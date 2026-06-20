#!/usr/bin/env python
"""Generic driver for Godot's SCons-style `(target, source, env)` builder functions.

The CMake build reuses Godot's own Python codegen (so generated output matches SCons)
instead of reimplementing it. This script reconstructs the calling convention an SCons
builder expects, then invokes the requested function from `add_custom_command`.

Usage:
    run_builder.py --repo-root <dir> (--module <dotted> | --module-path <file.py>)
                   --func <name> --target <out> [--target <out2> ...]
                   [--source <spec> ...]

`--source` specs (order is preserved; builders index source[0], source[1], ... and mix kinds):
    file:<path>            -> a file node; str()/os.fspath() yield the path
    jsonfile:<path>        -> a Value node; .read() returns json.load(path) (ordered)
    jsonlit:<json>         -> a Value node; .read() returns json.loads(json) (ordered)
    versioninfo:<modstr>   -> Value node = methods.get_version_info(<modstr>, silent=True)
    gitinfo:               -> Value node = methods.get_git_info()

Runs with CWD = repo root and repo root on sys.path, matching how SCons invokes builders
(so `import methods`, `import version`, etc. resolve, and get_git_info finds .git).
"""

import argparse
import importlib
import importlib.util
import json
import os
import sys
from collections import OrderedDict

_SELF_DIR = os.path.dirname(os.path.abspath(__file__))


class _FileNode:
    """Mimics an SCons File node: stringifies to its absolute path."""

    def __init__(self, path):
        self._path = os.path.abspath(path)

    def __str__(self):
        return self._path

    def __fspath__(self):
        return self._path

    @property
    def path(self):
        return self._path

    @property
    def abspath(self):
        return self._path

    @property
    def name(self):
        return os.path.basename(self._path)

    def read(self):
        raise TypeError(f"file node has no value to read(): {self._path}")


class _ValueNode:
    """Mimics an SCons Value node: .read() returns the wrapped Python object."""

    def __init__(self, obj):
        self._obj = obj

    def read(self):
        return self._obj

    def __str__(self):
        return str(self._obj)


def _resolve(repo_root, path):
    return path if os.path.isabs(path) else os.path.join(repo_root, path)


def _make_value(repo_root, spec):
    """Decode a value spec into a plain Python object (no node wrapper)."""
    kind, _, rest = spec.partition(":")
    if kind == "jsonfile":
        with open(_resolve(repo_root, rest), "r", encoding="utf-8") as handle:
            return json.load(handle, object_pairs_hook=OrderedDict)
    if kind == "jsonlit":
        return json.loads(rest, object_pairs_hook=OrderedDict)
    if kind == "str":
        return rest
    if kind == "versioninfo":
        import methods

        return methods.get_version_info(rest, silent=True)
    if kind == "gitinfo":
        import methods

        return methods.get_git_info()
    raise SystemExit(f"run_builder: unknown value kind in '{spec}'")


def _make_source(repo_root, spec):
    kind = spec.partition(":")[0]
    if kind == "file":
        return _FileNode(_resolve(repo_root, spec.partition(":")[2]))
    return _ValueNode(_make_value(repo_root, spec))


def _load_module(repo_root, dotted, module_path):
    if module_path:
        abspath = _resolve(repo_root, module_path)
        name = "_godot_builder_" + os.path.splitext(os.path.basename(abspath))[0]
        spec = importlib.util.spec_from_file_location(name, abspath)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
        return module
    return importlib.import_module(dotted)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--module")
    parser.add_argument("--module-path")
    parser.add_argument("--func", required=True)
    parser.add_argument("--target", action="append", default=[])
    parser.add_argument("--source", action="append", default=[])
    parser.add_argument("--source-list", default=None,
                        help="file with one --source spec per line (avoids command-line length limits)")
    parser.add_argument("--env", action="append", default=[],
                        help="env entry as KEY=SPEC (SPEC uses the value grammar: str:/jsonlit:/...)")
    args = parser.parse_args()

    if not args.module and not args.module_path:
        parser.error("one of --module or --module-path is required")

    repo_root = os.path.abspath(args.repo_root)
    sys.path.insert(0, repo_root)
    sys.path.append(_SELF_DIR)  # for fake_env
    os.chdir(repo_root)

    targets = [_FileNode(t) for t in args.target]
    for target in targets:
        os.makedirs(os.path.dirname(str(target)), exist_ok=True)
    source_specs = list(args.source)
    if args.source_list:
        with open(args.source_list, "r", encoding="utf-8") as handle:
            source_specs += [line.strip() for line in handle if line.strip()]
    sources = [_make_source(repo_root, spec) for spec in source_specs]

    module = _load_module(repo_root, args.module, args.module_path)
    func = getattr(module, args.func)

    from fake_env import FakeEnv

    env = FakeEnv()
    for entry in args.env:
        key, sep, spec = entry.partition("=")
        if not sep:
            raise SystemExit(f"run_builder: --env entry must be KEY=SPEC, got '{entry}'")
        env[key] = _make_value(repo_root, spec)

    func(targets, sources, env)


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""Emit the module manifest by reusing Godot's REAL module discovery.

Faking the SCons env with a fixed set of keys is the historical #1 source of breakage when
porting Godot's build. To avoid it for the part most likely to drift -- which modules are
enabled -- this script runs the engine's own `methods.detect_modules` and each module's
`config.py` (can_build / is_enabled / get_doc_*), replicating the SConstruct module loop
(SConstruct ~442-494 and ~1107-1155). It does NOT call `config.configure(env)` (that mutates
the compiler env via SCons-only methods and is irrelevant to the enabled-module set).

Outputs three files into --output-dir:
  modules_enabled.json   - OrderedDict(name -> path) of ENABLED modules (-> modules_enabled.gen.h)
  modules_detected.json  - OrderedDict(name -> path) of ALL detected modules (-> register_module_types.gen.cpp)
  modules_manifest.json  - full data for CMake: { module_list, modules_detected, doc_class_path,
                           icons_paths, module_version_string }
"""

import argparse
import importlib
import json
import os
import sys
from collections import OrderedDict


def _bool(s):
    return str(s).lower() in ("1", "true", "on", "yes")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--platform", default="windows")
    parser.add_argument("--arch", default="x86_64")
    parser.add_argument("--target", default="editor")
    parser.add_argument("--modules-enabled-by-default", default="1")
    # Renderer/feature flags some config.can_build() implementations read.
    parser.add_argument("--vulkan", default="1")
    parser.add_argument("--opengl3", default="1")
    parser.add_argument("--d3d12", default="0")
    parser.add_argument("--metal", default="0")
    args = parser.parse_args()

    repo_root = os.path.abspath(args.repo_root)
    sys.path.insert(0, repo_root)
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))  # fake_env
    os.chdir(repo_root)

    import methods
    from fake_env import FakeEnv

    editor_build = args.target == "editor"
    debug_features = args.target in ("editor", "template_debug")

    env = FakeEnv()
    env.update(
        {
            "platform": args.platform,
            "arch": args.arch,
            "target": args.target,
            "vulkan": _bool(args.vulkan),
            "opengl3": _bool(args.opengl3),
            "d3d12": _bool(args.d3d12),
            "metal": _bool(args.metal),
            "modules_enabled_by_default": _bool(args.modules_enabled_by_default),
            "tests": False,
            "use_volk": True,
            "minizip": True,
            # Export-template gates: editor builds enable these modules regardless.
            "cvtt_export_templates": False,
            "betsy_export_templates": False,
            # Web-only; off on desktop.
            "proxy_to_pthread": False,
        }
    )
    # Attributes (not [keys]) read by discovery/config code.
    env.editor_build = editor_build
    env.debug_features = debug_features
    env.dev_build = False
    env.msvc = (args.platform == "windows")
    env.module_dependencies = {}
    env.disabled_modules = set()
    env.module_version_string = ""
    env.module_icons_paths = []
    # Disable switches default off.
    for opt in ("disable_3d", "disable_advanced_gui", "disable_physics_2d", "disable_physics_3d",
                "disable_navigation_2d", "disable_navigation_3d", "disable_xr"):
        env[opt] = False

    # Bind the real dependency helpers (called as env.method(...) inside can_build).
    env["module_add_dependencies"] = (
        lambda module, deps, optional=False: methods.module_add_dependencies(env, module, deps, optional)
    )
    env["module_check_dependencies"] = lambda module: methods.module_check_dependencies(env, module)
    env["add_module_version_string"] = lambda s: setattr(env, "module_version_string", env.module_version_string + "." + s)

    # 1) Detect all built-in modules (SConstruct:459).
    modules_detected = methods.detect_modules("modules", recursive=False)

    # 2) Default enable state per module (SConstruct:476-485).
    def import_config(path):
        sys.path.insert(0, path)
        try:
            sys.modules.pop("config", None)
            return importlib.import_module("config")
        finally:
            sys.path.remove(path)

    for name, path in modules_detected.items():
        config = import_config(path)
        if env["modules_enabled_by_default"]:
            try:
                enabled = config.is_enabled()
            except AttributeError:
                enabled = True
        else:
            enabled = False
        env["module_{}_enabled".format(name)] = enabled
        sys.modules.pop("config", None)

    # 3) Activation loop (SConstruct:1112-1146): can_build + dependency check.
    module_list = OrderedDict()
    doc_class_path = {}
    icons_paths = []
    for name, path in modules_detected.items():
        if not env["module_{}_enabled".format(name)]:
            continue
        config = import_config(path)
        try:
            if config.can_build(env, env["platform"]):
                if not methods.module_check_dependencies(env, name):
                    continue
                # NOTE: config.configure(env) intentionally skipped (compiler-env only).
                try:
                    for c in config.get_doc_classes():
                        doc_class_path[c] = path + "/" + config.get_doc_path()
                except Exception:
                    pass
                try:
                    icons_paths.append(path + "/" + config.get_icons_path())
                except Exception:
                    icons_paths.append(path + "/" + "icons")
                module_list[name] = path
        finally:
            sys.modules.pop("config", None)

    env.module_list = module_list
    methods.sort_module_list(env)

    # 4) Editor dependency injection + check (SConstruct:1148-1155).
    if editor_build:
        methods.module_add_dependencies(env, "editor", ["freetype", "regex", "svg"])
        if not methods.module_check_dependencies(env, "editor"):
            sys.stderr.write("Not all modules required by editor builds are enabled (freetype/regex/svg).\n")
            sys.exit(1)

    # 5) Platform doc classes (SConstruct seeds env.doc_class_path with these).
    plat_dir = os.path.join("platform", args.platform)
    sys.path.insert(0, plat_dir)
    try:
        sys.modules.pop("detect", None)
        detect = importlib.import_module("detect")
        try:
            for c in detect.get_doc_classes():
                doc_class_path[c] = plat_dir.replace("\\", "/") + "/" + detect.get_doc_path()
        except Exception:
            pass
    finally:
        sys.modules.pop("detect", None)
        sys.path.remove(plat_dir)

    os.makedirs(args.output_dir, exist_ok=True)

    def dump(name, obj):
        with open(os.path.join(args.output_dir, name), "w", encoding="utf-8", newline="\n") as handle:
            json.dump(obj, handle, indent=2)

    dump("modules_enabled.json", env.module_list)
    dump("modules_detected.json", modules_detected)
    dump("doc_class_path.json", doc_class_path)
    dump(
        "modules_manifest.json",
        {
            "module_list": env.module_list,
            "modules_detected": modules_detected,
            "doc_class_path": doc_class_path,
            "icons_paths": icons_paths,
            "module_version_string": env.module_version_string,
        },
    )

    print(
        "emit_modules_manifest: {} enabled / {} detected modules".format(
            len(env.module_list), len(modules_detected)
        )
    )
    print("  enabled: " + ", ".join(env.module_list.keys()))


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""Configure-time guard against stale in-source generated files.

A prior SCons build writes *.gen.h / *.gen.cpp / *.glsl.gen.h into the SOURCE tree. Those
would shadow the CMake build's binary-dir copies (MSVC searches the including file's own
directory first), silently producing a stale or mismatched build. This guard fails the
CMake configure with an actionable message if any are found, so the user can `git clean`.

Usage: check_no_insource_gen.py --source-root <dir> [--build-dir <dir>]
"""

import argparse
import os
import sys

_SUFFIXES = (".gen.h", ".gen.cpp", ".gen.inc", ".glsl.gen.h", ".gen.hpp")
_PRUNE = {".git", "out", "bin", "__pycache__", ".claude"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--build-dir", default="")
    args = parser.parse_args()

    source_root = os.path.abspath(args.source_root)
    build_dir = os.path.abspath(args.build_dir) if args.build_dir else None

    found = []
    for dirpath, dirnames, filenames in os.walk(source_root):
        # Prune build/VCS/cache dirs in place.
        dirnames[:] = [
            d for d in dirnames
            if d not in _PRUNE and not (build_dir and os.path.abspath(os.path.join(dirpath, d)) == build_dir)
        ]
        for name in filenames:
            if name.endswith(_SUFFIXES):
                found.append(os.path.relpath(os.path.join(dirpath, name), source_root))

    if found:
        found.sort()
        sys.stderr.write(
            "Stale in-source generated files detected (likely from a previous SCons build).\n"
            "They would shadow the CMake build's binary-dir copies. Remove them, e.g.:\n"
            "    git clean -dxf -e out -e bin\n"
            "or delete these files manually:\n"
        )
        for f in found[:50]:
            sys.stderr.write(f"    {f}\n")
        if len(found) > 50:
            sys.stderr.write(f"    ... and {len(found) - 50} more\n")
        sys.exit(1)

    print(f"check_no_insource_gen: OK (no stale *.gen.* under {source_root})")


if __name__ == "__main__":
    main()

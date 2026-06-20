#!/usr/bin/env python
"""Drive Godot's GLSL shader-header builders to an explicit binary-dir output path.

glsl_builders.build_rd_headers / build_raw_headers / gles3_builders.build_gles3_headers all
write `<src>.gen.h` next to the source. We instead call the lower-level single-file builders
(build_rd_header / build_raw_header / build_gles3_header), which take an explicit output path,
so generated shader headers land under ${GODOT_GEN_DIR} (never in the source tree).

Runs with CWD = repo root so the builders' relative #include resolution (`thirdparty/...`
and dir-relative includes) matches SCons.

Usage: run_shader.py --repo-root <dir> --kind rd|raw|gles3 --src <repo-rel .glsl> --out <abs .gen.h>
"""

import argparse
import os
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--kind", required=True, choices=["rd", "raw", "gles3"])
    parser.add_argument("--src", required=True, help="shader path relative to repo root")
    parser.add_argument("--out", required=True, help="absolute output .gen.h path")
    args = parser.parse_args()

    repo_root = os.path.abspath(args.repo_root)
    sys.path.insert(0, repo_root)
    os.chdir(repo_root)

    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    if args.kind == "gles3":
        from gles3_builders import build_gles3_header

        build_gles3_header(out, args.src)
    elif args.kind == "raw":
        from glsl_builders import build_raw_header

        build_raw_header(out, args.src)
    else:  # rd
        from glsl_builders import build_rd_header

        build_rd_header(out, args.src)


if __name__ == "__main__":
    main()

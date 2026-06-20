#!/usr/bin/env python
"""Dev tool: extract each module's bundled-thirdparty source list from its SCsub.

The module SCsubs hard-list their thirdparty sources (curated subsets, not globbable). Rather
than hand-transcribe ~30 lists (hundreds of files), this scrapes the `*_dir = "#thirdparty/..."`
+ `*_sources = [ ... ]` literals and writes one `cmake/thirdparty_lists/<module>.cmake` per
module containing `set(GODOT_TP_<MODULE>_SOURCES <paths relative to thirdparty/>)`.

This is a ONE-TIME generator (not part of the build). The produced .cmake files are the
"hardcoded thirdparty lists" the build consumes (GodotModuleThirdparty.cmake). Re-run on engine
bumps. Arch-specific files are kept (they're #ifdef-guarded in the sources).

Usage: extract_thirdparty.py --repo-root <dir> --out-dir cmake/thirdparty_lists [--modules a,b,c]
"""

import argparse
import os
import re

# var-name -> "#thirdparty/foo/" assignments, and *_sources literal lists.
_DIR_RE = re.compile(r'(\w+)\s*=\s*"#?(thirdparty/[^"]*?)/?"')
_SRC_ASSIGN_RE = re.compile(r'(\w*sources\w*|\w+_src)\s*\+?=\s*\[(.*?)\]', re.DOTALL)
_FILE_RE = re.compile(r'"([^"]+\.(?:c|cpp|cc|cxx|S))"')


def _autocorrect(repo, lib_dir, path):
    """If `path` doesn't exist, try to locate the file by basename under thirdparty/<lib>."""
    if os.path.isfile(os.path.join(repo, path)):
        return path
    base = os.path.basename(path)
    root = os.path.join(repo, lib_dir) if lib_dir else os.path.join(repo, "thirdparty")
    matches = []
    for dirpath, _dirs, files in os.walk(root):
        if base in files:
            matches.append(os.path.relpath(os.path.join(dirpath, base), repo).replace("\\", "/"))
    return matches[0] if len(matches) == 1 else path


def extract(scsub_text, repo=None, lib_top=None):
    """Return a list of thirdparty paths (relative to repo root, e.g. thirdparty/enet/host.c)."""
    # Map of dir-var -> path, in order of appearance (to resolve "nearest preceding dir").
    dir_positions = [(m.start(), m.group(1), m.group(2)) for m in _DIR_RE.finditer(scsub_text)]

    results = []
    seen = set()
    for m in _SRC_ASSIGN_RE.finditer(scsub_text):
        block = m.group(2)
        if "for " in block and " in " in block:
            continue  # comprehension reassignment (e.g. [dir + f for f in sources]); files are elsewhere
        block = re.sub(r"#[^\n]*", "", block)  # strip commented-out entries (e.g. # "tool.c")
        files = _FILE_RE.findall(block)
        if not files:
            continue
        # Skip glob patterns and obvious non-thirdparty entries.
        files = [f for f in files if "*" not in f]
        if not files:
            continue
        # Choose the thirdparty dir: prefer the conventional `thirdparty_dir` var among those
        # declared before this block (secondary dirs like *_spirv_headers_dir are deps, not the
        # source root); otherwise fall back to the nearest preceding dir.
        pos = m.start()
        chosen = None
        for dpos, dvar, dpath in dir_positions:
            if dpos < pos:
                if dvar == "thirdparty_dir":
                    chosen = dpath
                elif chosen is None:
                    chosen = dpath
            else:
                break
        # Prefer thirdparty_dir if any preceding one matched it.
        for dpos, dvar, dpath in dir_positions:
            if dpos < pos and dvar == "thirdparty_dir":
                chosen = dpath
        if chosen is None and dir_positions:
            chosen = dir_positions[0][2]
        prefix = (chosen + "/") if chosen else ""
        # Top-level lib dir for basename auto-correction (e.g. thirdparty/libjpeg-turbo).
        lib_top = None
        if chosen:
            parts = chosen.split("/")
            lib_top = "/".join(parts[:2]) if len(parts) >= 2 else chosen
        for f in files:
            # If the file already contains a thirdparty path, keep as-is; else prefix with the dir.
            path = f if f.startswith("thirdparty/") else (prefix + f)
            path = path.replace("\\", "/").replace("//", "/")
            if repo is not None:
                path = _autocorrect(repo, lib_top, path)
            if path not in seen:
                seen.add(path)
                results.append(path)
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--modules", default="")
    args = parser.parse_args()

    repo = os.path.abspath(args.repo_root)
    out = os.path.join(repo, args.out_dir) if not os.path.isabs(args.out_dir) else args.out_dir
    os.makedirs(out, exist_ok=True)

    mods = [m for m in args.modules.split(",") if m] if args.modules else sorted(
        d for d in os.listdir(os.path.join(repo, "modules"))
        if os.path.isfile(os.path.join(repo, "modules", d, "SCsub"))
    )

    summary = []
    for mod in mods:
        scsub = os.path.join(repo, "modules", mod, "SCsub")
        if not os.path.isfile(scsub):
            continue
        with open(scsub, "r", encoding="utf-8") as fh:
            text = fh.read()
        files = extract(text, repo=repo)
        if not files:
            continue
        # Verify each file exists; warn (but keep) otherwise.
        missing = [f for f in files if not os.path.isfile(os.path.join(repo, f))]
        var = "GODOT_TP_{}_SOURCES".format(mod.upper())
        lines = ["# GENERATED by extract_thirdparty.py from modules/{}/SCsub -- do not edit by hand.".format(mod),
                 "set({}".format(var)]
        for f in files:
            lines.append("  {}".format(f))
        lines.append(")")
        with open(os.path.join(out, mod + ".cmake"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")
        summary.append((mod, len(files), len(missing)))

    for mod, n, miss in summary:
        note = " ({} MISSING!)".format(miss) if miss else ""
        print("  {:20s} {:4d} files{}".format(mod, n, note))
    print("extract_thirdparty: wrote {} module lists to {}".format(len(summary), out))


if __name__ == "__main__":
    main()

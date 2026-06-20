#!/usr/bin/env python
"""Print the Mesa/NIR include directories for the D3D12 driver, one per line.

drivers/d3d12/SCsub adds *every* directory under the prebuilt godot-mesa tree to the include
path (it includes Mesa internals), minus src/c11 (which would shadow the real <threads.h>).
CMake has no clean recursive-dir listing, so this mirrors that os.walk. The prebuilt
godot-nir-static package already ships generated/ headers, so nothing is generated here.

Usage: emit_mesa_includes.py <path-to/godot-mesa>
"""

import os
import sys

root = os.path.abspath(sys.argv[1])
c11 = os.path.join(root, "src", "c11")

dirs = []
for dirpath, _dirnames, _files in os.walk(root):
    # Skip src/c11 and below (its threads.h shadows the system one).
    if dirpath == c11 or dirpath.startswith(c11 + os.sep):
        continue
    dirs.append(dirpath.replace("\\", "/"))

print("\n".join(dirs))

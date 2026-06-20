# GodotDefines.cmake
#
# Creates the `godot_defines` INTERFACE library carrying the cross-cutting preprocessor
# definitions and include roots every engine/component target needs. The option->define map
# mirrors SConstruct (the platform-specific renderer/OS defines live in platform/Windows.cmake,
# matching where detect.py sets them).
#
# IMPORTANT: MODULE_<NAME>_ENABLED defines are NOT set here. They come exclusively from the
# generated header modules/modules_enabled.gen.h (let it own them, as SCons does).

add_library(godot_defines INTERFACE)

# C++17 is mandatory (guaranteed copy elision, GH-36436).
target_compile_features(godot_defines INTERFACE cxx_std_17)

# Include roots: source tree (for #include "core/foo.h") + the generated-file tree
# (for #include "core/foo.gen.h"). All codegen lands under GODOT_GEN_DIR, never in-source.
target_include_directories(godot_defines INTERFACE
  "${CMAKE_SOURCE_DIR}"
  "${GODOT_GEN_DIR}"
)

set(_defs "")

# Build-type defines (SConstruct ~548-562).
if(GODOT_EDITOR_BUILD)
  list(APPEND _defs TOOLS_ENABLED)
endif()
if(GODOT_DEBUG_FEATURES)
  list(APPEND _defs DEBUG_ENABLED)
endif()
if(GODOT_DEV_BUILD)
  list(APPEND _defs DEV_ENABLED)
else()
  list(APPEND _defs NDEBUG)
endif()

# Feature defines.
if(GODOT_THREADS)
  list(APPEND _defs THREADS_ENABLED)
endif()
if(GODOT_MINIZIP)
  list(APPEND _defs MINIZIP_ENABLED)
endif()
if(GODOT_BROTLI)
  list(APPEND _defs BROTLI_ENABLED)
endif()
if(GODOT_PRECISION STREQUAL "double")
  list(APPEND _defs REAL_T_IS_DOUBLE)
endif()
if(NOT GODOT_DEPRECATED)
  list(APPEND _defs DISABLE_DEPRECATED)
endif()

# Override system (SConstruct ~1098-1102): defaults enable both.
list(APPEND _defs OVERRIDE_ENABLED)
if(GODOT_EDITOR_BUILD)
  list(APPEND _defs OVERRIDE_PATH_ENABLED)
  # Editor splash is disabled if the image is missing (SConstruct ~587-591).
  if(NOT EXISTS "${CMAKE_SOURCE_DIR}/main/splash_editor.png")
    list(APPEND _defs NO_EDITOR_SPLASH)
  endif()
endif()

# Disable switches (SConstruct ~1076-1092).
if(GODOT_DISABLE_3D)
  list(APPEND _defs _3D_DISABLED)
endif()
if(GODOT_DISABLE_ADVANCED_GUI)
  list(APPEND _defs ADVANCED_GUI_DISABLED)
endif()
if(GODOT_DISABLE_PHYSICS_2D)
  list(APPEND _defs PHYSICS_2D_DISABLED)
endif()
if(GODOT_DISABLE_PHYSICS_3D)
  list(APPEND _defs PHYSICS_3D_DISABLED)
endif()
if(GODOT_DISABLE_NAVIGATION_2D)
  list(APPEND _defs NAVIGATION_2D_DISABLED)
endif()
if(GODOT_DISABLE_NAVIGATION_3D)
  list(APPEND _defs NAVIGATION_3D_DISABLED)
endif()
if(GODOT_DISABLE_XR)
  list(APPEND _defs XR_DISABLED)
endif()

# Thirdparty defines that core/SCsub leaks into the main env (so engine code sees them too).
list(APPEND _defs CLIPPER2_ENABLED ZSTD_STATIC_LINKING_ONLY)

target_compile_definitions(godot_defines INTERFACE ${_defs})

message(STATUS "godot_defines: ${_defs}")

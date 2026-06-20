# GodotOptions.cmake
#
# GODOT_* cache variables mirroring the SCons option surface (SConstruct opts.Add),
# plus validation and derived booleans. This is the single source of build configuration
# for the CMake build; everything else (defines, suffix, platform, modules) reads from here.
#
# NOTE: This is a parallel, additive build. It never invokes SCons. Defaults track SConstruct
# except for prebuilt-SDK features (d3d12/angle/accesskit/winrt) which default OFF here so the
# editor builds and runs without first fetching external SDKs (documented divergence).

# ---- Target selection ---------------------------------------------------------------------
set(GODOT_PLATFORM "windows" CACHE STRING "Target platform (only 'windows' implemented so far)")
set(GODOT_TARGET   "editor"  CACHE STRING "Build target: editor | template_debug | template_release")
set(GODOT_ARCH     "x86_64"  CACHE STRING "Target architecture: x86_64 | x86_32 | arm64 | arm32")
set(GODOT_PRECISION "single" CACHE STRING "Floating-point precision: single | double")
set(GODOT_OPTIMIZE "auto"    CACHE STRING "Optimization: auto | none | speed | speed_trace | size")

set_property(CACHE GODOT_TARGET    PROPERTY STRINGS editor template_debug template_release)
set_property(CACHE GODOT_PRECISION PROPERTY STRINGS single double)
set_property(CACHE GODOT_OPTIMIZE  PROPERTY STRINGS auto none speed speed_trace size)

# ---- Core feature toggles -----------------------------------------------------------------
option(GODOT_DEV_BUILD  "Enable DEV_ENABLED engine-developer code"            OFF)
option(GODOT_THREADS    "Enable threading support (THREADS_ENABLED)"          ON)
option(GODOT_DEPRECATED "Keep compatibility/deprecated code"                  ON)
option(GODOT_MINIZIP    "ZIP archive support (MINIZIP_ENABLED)"               ON)
option(GODOT_BROTLI     "Brotli compression + WOFF2 (BROTLI_ENABLED)"         ON)

# Renderers / drivers
option(GODOT_VULKAN   "Vulkan / RenderingDevice renderer (VULKAN_ENABLED)"    ON)
option(GODOT_OPENGL3  "OpenGL / GLES3 renderer (GLES3_ENABLED)"               ON)
option(GODOT_USE_VOLK "Load Vulkan dynamically via volk"                      ON)
option(GODOT_SDL      "SDL input driver (SDL_ENABLED)"                        ON)

# Disable switches (export-template only; rejected for editor builds, mirroring SConstruct).
option(GODOT_DISABLE_3D            "Disable 3D nodes (_3D_DISABLED)"          OFF)
option(GODOT_DISABLE_ADVANCED_GUI  "Disable advanced GUI"                     OFF)
option(GODOT_DISABLE_PHYSICS_2D    "Disable 2D physics"                       OFF)
option(GODOT_DISABLE_PHYSICS_3D    "Disable 3D physics"                       OFF)
option(GODOT_DISABLE_NAVIGATION_2D "Disable 2D navigation"                    OFF)
option(GODOT_DISABLE_NAVIGATION_3D "Disable 3D navigation"                    OFF)
option(GODOT_DISABLE_XR            "Disable XR (XR_DISABLED)"                  OFF)

# Modules
option(GODOT_MODULES_ENABLED_BY_DEFAULT "Enable all detected modules by default" ON)

# Prebuilt-SDK features: need an external SDK fetched by misc/scripts/install_*.py into
# GODOT_BUILD_DEPS (bin/build_deps by default; that's where the install scripts land under MSYS/Git-Bash).
option(GODOT_D3D12     "Direct3D 12 renderer (needs mesa/NIR + Agility SDK)"  ON)
option(GODOT_ANGLE     "OpenGL via ANGLE (needs prebuilt ANGLE libs)"         ON)
option(GODOT_ACCESSKIT "Screen-reader support (needs AccessKit C SDK)"        ON)
option(GODOT_WINRT     "WinRT/OneCore TTS (MSVC: uses system Windows SDK)"    ON)
set(GODOT_BUILD_DEPS "${CMAKE_SOURCE_DIR}/bin/build_deps" CACHE PATH "Prebuilt SDK dir (install_*.py output)")

# Link-time optimization + builds.
set(GODOT_LTO "none" CACHE STRING "LTO: none | full")
set_property(CACHE GODOT_LTO PROPERTY STRINGS none full)
option(GODOT_TESTS "Build the unit-test suite (run with --test)" OFF)

# Windows specifics
set(GODOT_WINDOWS_SUBSYSTEM "gui" CACHE STRING "Windows subsystem: gui | console")
set_property(CACHE GODOT_WINDOWS_SUBSYSTEM PROPERTY STRINGS gui console)
option(GODOT_USE_STATIC_CPP "Statically link the MSVC C++ runtime (/MT)"      ON)
option(GODOT_DEBUG_SYMBOLS  "Emit debug symbols (/Zi /DEBUG:FULL)"            OFF)

# Bring-up scaffold smoke test (Stage 1). OFF now that the real executable is wired.
option(GODOT_SCAFFOLD_ONLY "Build only the Stage-1 scaffold smoke-test executable" OFF)

# ---- Validation ---------------------------------------------------------------------------
if(NOT GODOT_PLATFORM STREQUAL "windows")
  message(FATAL_ERROR "GODOT_PLATFORM='${GODOT_PLATFORM}': only 'windows' is implemented in this CMake build so far.")
endif()

set(_valid_targets editor template_debug template_release)
if(NOT GODOT_TARGET IN_LIST _valid_targets)
  message(FATAL_ERROR "GODOT_TARGET='${GODOT_TARGET}' is invalid. Use one of: ${_valid_targets}.")
endif()

if(NOT GODOT_PRECISION STREQUAL "single" AND NOT GODOT_PRECISION STREQUAL "double")
  message(FATAL_ERROR "GODOT_PRECISION='${GODOT_PRECISION}' is invalid. Use 'single' or 'double'.")
endif()

# ---- Derived booleans (mirror SConstruct env.editor_build / env.debug_features) ------------
if(GODOT_TARGET STREQUAL "editor")
  set(GODOT_EDITOR_BUILD ON)
else()
  set(GODOT_EDITOR_BUILD OFF)
endif()

if(GODOT_TARGET STREQUAL "editor" OR GODOT_TARGET STREQUAL "template_debug")
  set(GODOT_DEBUG_FEATURES ON)
else()
  set(GODOT_DEBUG_FEATURES OFF)
endif()

# Editor builds reject the export-template-only disable switches (SConstruct ~1056-1074).
if(GODOT_EDITOR_BUILD)
  foreach(_opt GODOT_DISABLE_3D GODOT_DISABLE_ADVANCED_GUI GODOT_DISABLE_PHYSICS_2D
               GODOT_DISABLE_PHYSICS_3D GODOT_DISABLE_NAVIGATION_2D GODOT_DISABLE_NAVIGATION_3D)
    if(${_opt})
      message(FATAL_ERROR "${_opt} cannot be used for editor builds (export templates only).")
    endif()
  endforeach()
endif()

# disable_3d cascades (SConstruct ~1076-1080).
if(GODOT_DISABLE_3D)
  set(GODOT_DISABLE_NAVIGATION_3D ON)
  set(GODOT_DISABLE_PHYSICS_3D ON)
  set(GODOT_DISABLE_XR ON)
endif()

# Resolve "auto" optimization (SConstruct ~537-544).
if(GODOT_OPTIMIZE STREQUAL "auto")
  if(GODOT_DEV_BUILD)
    set(GODOT_OPTIMIZE_RESOLVED "none")
  elseif(GODOT_DEBUG_FEATURES)
    set(GODOT_OPTIMIZE_RESOLVED "speed_trace")
  else()
    set(GODOT_OPTIMIZE_RESOLVED "speed")
  endif()
else()
  set(GODOT_OPTIMIZE_RESOLVED "${GODOT_OPTIMIZE}")
endif()

message(STATUS "Godot CMake config: platform=${GODOT_PLATFORM} target=${GODOT_TARGET} arch=${GODOT_ARCH} "
               "precision=${GODOT_PRECISION} optimize=${GODOT_OPTIMIZE_RESOLVED} "
               "editor=${GODOT_EDITOR_BUILD} dev=${GODOT_DEV_BUILD}")

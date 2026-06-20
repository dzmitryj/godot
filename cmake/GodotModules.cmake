# GodotModules.cmake
#
# Stage 3: run Godot's REAL module discovery (emit_modules_manifest.py) at configure time,
# parse the manifest, and wire the module-registration codegen. The same JSON the emitter
# produces is fed straight to the builders, so CMake and the generated code agree by
# construction.
#
# Per-module static libraries + their bundled thirdparty are added in Stage 6 (this file
# will grow a loop over GODOT_ENABLED_MODULES).

set(GODOT_MODULES_DIR "${CMAKE_BINARY_DIR}/godot_modules")

# bool -> 1/0 for the emitter CLI.
macro(_b01 out var)
  if(${var})
    set(${out} 1)
  else()
    set(${out} 0)
  endif()
endmacro()
_b01(_m_vulkan  GODOT_VULKAN)
_b01(_m_opengl3 GODOT_OPENGL3)
_b01(_m_d3d12   GODOT_D3D12)
_b01(_m_metal   OFF)
_b01(_m_default GODOT_MODULES_ENABLED_BY_DEFAULT)

execute_process(
  COMMAND "${GODOT_PYTHON}" "${CMAKE_SOURCE_DIR}/misc/cmake/emit_modules_manifest.py"
          --repo-root "${CMAKE_SOURCE_DIR}" --output-dir "${GODOT_MODULES_DIR}"
          --platform "${GODOT_PLATFORM}" --arch "${GODOT_ARCH}" --target "${GODOT_TARGET}"
          --modules-enabled-by-default "${_m_default}"
          --vulkan "${_m_vulkan}" --opengl3 "${_m_opengl3}" --d3d12 "${_m_d3d12}" --metal "${_m_metal}"
  RESULT_VARIABLE _mod_rc
  OUTPUT_VARIABLE _mod_out
)
if(NOT _mod_rc EQUAL 0)
  message(FATAL_ERROR "emit_modules_manifest.py failed:\n${_mod_out}")
endif()
message(STATUS "${_mod_out}")

set(GODOT_MODULES_ENABLED_JSON  "${GODOT_MODULES_DIR}/modules_enabled.json")
set(GODOT_MODULES_DETECTED_JSON "${GODOT_MODULES_DIR}/modules_detected.json")
set(GODOT_MODULES_MANIFEST      "${GODOT_MODULES_DIR}/modules_manifest.json")

# Re-run configure if the manifest inputs change.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/misc/cmake/emit_modules_manifest.py")

# Parse the enabled-module list (name -> path) for use by later stages.
file(READ "${GODOT_MODULES_MANIFEST}" _manifest)
string(JSON _ml GET "${_manifest}" "module_list")
string(JSON _ml_count LENGTH "${_ml}")
set(GODOT_ENABLED_MODULES "")
if(_ml_count GREATER 0)
  math(EXPR _last "${_ml_count} - 1")
  foreach(_i RANGE ${_last})
    string(JSON _name MEMBER "${_ml}" ${_i})
    string(JSON _path GET "${_ml}" "${_name}")
    list(APPEND GODOT_ENABLED_MODULES "${_name}")
    set(GODOT_MODULE_PATH_${_name} "${_path}")
  endforeach()
endif()
list(LENGTH GODOT_ENABLED_MODULES _n_enabled)
message(STATUS "GodotModules: ${_n_enabled} modules enabled")

# ---- Module-registration codegen ----------------------------------------------------------
# modules_enabled.gen.h: #define MODULE_<NAME>_ENABLED for each ENABLED module.
godot_add_generated(OUTPUT modules/modules_enabled.gen.h
  MODULE_PATH modules/modules_builders.py FUNC modules_enabled_builder
  SOURCES "jsonfile:${GODOT_MODULES_ENABLED_JSON}")

# register_module_types.gen.cpp: includes register_types.h for ALL detected modules, init
# calls guarded by MODULE_<NAME>_ENABLED. source[0] = modules_detected; depends on the
# enabled header (matching the SCons source ordering).
godot_add_generated(OUTPUT modules/register_module_types.gen.cpp
  MODULE_PATH modules/modules_builders.py FUNC register_module_types_builder
  SOURCES "jsonfile:${GODOT_MODULES_DETECTED_JSON}"
  DEPENDS "${GODOT_GEN_DIR}/modules/modules_enabled.gen.h")

# ---- Per-module static libraries ----------------------------------------------------------
# One module_<name> lib per enabled module, sources globbed from the module dir (editor build:
# the module's editor/ subdir is included; tests/ excluded). Modules that pull in bundled
# thirdparty / extra includes / defines / shaders are augmented below in GodotModuleExtras.
set(GODOT_MODULE_LIBS "" CACHE INTERNAL "")
foreach(_mod IN LISTS GODOT_ENABLED_MODULES)
  set(_mpath "${GODOT_MODULE_PATH_${_mod}}")
  if(NOT IS_ABSOLUTE "${_mpath}")
    set(_mpath "${CMAKE_SOURCE_DIR}/${_mpath}")
  endif()
  file(GLOB_RECURSE _msrcs CONFIGURE_DEPENDS "${_mpath}/*.cpp")
  list(FILTER _msrcs EXCLUDE REGEX "\\.gen\\.cpp$")
  list(FILTER _msrcs EXCLUDE REGEX "/tests/")
  # Editor-only module subdirs (gated on env.editor_build in the module SCsubs): exclude for
  # template builds. editor/ is the convention; gdscript also gates language_server/.
  if(NOT GODOT_EDITOR_BUILD)
    list(FILTER _msrcs EXCLUDE REGEX "/(editor|language_server)/")
  endif()
  # camera/SCsub selects only the platform backend (we build Windows): drop the others.
  if(_mod STREQUAL "camera")
    list(FILTER _msrcs EXCLUDE REGEX "camera_(linux|android|apple|feed_linux)|buffer_decoder")
  endif()
  # openxr/extensions/SCsub picks platform extensions: keep vulkan/opengl, drop android (+ d3d12 if off).
  if(_mod STREQUAL "openxr")
    list(FILTER _msrcs EXCLUDE REGEX "openxr_android_extension")
    if(NOT GODOT_D3D12)
      list(FILTER _msrcs EXCLUDE REGEX "openxr_d3d12_extension")
    endif()
  endif()
  if(_msrcs)
    add_library(module_${_mod} STATIC ${_msrcs})
    target_link_libraries(module_${_mod} PUBLIC godot_defines godot_platform_windows)
    target_compile_definitions(module_${_mod} PRIVATE GODOT_MODULE)
    add_dependencies(module_${_mod} godot_generated godot_shaders)
    set(GODOT_MODULE_LIBS "${GODOT_MODULE_LIBS};module_${_mod}" CACHE INTERNAL "")
  endif()
endforeach()

# Final register lib (register_module_types.gen.cpp) -- does a bare #include "register_module_types.h".
add_library(godot_modules_register STATIC "${GODOT_GEN_DIR}/modules/register_module_types.gen.cpp")
target_link_libraries(godot_modules_register PUBLIC godot_defines godot_platform_windows)
target_include_directories(godot_modules_register PRIVATE "${CMAKE_SOURCE_DIR}/modules")
add_dependencies(godot_modules_register godot_generated)
set_source_files_properties("${GODOT_GEN_DIR}/modules/register_module_types.gen.cpp" PROPERTIES GENERATED TRUE)

# Module-specific thirdparty / includes / defines / shaders (transcribed from module SCsubs).
include(GodotModuleExtras OPTIONAL)
# Bundled-thirdparty OBJECT libs per module (from extracted source lists) -> linked into modules.
include(GodotModuleThirdparty OPTIONAL)

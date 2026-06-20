# GodotExecutable.cmake
#
# Assembles and links the final editor executable plus the console wrapper. The Windows entry
# point (godot_windows.cpp, WinMain) is compiled here; the rest of platform/windows is in
# godot_platform. MSVC's linker resolves the static-lib cycles in one command, so no --start-group.

# Resource scripts: icon + manifest + version info (editor vs export-template variants).
if(GODOT_EDITOR_BUILD)
  set(_res      "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/godot_res.rc")
  set(_res_wrap "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/godot_res_wrap.rc")
else()
  set(_res      "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/godot_res_template.rc")
  set(_res_wrap "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/godot_res_wrap_template.rc")
endif()

set(_entry "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/godot_windows.cpp")

# Startup CPU baseline check (x86_64): cpu_feature_validation.c must be built WITHOUT /d2archSSE42
# (it runs before confirming SSE4.2 support), so it is its own object lib with a minimal flag set
# rather than linking godot_platform_windows. It provides ShimMainCRTStartup, used as the entry.
set(_cpu_check_objs "")
if(GODOT_ARCH STREQUAL "x86_64")
  add_library(godot_cpu_check OBJECT "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/cpu_feature_validation.c")
  target_compile_options(godot_cpu_check PRIVATE /MT /utf-8 /nologo)
  set(_cpu_check_objs $<TARGET_OBJECTS:godot_cpu_check>)
endif()

add_executable(godot "${_entry}" "${_res}" ${_cpu_check_objs})

# RC compilation needs the source root (to resolve "core/version.h" and the repo-root-relative
# icon/manifest paths) and the gen dir (version_generated.gen.h, pulled in by version.h).
target_include_directories(godot PRIVATE "${CMAKE_SOURCE_DIR}" "${GODOT_GEN_DIR}")
add_dependencies(godot godot_generated)  # version_generated.gen.h for the .rc

target_link_libraries(godot PRIVATE
  godot_main
  godot_modules_register
  ${GODOT_MODULE_LIBS}
  godot_editor
  godot_scene
  godot_servers
  godot_drivers
  godot_platform
  godot_core
  ${GODOT_ORPHAN_TP}        # freetype/msdfgen (thirdparty-only modules, no own .cpp)
  godot_defines
  godot_platform_windows)

if(GODOT_ARCH STREQUAL "x86_64")
  target_link_options(godot PRIVATE /ENTRY:ShimMainCRTStartup)
endif()

# The resource script already embeds the application manifest (RT_MANIFEST id 1); stop CMake/link
# from generating and embedding its own at the same id (which collides). Matches SCons.
target_link_options(godot PRIVATE /MANIFEST:NO)

godot_set_output(godot)

# ---- Console wrapper executable -----------------------------------------------------------
# Relaunches the GUI exe with stdout attached. Standalone console-subsystem program.
godot_compute_suffix(_suffix)
add_executable(godot_console
  "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/console_wrapper_windows.cpp" "${_res_wrap}")
target_include_directories(godot_console PRIVATE "${CMAKE_SOURCE_DIR}" "${GODOT_GEN_DIR}")
target_link_libraries(godot_console PRIVATE godot_platform_windows version)
# Override the GUI subsystem from godot_platform_windows (last /SUBSYSTEM wins); the wrap resource
# embeds its own manifest, so disable CMake's auto manifest here too.
target_link_options(godot_console PRIVATE /SUBSYSTEM:CONSOLE /MANIFEST:NO)
set_target_properties(godot_console PROPERTIES
  OUTPUT_NAME "godot${_suffix}.console"
  SUFFIX ".exe"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")
add_dependencies(godot_console godot godot_generated)

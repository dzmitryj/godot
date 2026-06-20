# GodotExecutable.cmake
#
# Assembles and links the final editor executable. The Windows entry point (godot_windows.cpp,
# which provides WinMain) is compiled here; the rest of platform/windows lives in godot_platform.
#
# MSVC's linker resolves symbols across all input libraries in a single command (unlike GNU ld's
# strict one-pass ordering), so the static-lib cycles between core/servers/scene/modules/editor
# resolve without --start-group; we still list them dependents-first (core last) for clarity.

set(_entry "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/godot_windows.cpp")

add_executable(godot "${_entry}")

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

# ktx and basis_universal both bundle basis's miniz (identical buminiz::mz_* defs). The bundled
# code is byte-identical, so let the linker keep the first definition. (Pragmatic; SCons isolates
# these via separate static libs that aren't co-linked the same way.)
target_link_options(godot PRIVATE /FORCE:MULTIPLE)

godot_set_output(godot)

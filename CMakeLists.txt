# Godot Engine - parallel, additive CMake build (Windows editor first).
#
# This build coexists with and never invokes SCons; SCons remains the reference oracle.
# See the implementation plan for the full architecture. Configure via the bundled preset:
#   cmake --preset windows-editor && cmake --build --preset windows-editor
#
# All generated files are written under ${CMAKE_BINARY_DIR}/gen (never into the source tree).

cmake_minimum_required(VERSION 3.24)

# Forbid in-source builds (would collide with the source tree and SCons output).
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
  message(FATAL_ERROR "In-source CMake builds are not allowed. Use a preset (out/cmake/<preset>).")
endif()

project(godot LANGUAGES C CXX)

set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Godot (like SCons) controls ALL compiler/linker flags explicitly via the interface libs.
# Neutralize CMake's built-in default + per-config flags so they can't conflict with ours
# (e.g. the default Debug /RTC1 + our /O2, or /MDd vs /MT). We also disable CMake's automatic
# MSVC runtime-library selection and pass /MT or /MD ourselves (platform/Windows.cmake).
if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "")
  foreach(_cfg "" _DEBUG _RELEASE _RELWITHDEBINFO _MINSIZEREL)
    set(CMAKE_C_FLAGS${_cfg} "")
    set(CMAKE_CXX_FLAGS${_cfg} "")
    set(CMAKE_EXE_LINKER_FLAGS${_cfg} "")
    set(CMAKE_SHARED_LINKER_FLAGS${_cfg} "")
    set(CMAKE_STATIC_LINKER_FLAGS${_cfg} "")
    set(CMAKE_MODULE_LINKER_FLAGS${_cfg} "")
  endforeach()
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# Root directory for all generated source/headers, mirroring the source layout.
set(GODOT_GEN_DIR "${CMAKE_BINARY_DIR}/gen")
file(MAKE_DIRECTORY "${GODOT_GEN_DIR}")

# Guard against stale in-source *.gen.* from a prior SCons build shadowing our binary-dir copies.
find_package(Python3 COMPONENTS Interpreter REQUIRED)
execute_process(
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/misc/cmake/check_no_insource_gen.py"
          --source-root "${CMAKE_SOURCE_DIR}" --build-dir "${CMAKE_BINARY_DIR}"
  RESULT_VARIABLE _insrc_gen_rc
)
if(NOT _insrc_gen_rc EQUAL 0)
  message(FATAL_ERROR "Stale in-source generated files detected (see above). Clean them and re-configure.")
endif()

include(GodotOptions)   # GODOT_* cache vars + validation + derived booleans
include(GodotDefines)   # godot_defines INTERFACE library
include(GodotSuffix)    # godot_compute_suffix() / godot_set_output()

if(GODOT_PLATFORM STREQUAL "windows")
  include(platform/Windows)   # godot_platform_windows INTERFACE library
endif()

include(GodotPython)      # Python interpreter + godot_add_generated()
include(GodotGenerated)   # core/platform non-shader .gen.* custom commands
include(GodotModules)     # module manifest (real discovery) + module-registration codegen
include(GodotShaders)     # RD + GLES3 *.glsl.gen.h shader headers
include(GodotComponent)   # godot_add_component() glob macro
include(GodotThirdparty)  # core/driver-owned thirdparty OBJECT libs

# Aggregate target covering every generated file wired above (drive/verify independently).
add_custom_target(godot_generated DEPENDS ${GODOT_GENERATED_OUTPUTS})

# ---- Component libraries ------------------------------------------------------------------
# core (core/SCsub): all of core/ + the 3 core generated .cpp + core thirdparty objects.
godot_add_component(godot_core ROOTS core
  GEN_SOURCES
    "${GODOT_GEN_DIR}/core/version_hash.gen.cpp"
    "${GODOT_GEN_DIR}/core/script_encryption_key.gen.cpp"
    "${GODOT_GEN_DIR}/core/input/default_controller_mappings.gen.cpp")
target_link_libraries(godot_core PRIVATE ${GODOT_CORE_THIRDPARTY})

# servers (servers/SCsub): includes RD shader headers; effects/ compiles AMD FSR2 thirdparty.
godot_add_component(godot_servers ROOTS servers)
target_link_libraries(godot_servers PRIVATE ${GODOT_SERVERS_THIRDPARTY})
if(GODOT_VULKAN OR GODOT_D3D12)
  target_include_directories(godot_servers PRIVATE "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2")
  target_compile_definitions(godot_servers PRIVATE FFX_GCC)
endif()

# scene (scene/SCsub): theme assets generated above; 3d/ always present for editor builds.
godot_add_component(godot_scene ROOTS scene)
target_link_libraries(godot_scene PRIVATE ${GODOT_SCENE_THIRDPARTY})

# drivers (drivers/SCsub): explicit subdir selection for windows+msvc+vulkan+opengl3 (NOT globbed;
# full glob would pull in alsa/pulseaudio/coreaudio/d3d12/metal/sdl). Plus driver thirdparty objects.
set(_drv_srcs "")
file(GLOB _drv_top CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/drivers/*.cpp")
list(APPEND _drv_srcs ${_drv_top})
set(_drv_dirs unix windows wasapi winmidi png)
if(GODOT_VULKAN)
  list(APPEND _drv_dirs vulkan)
endif()
if(GODOT_OPENGL3)
  list(APPEND _drv_dirs gl_context gles3 egl)
endif()
if(GODOT_SDL)
  list(APPEND _drv_dirs sdl)
endif()
foreach(_d IN LISTS _drv_dirs)
  file(GLOB_RECURSE _dd CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/drivers/${_d}/*.cpp")
  list(APPEND _drv_srcs ${_dd})
endforeach()
list(FILTER _drv_srcs EXCLUDE REGEX "\\.gen\\.cpp$")
add_library(godot_drivers STATIC ${_drv_srcs})
target_link_libraries(godot_drivers PUBLIC godot_defines godot_platform_windows PRIVATE ${GODOT_DRIVERS_THIRDPARTY} ${GODOT_SDL_THIRDPARTY})
if(GODOT_SDL)
  # drivers/sdl/*.cpp include <SDL3/SDL.h>.
  target_include_directories(godot_drivers PRIVATE
    "${CMAKE_SOURCE_DIR}/thirdparty/sdl" "${CMAKE_SOURCE_DIR}/thirdparty/sdl/include"
    "${CMAKE_SOURCE_DIR}/thirdparty/sdl/include/build_config" "${CMAKE_SOURCE_DIR}/drivers/sdl")
endif()
add_dependencies(godot_drivers godot_generated godot_shaders)
list(LENGTH _drv_srcs _n_drv)
message(STATUS "component godot_drivers: ${_n_drv} sources")

# platform/windows: NOT globbed -- platform/windows/SCsub uses an explicit source list with
# per-compiler/feature selection (SEH vs signal crash handler, angle/winrt extras, entry points).
# The executable entry (godot_windows.cpp), console wrapper, .rc/manifest, cpu_feature_validation,
# and the editor export/ subdir are handled with the final exe (Stage 7).
set(_plat_win
  os_windows.cpp display_server_windows.cpp key_mapping_windows.cpp windows_terminal_logger.cpp
  windows_utils.cpp native_menu_windows.cpp gl_manager_windows_native.cpp wgl_detect_version.cpp
  rendering_context_driver_vulkan_windows.cpp drop_target_windows.cpp crash_handler_windows_seh.cpp)
list(TRANSFORM _plat_win PREPEND "${CMAKE_SOURCE_DIR}/platform/windows/")
add_library(godot_platform STATIC ${_plat_win} "${GODOT_GEN_DIR}/platform/register_platform_apis.gen.cpp")
target_link_libraries(godot_platform PUBLIC godot_defines godot_platform_windows)

# TTS lives in a separate object lib: WinRT/OneCore TTS needs C++20 + exceptions (per
# platform/windows/SCsub), which conflicts with the engine's c++17 + _HAS_EXCEPTIONS=0. Without
# WinRT it's the SAPI driver at normal flags. WINRT_ENABLED is used only by these TTS files.
set(_tts_srcs platform/windows/tts_windows.cpp platform/windows/tts_driver_sapi.cpp
  platform/windows/winrt_utils.cpp)
if(GODOT_WINRT)
  list(APPEND _tts_srcs platform/windows/tts_driver_onecore.cpp)
endif()
add_library(godot_tts OBJECT ${_tts_srcs})
target_include_directories(godot_tts PRIVATE "${CMAKE_SOURCE_DIR}/platform/windows")
if(GODOT_WINRT)
  # Don't link godot_platform_windows (it forces _HAS_EXCEPTIONS=0); supply the needed flags here.
  target_link_libraries(godot_tts PRIVATE godot_defines)
  set_target_properties(godot_tts PROPERTIES CXX_STANDARD 20)
  # /Zc:__cplusplus is required or MSVC reports the old __cplusplus value and the engine's
  # C++17-minimum static_assert (core/typedefs.h) fails. /permissive- matches the engine compile.
  target_compile_options(godot_tts PRIVATE /MT /utf-8 /nologo /bigobj /EHsc /permissive- /Zc:__cplusplus)
  target_compile_definitions(godot_tts PRIVATE WINDOWS_ENABLED WINVER=0x0A00 _WIN32_WINNT=0x0A00
    NOMINMAX _WIN64 WINRT_ENABLED)
else()
  target_link_libraries(godot_tts PRIVATE godot_defines godot_platform_windows)
endif()
target_link_libraries(godot_platform PRIVATE godot_tts)
# register_platform_apis.gen.cpp does a bare #include "register_platform_apis.h" (sibling in source).
target_include_directories(godot_platform PRIVATE "${CMAKE_SOURCE_DIR}/platform")
add_dependencies(godot_platform godot_generated godot_shaders)
set_source_files_properties("${GODOT_GEN_DIR}/platform/register_platform_apis.gen.cpp" PROPERTIES GENERATED TRUE)

# editor (editor/SCsub): editor-build only; huge component + its codegen. Defines godot_editor.
include(GodotEditor)

# main (main/SCsub): entry-point glue; main.cpp pulls in editor codegen (now available).
godot_add_component(godot_main ROOTS main)

# ---- Final executable (Stage 7) -----------------------------------------------------------
include(GodotExecutable)

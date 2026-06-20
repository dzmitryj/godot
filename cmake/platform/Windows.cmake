# platform/Windows.cmake
#
# Creates the `godot_platform_windows` INTERFACE library carrying the MSVC compile/link flags,
# Windows OS/renderer defines, and the Win32 system-library list. Mirrors
# platform/windows/detect.py (configure_msvc) + the global flag blocks in SConstruct.
#
# MSVC-only for now (MinGW/clang-cl not handled). The editor's .rc/manifest resource is wired
# later (Stage 7) when the real executable is assembled.

if(NOT MSVC)
  message(FATAL_ERROR "platform/Windows.cmake currently supports the MSVC toolchain only "
                      "(detected compiler: ${CMAKE_CXX_COMPILER_ID}).")
endif()

# Needed to compile the Windows resource script (icon/manifest/version) into the executables.
enable_language(RC)

add_library(godot_platform_windows INTERFACE)

# ---- Compile flags (CCFLAGS in detect.py + SConstruct conformance/standard blocks) ---------
set(_cflags
  /fp:strict   # Strict floating point.
  /Gd /GR /nologo
  /utf-8       # Force Unicode source/exec charset.
  /bigobj      # Many template instantiations overflow the default section limit.
  /permissive- # Closer standards conformance (SConstruct ~925).
)
# /Zc:__cplusplus is C++-only.
target_compile_options(godot_platform_windows INTERFACE
  ${_cflags}
  $<$<COMPILE_LANGUAGE:CXX>:/Zc:__cplusplus>
)

# C++ runtime (detect.py ~392-399).
if(GODOT_USE_STATIC_CPP)
  target_compile_options(godot_platform_windows INTERFACE /MT)
else()
  target_compile_options(godot_platform_windows INTERFACE /MD)
endif()

# Architecture flags (SConstruct arch block). NOTE: platform/windows/cpu_feature_validation.c
# must be compiled WITHOUT /d2archSSE42 -- handled where that TU is added (Stage 5).
if(GODOT_ARCH STREQUAL "x86_64")
  target_compile_options(godot_platform_windows INTERFACE /d2archSSE42)
endif()

# Optimization (SConstruct ~842-853, driven by resolved optimize level).
if(GODOT_OPTIMIZE_RESOLVED MATCHES "^speed")
  target_compile_options(godot_platform_windows INTERFACE /O2)
elseif(GODOT_OPTIMIZE_RESOLVED MATCHES "^size")
  target_compile_options(godot_platform_windows INTERFACE /O1)
else() # none / debug
  target_compile_options(godot_platform_windows INTERFACE /Od)
endif()

# ---- Defines (detect.py configure_msvc + SConstruct exceptions block) ----------------------
set(_pdefs
  WINDOWS_ENABLED
  WASAPI_ENABLED
  WINMIDI_ENABLED
  TYPED_METHOD_BIND
  WIN32
  WINVER=0x0A00
  _WIN32_WINNT=0x0A00
  NOMINMAX
)
if(GODOT_ARCH STREQUAL "x86_64")
  list(APPEND _pdefs _WIN64)
endif()

# Exceptions disabled by default (SConstruct ~931-933): saves ~20% size/build time.
list(APPEND _pdefs _HAS_EXCEPTIONS=0)

# Renderer defines (detect.py ~503-535).
if(GODOT_VULKAN)
  list(APPEND _pdefs VULKAN_ENABLED RD_ENABLED)
endif()
if(GODOT_OPENGL3)
  list(APPEND _pdefs GLES3_ENABLED)
endif()
if(GODOT_SDL)
  list(APPEND _pdefs SDL_ENABLED)
endif()

if(GODOT_WINDOWS_SUBSYSTEM STREQUAL "console")
  list(APPEND _pdefs WINDOWS_SUBSYSTEM_CONSOLE)
endif()

target_compile_definitions(godot_platform_windows INTERFACE ${_pdefs})

# platform/windows is on the include path (detect.py ~1039: Prepend CPPPATH #platform/windows).
target_include_directories(godot_platform_windows INTERFACE "${CMAKE_SOURCE_DIR}/platform/windows")

# ---- Link flags (detect.py + SConstruct link blocks) ---------------------------------------
set(_lflags /INCREMENTAL:NO /STACK:8388608)
if(GODOT_WINDOWS_SUBSYSTEM STREQUAL "console")
  list(APPEND _lflags /SUBSYSTEM:CONSOLE)
else()
  list(APPEND _lflags /SUBSYSTEM:WINDOWS)
endif()

# Debug symbols (SConstruct ~836-840).
if(GODOT_DEBUG_SYMBOLS)
  target_compile_options(godot_platform_windows INTERFACE /Zi /FS)
  list(APPEND _lflags /DEBUG:FULL)
else()
  list(APPEND _lflags /DEBUG:NONE)
endif()

# Linker optimization to match the compile optimize level (SConstruct ~844-849).
if(GODOT_OPTIMIZE_RESOLVED MATCHES "^speed")
  list(APPEND _lflags /OPT:REF)
  if(GODOT_OPTIMIZE_RESOLVED STREQUAL "speed_trace")
    list(APPEND _lflags /OPT:NOICF)
  endif()
elseif(GODOT_OPTIMIZE_RESOLVED MATCHES "^size")
  list(APPEND _lflags /OPT:REF)
endif()

# Native Visualizers for debuggers (detect.py ~590). Guarded on existence.
if(EXISTS "${CMAKE_SOURCE_DIR}/platform/windows/godot.natvis")
  list(APPEND _lflags "/NATVIS:${CMAKE_SOURCE_DIR}/platform/windows/godot.natvis")
endif()

target_link_options(godot_platform_windows INTERFACE ${_lflags})

# ---- Win32 system libraries (detect.py ~440-471) -------------------------------------------
set(_syslibs
  winmm dsound kernel32 ole32 oleaut32 sapi user32 gdi32 IPHLPAPI Shlwapi Shcore
  wsock32 Ws2_32 shell32 advapi32 dinput8 dxguid imm32 bcrypt Crypt32 Avrt dwmapi
  dwrite wbemuuid ntdll hid mincore
)
if(GODOT_DEBUG_FEATURES)
  list(APPEND _syslibs psapi dbghelp)
endif()
if(GODOT_VULKAN AND NOT GODOT_USE_VOLK)
  list(APPEND _syslibs vulkan)
endif()

target_link_libraries(godot_platform_windows INTERFACE ${_syslibs})

message(STATUS "godot_platform_windows: subsystem=${GODOT_WINDOWS_SUBSYSTEM} static_cpp=${GODOT_USE_STATIC_CPP} "
               "optimize=${GODOT_OPTIMIZE_RESOLVED}")

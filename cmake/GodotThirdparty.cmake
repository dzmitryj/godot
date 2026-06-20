# GodotThirdparty.cmake
#
# Core/driver-owned bundled thirdparty libraries, built as OBJECT libs with warnings disabled
# (/w) but the engine's base flags/runtime (via godot_platform_windows). Each source list is
# TRANSCRIBED from the owning SCsub and WILL DRIFT on engine bumps -- the SCsub path is noted.
#
# Module-owned thirdparty (freetype, harfbuzz, icu, thorvg, pcre2, ...) lives in GodotModules.cmake.

set(_TP "${CMAKE_SOURCE_DIR}/thirdparty")

# godot_add_thirdparty(<name> SOURCES <rel-to-thirdparty> ... [INCLUDES <dir> ...] [DEFINES <d> ...])
function(godot_add_thirdparty name)
  cmake_parse_arguments(T "" "" "SOURCES;INCLUDES;DEFINES" ${ARGN})
  set(_abs "")
  foreach(_s IN LISTS T_SOURCES)
    list(APPEND _abs "${_TP}/${_s}")
  endforeach()
  add_library(${name} OBJECT ${_abs})
  # SCons compiles thirdparty with a clone of the FULL env (all engine defines + include roots),
  # only disabling warnings. Some "misc" thirdparty (polypartition, pcg) include engine headers,
  # so they need godot_defines (source root + gen + global defines) as well as the platform flags.
  target_link_libraries(${name} PRIVATE godot_defines)
  if(TARGET godot_platform_windows)
    target_link_libraries(${name} PRIVATE godot_platform_windows)
  endif()
  target_compile_options(${name} PRIVATE /w)   # thirdparty: warnings off (matches disable_warnings()).
  foreach(_i IN LISTS T_INCLUDES)
    target_include_directories(${name} PRIVATE "${_TP}/${_i}")
  endforeach()
  if(T_DEFINES)
    target_compile_definitions(${name} PRIVATE ${T_DEFINES})
  endif()
endfunction()

# Thirdparty include dirs that core/SCsub Prepends onto the MAIN env (engine code uses
# <zlib.h>, brotli, clipper2, zstd directly). Put them on godot_defines so every component sees them.
target_include_directories(godot_defines INTERFACE
  "${_TP}/zlib" "${_TP}/zstd" "${_TP}/brotli/include" "${_TP}/clipper2/include")

# core/crypto/crypto_core.cpp includes <mbedtls/...>; the mbedtls module's configure() adds this
# include globally in SCons (mbedtls is enabled by default). Provide it engine-wide here.
target_include_directories(godot_defines INTERFACE "${_TP}/mbedtls/include")

# Vulkan/volk: drivers/vulkan/SCsub Prepends these onto the MAIN env (so servers/display etc. see them).
if(GODOT_VULKAN)
  target_include_directories(godot_defines INTERFACE "${_TP}/vulkan" "${_TP}/vulkan/include")
  target_compile_definitions(godot_defines INTERFACE VK_USE_PLATFORM_WIN32_KHR "VMA_EXTERNAL_MEMORY_WIN32=0")
  if(GODOT_USE_VOLK)
    target_include_directories(godot_defines INTERFACE "${_TP}/volk")
    target_compile_definitions(godot_defines INTERFACE USE_VOLK)
  endif()
endif()

# glad GL loader (opengl3): display_server / gl_manager include <glad/gl.h>; the dir also holds KHR/.
if(GODOT_OPENGL3)
  target_include_directories(godot_defines INTERFACE "${_TP}/glad")
  target_compile_definitions(godot_defines INTERFACE GLAD_ENABLED)  # gl_context/SCsub adds globally.
endif()

# libpng (drivers/png/SCsub Prepends onto the MAIN env -- drivers includes + platform/web use it).
target_include_directories(godot_defines INTERFACE "${_TP}/libpng")

# Bare-basename generated includes (e.g. core/extension/gdextension_interface.cpp does
# #include "gdextension_interface.gen.h"; core/profiling/profiling.h does #include "profiling.gen.h").
# Expose the mirrored gen dirs engine-wide.
target_include_directories(godot_defines INTERFACE
  "${GODOT_GEN_DIR}/core/extension"
  "${GODOT_GEN_DIR}/core/profiling"
  "${GODOT_GEN_DIR}/platform/windows/export")

# ---- core/SCsub thirdparty ----------------------------------------------------------------
godot_add_thirdparty(tp_misc SOURCES
  misc/fastlz.c misc/r128.c misc/smaz.c misc/pcg.cpp misc/polypartition.cpp misc/smolv.cpp)

if(GODOT_BROTLI)
  godot_add_thirdparty(tp_brotli
    SOURCES
      brotli/common/constants.c brotli/common/context.c brotli/common/dictionary.c
      brotli/common/platform.c brotli/common/shared_dictionary.c brotli/common/transform.c
      brotli/dec/bit_reader.c brotli/dec/decode.c brotli/dec/huffman.c brotli/dec/prefix.c
      brotli/dec/state.c brotli/dec/static_init.c
    INCLUDES brotli/include)
endif()

godot_add_thirdparty(tp_clipper2
  SOURCES clipper2/src/clipper.engine.cpp clipper2/src/clipper.offset.cpp clipper2/src/clipper.rectclip.cpp
  INCLUDES clipper2/include DEFINES CLIPPER2_ENABLED)

godot_add_thirdparty(tp_zlib SOURCES
  zlib/adler32.c zlib/compress.c zlib/crc32.c zlib/deflate.c zlib/inffast.c zlib/inflate.c
  zlib/inftrees.c zlib/trees.c zlib/uncompr.c zlib/zutil.c
  INCLUDES zlib)

godot_add_thirdparty(tp_minizip SOURCES
  minizip/ioapi.c minizip/unzip.c minizip/zip.c
  INCLUDES zlib)

godot_add_thirdparty(tp_zstd SOURCES
  zstd/common/debug.c zstd/common/entropy_common.c zstd/common/error_private.c
  zstd/common/fse_decompress.c zstd/common/pool.c zstd/common/threading.c zstd/common/xxhash.c
  zstd/common/zstd_common.c zstd/compress/fse_compress.c zstd/compress/hist.c
  zstd/compress/huf_compress.c zstd/compress/zstd_compress.c zstd/compress/zstd_double_fast.c
  zstd/compress/zstd_fast.c zstd/compress/zstd_lazy.c zstd/compress/zstd_ldm.c
  zstd/compress/zstd_opt.c zstd/compress/zstd_preSplit.c zstd/compress/zstdmt_compress.c
  zstd/compress/zstd_compress_literals.c zstd/compress/zstd_compress_sequences.c
  zstd/compress/zstd_compress_superblock.c zstd/decompress/huf_decompress.c
  zstd/decompress/zstd_ddict.c zstd/decompress/zstd_decompress_block.c zstd/decompress/zstd_decompress.c
  INCLUDES zstd zstd/common DEFINES ZSTD_STATIC_LINKING_ONLY)

# Objects compiled into the core component (core/SCsub: env.core_sources += thirdparty_obj).
set(GODOT_CORE_THIRDPARTY tp_misc tp_clipper2 tp_zlib tp_minizip tp_zstd CACHE INTERNAL "")
if(GODOT_BROTLI)
  set(GODOT_CORE_THIRDPARTY "${GODOT_CORE_THIRDPARTY};tp_brotli" CACHE INTERNAL "")
endif()

# ---- drivers thirdparty -------------------------------------------------------------------
# libpng (drivers/png/SCsub) + x86 SSE intrinsics.
set(_png_srcs
  libpng/png.c libpng/pngerror.c libpng/pngget.c libpng/pngmem.c libpng/pngpread.c libpng/pngread.c
  libpng/pngrio.c libpng/pngrtran.c libpng/pngrutil.c libpng/pngset.c libpng/pngtrans.c libpng/pngwio.c
  libpng/pngwrite.c libpng/pngwtran.c libpng/pngwutil.c)
if(GODOT_ARCH STREQUAL "x86_64" OR GODOT_ARCH STREQUAL "x86_32")
  list(APPEND _png_srcs libpng/intel/intel_init.c libpng/intel/filter_sse2_intrinsics.c)
  godot_add_thirdparty(tp_libpng SOURCES ${_png_srcs} INCLUDES libpng DEFINES PNG_INTEL_SSE)
else()
  godot_add_thirdparty(tp_libpng SOURCES ${_png_srcs} INCLUDES libpng)
endif()
set(GODOT_DRIVERS_THIRDPARTY tp_libpng CACHE INTERNAL "")

# glad GL loader (opengl3, windows: gl.c only; no egl.c without ANGLE).
if(GODOT_OPENGL3)
  godot_add_thirdparty(tp_glad SOURCES glad/gl.c INCLUDES glad)
  set(GODOT_DRIVERS_THIRDPARTY "${GODOT_DRIVERS_THIRDPARTY};tp_glad" CACHE INTERNAL "")
endif()

# Vulkan: VMA + volk + re-spirv (drivers/vulkan/SCsub).
if(GODOT_VULKAN)
  if(GODOT_USE_VOLK)
    godot_add_thirdparty(tp_vulkan_vma SOURCES vulkan/vk_mem_alloc.cpp DEFINES VMA_STATIC_VULKAN_FUNCTIONS=1)
    godot_add_thirdparty(tp_volk SOURCES volk/volk.c)
    set(GODOT_DRIVERS_THIRDPARTY "${GODOT_DRIVERS_THIRDPARTY};tp_vulkan_vma;tp_volk" CACHE INTERNAL "")
  else()
    godot_add_thirdparty(tp_vulkan_vma SOURCES vulkan/vk_mem_alloc.cpp)
    set(GODOT_DRIVERS_THIRDPARTY "${GODOT_DRIVERS_THIRDPARTY};tp_vulkan_vma" CACHE INTERNAL "")
  endif()
  godot_add_thirdparty(tp_respirv SOURCES re-spirv/re-spirv.cpp INCLUDES spirv-headers/include)
  set(GODOT_DRIVERS_THIRDPARTY "${GODOT_DRIVERS_THIRDPARTY};tp_respirv" CACHE INTERNAL "")
endif()

# ---- servers/rendering/renderer_rd/effects/SCsub thirdparty (AMD FSR2) ---------------------
if(GODOT_VULKAN OR GODOT_D3D12)
  godot_add_thirdparty(tp_fsr2 SOURCES amd-fsr2/ffx_assert.cpp amd-fsr2/ffx_fsr2.cpp
    INCLUDES amd-fsr2 DEFINES FFX_GCC)
  set(GODOT_SERVERS_THIRDPARTY tp_fsr2 CACHE INTERNAL "")
else()
  set(GODOT_SERVERS_THIRDPARTY "" CACHE INTERNAL "")
endif()
# servers/rendering/renderer_rd/spirv-reflect/SCsub
if(GODOT_VULKAN OR GODOT_D3D12)
  godot_add_thirdparty(tp_spirv_reflect SOURCES spirv-reflect/spirv_reflect.c)
  set(GODOT_SERVERS_THIRDPARTY "${GODOT_SERVERS_THIRDPARTY};tp_spirv_reflect" CACHE INTERNAL "")
endif()

# ---- scene/resources/SCsub thirdparty (mikktspace + qoa) ----------------------------------
godot_add_thirdparty(tp_scene_misc SOURCES misc/mikktspace.c misc/qoa.c)
set(GODOT_SCENE_THIRDPARTY tp_scene_misc CACHE INTERNAL "")

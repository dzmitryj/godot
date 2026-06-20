# GodotModuleThirdparty.cmake
#
# Builds each module's bundled-thirdparty OBJECT library from the extracted source lists
# (cmake/thirdparty_lists/<module>.cmake, produced by misc/cmake/extract_thirdparty.py) and links
# it into module_<name>. Compiled with warnings off (/w) but the engine's base flags/defines
# (godot_defines + platform), plus each lib's own include dirs / build defines.
#
# Included from GodotModules.cmake after GodotModuleExtras (which sets the module libs' includes).

set(_T "${CMAKE_SOURCE_DIR}/thirdparty")
set(GODOT_ORPHAN_TP "" CACHE INTERNAL "")  # tp libs from thirdparty-only modules -> linked into exe

# godot_module_tp(<mod> [INCLUDES <dir>...] [DEFINES <d>...])
# Reads GODOT_TP_<MOD>_SOURCES from the list file, builds tp_<mod>, and links it into module_<mod>
# (or, for thirdparty-only modules with no own .cpp like freetype/msdfgen, defers to the exe link).
function(godot_module_tp mod)
  cmake_parse_arguments(TP "" "EXCLUDE" "INCLUDES;DEFINES;EXTRA" ${ARGN})
  string(TOUPPER "${mod}" _MOD)
  include("${CMAKE_SOURCE_DIR}/cmake/thirdparty_lists/${mod}.cmake" OPTIONAL RESULT_VARIABLE _inc)
  set(_var "GODOT_TP_${_MOD}_SOURCES")
  if(NOT DEFINED ${_var})
    message(WARNING "godot_module_tp(${mod}): no source list (${_var}); skipping")
    return()
  endif()
  set(_list ${${_var}})
  if(TP_EXCLUDE)
    list(FILTER _list EXCLUDE REGEX "${TP_EXCLUDE}")
  endif()
  set(_srcs "")
  foreach(_f IN LISTS _list)
    list(APPEND _srcs "${CMAKE_SOURCE_DIR}/${_f}")
  endforeach()
  foreach(_e IN LISTS TP_EXTRA)  # files the list extractor can't see (assigned via vars, etc.)
    list(APPEND _srcs "${_T}/${_e}")
  endforeach()
  add_library(tp_${mod} OBJECT ${_srcs})
  target_link_libraries(tp_${mod} PRIVATE godot_defines)
  if(TARGET godot_platform_windows)
    target_link_libraries(tp_${mod} PRIVATE godot_platform_windows)
  endif()
  target_compile_options(tp_${mod} PRIVATE /w)
  if(TP_INCLUDES)
    target_include_directories(tp_${mod} PRIVATE ${TP_INCLUDES})
  endif()
  if(TP_DEFINES)
    target_compile_definitions(tp_${mod} PRIVATE ${TP_DEFINES})
  endif()
  if(TARGET module_${mod})
    target_link_libraries(module_${mod} PRIVATE tp_${mod})
  else()
    set(GODOT_ORPHAN_TP "${GODOT_ORPHAN_TP};tp_${mod}" CACHE INTERNAL "")
  endif()
endfunction()

# ---- Simple / self-contained libs ---------------------------------------------------------
godot_module_tp(enet      INCLUDES "${_T}/enet")
godot_module_tp(ogg       INCLUDES "${_T}/libogg")
godot_module_tp(vorbis    INCLUDES "${_T}/libvorbis" "${_T}/libogg")
# theora x86/*.c use GCC inline asm (incompatible with MSVC); exclude -> portable C path.
godot_module_tp(theora    INCLUDES "${_T}/libtheora" "${_T}/libtheora/include" "${_T}/libogg"
  EXCLUDE "/x86(_vc)?/")
godot_module_tp(webp      INCLUDES "${_T}/libwebp" "${_T}/libwebp/src")
godot_module_tp(jpg       INCLUDES "${_T}/libjpeg-turbo" "${_T}/libjpeg-turbo/src")
# libjpeg-turbo compiles its bit-dependent files twice (8-bit default + 12-bit). The extracted
# list covers the default (8); add the 12-bit variant (j12init_*/jpeg12_* symbols).
if(TARGET module_jpg)
  set(_jpg12 jcapistd jccoefct jccolor jcdctmgr jcmainct jcprepct jcsample jdcoefct jdcolor
             jdapistd jddctmgr jdmainct jdmerge jdpostct jdsample jfdctfst jfdctint jidctflt
             jidctfst jidctint jidctred jutils jquant1 jquant2)
  set(_jpg12_srcs "")
  foreach(_f IN LISTS _jpg12)
    list(APPEND _jpg12_srcs "${_T}/libjpeg-turbo/src/${_f}.c")
  endforeach()
  add_library(tp_jpg_12 OBJECT ${_jpg12_srcs})
  target_link_libraries(tp_jpg_12 PRIVATE godot_defines godot_platform_windows)
  target_compile_options(tp_jpg_12 PRIVATE /w)
  target_include_directories(tp_jpg_12 PRIVATE "${_T}/libjpeg-turbo" "${_T}/libjpeg-turbo/src")
  target_compile_definitions(tp_jpg_12 PRIVATE "BITS_IN_JSAMPLE=12")
  target_link_libraries(module_jpg PRIVATE tp_jpg_12)
endif()
godot_module_tp(astcenc   INCLUDES "${_T}/astcenc")
godot_module_tp(etcpak    INCLUDES "${_T}/etcpak")
godot_module_tp(cvtt      INCLUDES "${_T}/cvtt")
godot_module_tp(meshoptimizer INCLUDES "${_T}/meshoptimizer")
godot_module_tp(vhacd     INCLUDES "${_T}/vhacd" "${_T}/vhacd/inc" "${_T}/vhacd/public")
godot_module_tp(xatlas_unwrap INCLUDES "${_T}/xatlas")
godot_module_tp(tinyexr   INCLUDES "${_T}/tinyexr" DEFINES TINYEXR_USE_THREAD "TINYEXR_USE_MINIZ=0")
godot_module_tp(fbx       INCLUDES "${_T}/ufbx")
godot_module_tp(navigation_2d INCLUDES "${_T}/rvo2/rvo2_2d")
godot_module_tp(navigation_3d INCLUDES "${_T}/recastnavigation/Recast/Include" "${_T}/rvo2/rvo2_2d" "${_T}/rvo2/rvo2_3d")

# ---- Fonts / text -------------------------------------------------------------------------
# freetype: sfnt.c is added via a variable in the SCsub (extractor can't see it) -> EXTRA.
godot_module_tp(freetype INCLUDES "${_T}/freetype/include" "${_T}/libpng" "${_T}/zlib" "${_T}/harfbuzz/src"
  EXTRA freetype/src/sfnt/sfnt.c
  DEFINES FT2_BUILD_LIBRARY FT_CONFIG_OPTION_USE_PNG FT_CONFIG_OPTION_SYSTEM_ZLIB
          FT_CONFIG_OPTION_USE_BROTLI FT_CONFIG_OPTION_USE_HARFBUZZ)
godot_module_tp(msdfgen INCLUDES "${_T}/msdfgen" "${_T}/freetype/include" "${_T}/nanosvg" DEFINES "MSDFGEN_PUBLIC=")

# ---- Security -----------------------------------------------------------------------------
godot_module_tp(mbedtls INCLUDES "${_T}/mbedtls/include")

# ---- Net ----------------------------------------------------------------------------------
godot_module_tp(upnp INCLUDES "${_T}/miniupnpc" "${_T}/miniupnpc/include" "${_T}/miniupnpc/include/miniupnpc"
  DEFINES MINIUPNP_STATICLIB MINIUPNPC_SET_SOCKET_TIMEOUT _WINSOCK_DEPRECATED_NO_WARNINGS)
godot_module_tp(websocket INCLUDES "${_T}/wslay" "${_T}/wslay/wslay" DEFINES HAVE_CONFIG_H HAVE_WINSOCK2_H)

# ---- Codecs / compression -----------------------------------------------------------------
godot_module_tp(basis_universal INCLUDES "${_T}/basis_universal" "${_T}/tinyexr" "${_T}/zstd")
godot_module_tp(ktx INCLUDES "${_T}/libktx/include" "${_T}/libktx/utils" "${_T}/libktx/lib"
  "${_T}/libktx/other_include" "${_T}/libktx/external" "${_T}/basis_universal"
  DEFINES KHRONOS_STATIC BASISU_SUPPORT_OPENCL=0 LIBKTX)

# ---- Geometry / physics / 3D --------------------------------------------------------------
godot_module_tp(glslang INCLUDES "${_T}/glslang" "${_T}" "${_T}/spirv-headers/include/spirv/unified1"
  DEFINES "ENABLE_OPT=0")
godot_module_tp(jolt_physics INCLUDES "${_T}/jolt_physics")
godot_module_tp(csg INCLUDES "${_T}/manifold/include" "${_T}/manifold/src" DEFINES "MANIFOLD_PAR=-1")
godot_module_tp(raycast INCLUDES "${_T}/embree" "${_T}/embree/include" "${_T}/embree/common"
  DEFINES EMBREE_TARGET_SSE2 EMBREE_LOWEST_ISA TASKING_INTERNAL NDEBUG __SSE__ __SSE2__)

# ---- OpenXR loader + jsoncpp (modules/openxr/SCsub uses per-file add_source_files) ---------
if(TARGET module_openxr)
  set(_oxr "${_T}/openxr")
  add_library(tp_openxr OBJECT
    "${_oxr}/src/external/jsoncpp/src/lib_json/json_reader.cpp"
    "${_oxr}/src/external/jsoncpp/src/lib_json/json_value.cpp"
    "${_oxr}/src/external/jsoncpp/src/lib_json/json_writer.cpp"
    "${_oxr}/src/xr_generated_dispatch_table_core.c"
    "${_oxr}/src/common/filesystem_utils.cpp"
    "${_oxr}/src/common/object_info.cpp"
    "${_oxr}/src/loader/api_layer_interface.cpp"
    "${_oxr}/src/loader/loader_core.cpp"
    "${_oxr}/src/loader/loader_init_data.cpp"
    "${_oxr}/src/loader/loader_instance.cpp"
    "${_oxr}/src/loader/loader_logger_recorders.cpp"
    "${_oxr}/src/loader/loader_logger.cpp"
    "${_oxr}/src/loader/loader_properties.cpp"
    "${_oxr}/src/loader/manifest_file.cpp"
    "${_oxr}/src/loader/runtime_interface.cpp")
  target_link_libraries(tp_openxr PRIVATE godot_defines godot_platform_windows)
  target_compile_options(tp_openxr PRIVATE /w)
  target_include_directories(tp_openxr PRIVATE "${_oxr}" "${_oxr}/include" "${_oxr}/src"
    "${_oxr}/src/common" "${_oxr}/src/external/jsoncpp/include" "${_oxr}/src/loader")
  target_compile_definitions(tp_openxr PRIVATE XR_OS_WINDOWS XR_USE_PLATFORM_WIN32 NOMINMAX
    DISABLE_STD_FILESYSTEM XRLOADER_DISABLE_EXCEPTION_HANDLING "JSON_USE_EXCEPTION=0")
  target_link_libraries(module_openxr PRIVATE tp_openxr)
endif()

# ---- Regex / vector / text-server (heaviest) ----------------------------------------------
# pcre2: the SAME sources are compiled once per code-unit width (16 + 32). The module's own
# .cpp use width 0 (handled in GodotModuleExtras). Build two width-specific OBJECT libs.
if(TARGET module_regex)
  include("${CMAKE_SOURCE_DIR}/cmake/thirdparty_lists/regex.cmake" OPTIONAL)
  set(_pcre_srcs "")
  foreach(_f IN LISTS GODOT_TP_REGEX_SOURCES)
    list(APPEND _pcre_srcs "${CMAKE_SOURCE_DIR}/${_f}")
  endforeach()
  foreach(_w 16 32)
    add_library(tp_regex_${_w} OBJECT ${_pcre_srcs})
    target_link_libraries(tp_regex_${_w} PRIVATE godot_defines godot_platform_windows)
    target_compile_options(tp_regex_${_w} PRIVATE /w)
    target_include_directories(tp_regex_${_w} PRIVATE "${_T}/pcre2/src")
    target_compile_definitions(tp_regex_${_w} PRIVATE
      PCRE2_STATIC HAVE_CONFIG_H SUPPORT_UNICODE SUPPORT_JIT "PCRE2_CODE_UNIT_WIDTH=${_w}")
    target_link_libraries(module_regex PRIVATE tp_regex_${_w})
  endforeach()
endif()
godot_module_tp(svg INCLUDES "${_T}/thorvg/inc" "${_T}/thorvg/src/common" "${_T}/thorvg/src/loaders/svg"
  "${_T}/thorvg/src/renderer" "${_T}/thorvg/src/renderer/sw_engine" "${_T}/thorvg/src/loaders/raw"
  "${_T}/thorvg/src/loaders/external_png" "${_T}/libpng"
  "${_T}/thorvg/src/loaders/external_webp" "${_T}/libwebp/src"
  "${_T}/thorvg/src/loaders/external_jpg" "${_T}/libjpeg-turbo/src"
  DEFINES TVG_STATIC THORVG_FILE_IO_SUPPORT THORVG_WEBP_LOADER_SUPPORT THORVG_JPG_LOADER_SUPPORT)
# text_server_adv: split the extracted list into harfbuzz / graphite / icu sub-libs, each with the
# distinct defines/includes from modules/text_server_adv/SCsub. Heaviest module by far.
if(TARGET module_text_server_adv)
  include("${CMAKE_SOURCE_DIR}/cmake/thirdparty_lists/text_server_adv.cmake" OPTIONAL)
  set(_hb "")
  set(_gr "")
  set(_icu "")
  foreach(_f IN LISTS GODOT_TP_TEXT_SERVER_ADV_SOURCES)
    if(_f MATCHES "thirdparty/harfbuzz/")
      list(APPEND _hb "${CMAKE_SOURCE_DIR}/${_f}")
    elseif(_f MATCHES "thirdparty/graphite/")
      # MSVC uses call_machine.cpp; direct_machine.cpp is GCC computed-goto (skip).
      if(NOT _f MATCHES "direct_machine")
        list(APPEND _gr "${CMAKE_SOURCE_DIR}/${_f}")
      endif()
    elseif(_f MATCHES "thirdparty/icu4c/")
      # icudata_stub is for non-editor builds; editor uses the generated icudata.gen.h.
      if(NOT _f MATCHES "icudata_stub")
        list(APPEND _icu "${CMAKE_SOURCE_DIR}/${_f}")
      endif()
    endif()
  endforeach()

  add_library(tp_ts_graphite OBJECT ${_gr})
  target_link_libraries(tp_ts_graphite PRIVATE godot_defines godot_platform_windows)
  target_compile_options(tp_ts_graphite PRIVATE /w)
  target_include_directories(tp_ts_graphite PRIVATE "${_T}/graphite/src" "${_T}/graphite/include")
  target_compile_definitions(tp_ts_graphite PRIVATE GRAPHITE2_STATIC GRAPHITE2_NTRACING GRAPHITE2_NFILEFACE)

  add_library(tp_ts_harfbuzz OBJECT ${_hb})
  target_link_libraries(tp_ts_harfbuzz PRIVATE godot_defines godot_platform_windows)
  target_compile_options(tp_ts_harfbuzz PRIVATE /w)
  target_include_directories(tp_ts_harfbuzz PRIVATE "${_T}/harfbuzz/src" "${_T}/icu4c/common"
    "${_T}/icu4c/i18n" "${_T}/freetype/include" "${_T}/graphite/include")
  target_compile_definitions(tp_ts_harfbuzz PRIVATE HAVE_ICU HAVE_ZLIB HAVE_PNG U_STATIC_IMPLEMENTATION
    "U_HAVE_LIB_SUFFIX=1" "U_LIB_SUFFIX_C_NAME=_godot" HAVE_ICU_BUILTIN HAVE_FREETYPE HAVE_GRAPHITE2 GRAPHITE2_STATIC)

  add_library(tp_ts_icu OBJECT ${_icu})
  target_link_libraries(tp_ts_icu PRIVATE godot_defines godot_platform_windows)
  target_compile_options(tp_ts_icu PRIVATE /w)
  target_include_directories(tp_ts_icu PRIVATE "${_T}/icu4c/common" "${_T}/icu4c/i18n")
  target_compile_definitions(tp_ts_icu PRIVATE U_STATIC_IMPLEMENTATION U_COMMON_IMPLEMENTATION
    UCONFIG_NO_COLLATION UCONFIG_NO_CONVERSION UCONFIG_NO_FORMATTING UCONFIG_NO_SERVICE UCONFIG_NO_IDNA
    UCONFIG_NO_FILE_IO UCONFIG_NO_TRANSLITERATION UCONFIG_NO_REGULAR_EXPRESSIONS "PKGDATA_MODE=static"
    "U_ENABLE_DYLOAD=0" "U_HAVE_LIB_SUFFIX=1" "U_LIB_SUFFIX_C_NAME=_godot")

  target_link_libraries(module_text_server_adv PRIVATE tp_ts_harfbuzz tp_ts_graphite tp_ts_icu)

  # ICU static data header (editor build), embedded from icudt_godot.dat.
  godot_add_generated(OUTPUT thirdparty/icu4c/icudata.gen.h
    MODULE_PATH modules/text_server_adv/text_server_adv_builders.py FUNC make_icu_data
    SOURCES "file:thirdparty/icu4c/icudt_godot.dat")
  add_custom_target(godot_icudata DEPENDS "${GODOT_GEN_DIR}/thirdparty/icu4c/icudata.gen.h")
  add_dependencies(module_text_server_adv godot_icudata)
endif()

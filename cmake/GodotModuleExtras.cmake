# GodotModuleExtras.cmake
#
# Per-module include dirs / defines / generated headers needed to COMPILE each module's sources,
# transcribed from the module SCsubs. These mirror each `env_<module>.Prepend(CPPPATH=...)` /
# `.Append(CPPDEFINES=...)`. (Bundled thirdparty OBJECT libraries — needed at LINK time — are a
# separate concern; see GodotModuleThirdparty.cmake.)
#
# WILL DRIFT with the module SCsubs. Included from GodotModules.cmake after the module-lib loop.

# Convenience: only touch a module lib if it exists (module enabled + had sources).
macro(_mod_inc mod)
  if(TARGET module_${mod})
    target_include_directories(module_${mod} PRIVATE ${ARGN})
  endif()
endmacro()
macro(_mod_def mod)
  if(TARGET module_${mod})
    target_compile_definitions(module_${mod} PRIVATE ${ARGN})
  endif()
endmacro()

set(_T "${CMAKE_SOURCE_DIR}/thirdparty")

# freetype/include is Prepended onto the GLOBAL env by modules/freetype/SCsub (other modules +
# scene use FreeType headers), so expose it engine-wide.
target_include_directories(godot_defines INTERFACE "${_T}/freetype/include")

# ---- Text / fonts / vector --------------------------------------------------------------
_mod_inc(freetype "${_T}/freetype/include")
_mod_def(freetype FT2_BUILD_LIBRARY FT_CONFIG_OPTION_USE_PNG FT_CONFIG_OPTION_SYSTEM_ZLIB)
if(GODOT_BROTLI)
  _mod_def(freetype FT_CONFIG_OPTION_USE_BROTLI)
endif()

_mod_inc(svg "${_T}/thorvg/inc")
_mod_def(svg TVG_STATIC THORVG_FILE_IO_SUPPORT)

_mod_inc(msdfgen "${_T}/freetype/include" "${_T}/msdfgen" "${_T}/nanosvg")
_mod_def(msdfgen "MSDFGEN_PUBLIC=")

_mod_inc(text_server_adv "${_T}/harfbuzz/src" "${_T}/icu4c/common" "${_T}/icu4c/i18n"
         "${_T}/freetype/include" "${_T}/msdfgen" "${_T}/nanosvg"
         "${_T}/thorvg/inc" "${_T}/thorvg/src/common" "${_T}/thorvg/src/renderer"
         "${_T}/graphite/include" "${GODOT_GEN_DIR}/thirdparty/icu4c")
_mod_def(text_server_adv HAVE_ICU_BUILTIN TVG_STATIC "MSDFGEN_PUBLIC=" FT_CONFIG_OPTION_USE_BROTLI
         U_STATIC_IMPLEMENTATION "U_HAVE_LIB_SUFFIX=1" "U_LIB_SUFFIX_C_NAME=_godot" ICU_STATIC_DATA)

# ---- Regex / net / compression ----------------------------------------------------------
_mod_inc(regex "${_T}/pcre2/src")
_mod_def(regex "PCRE2_CODE_UNIT_WIDTH=0" PCRE2_STATIC)
_mod_inc(enet "${_T}/enet")
_mod_def(enet GODOT_ENET)
_mod_inc(upnp "${_T}/miniupnpc/include" "${_T}/miniupnpc/include/miniupnpc")
_mod_def(upnp MINIUPNP_STATICLIB)
_mod_inc(websocket "${_T}/wslay")
_mod_def(websocket HAVE_CONFIG_H HAVE_WINSOCK2_H)

# ---- Audio / video ----------------------------------------------------------------------
_mod_inc(ogg "${_T}/libogg")
_mod_inc(vorbis "${_T}/libvorbis" "${_T}/libogg")
_mod_inc(theora "${_T}/libtheora" "${_T}/libogg" "${_T}/libvorbis")

# ---- Image codecs -----------------------------------------------------------------------
_mod_inc(webp "${_T}/libwebp" "${_T}/libwebp/src")
_mod_inc(jpg "${_T}/libjpeg-turbo/src")
_mod_inc(basis_universal "${_T}/basis_universal" "${_T}/tinyexr" "${_T}/zstd")
_mod_inc(astcenc "${_T}/astcenc")
_mod_inc(etcpak "${_T}/etcpak")
_mod_inc(cvtt "${_T}/cvtt")
_mod_inc(bcdec "${_T}/bcdec")
_mod_inc(dds "${_T}/bcdec")
_mod_inc(ktx "${_T}/libktx/include" "${_T}/libktx/utils" "${_T}/libktx/lib"
         "${_T}/libktx/other_include" "${_T}/libktx/external" "${_T}/basis_universal")
_mod_def(ktx KHRONOS_STATIC LIBKTX "BASISU_SUPPORT_OPENCL=0")
_mod_inc(tinyexr "${_T}/tinyexr")
_mod_def(tinyexr TINYEXR_USE_THREAD "TINYEXR_USE_MINIZ=0")

# ---- 3D / geometry / physics ------------------------------------------------------------
_mod_inc(glslang "${_T}/glslang" "${_T}" "${_T}/spirv-headers/include/spirv/unified1")
_mod_def(glslang "ENABLE_OPT=0")
_mod_inc(raycast "${_T}/embree" "${_T}/embree/include")
_mod_def(raycast EMBREE_TARGET_SSE2 EMBREE_LOWEST_ISA TASKING_INTERNAL NDEBUG)
_mod_inc(csg "${_T}/manifold/include")
_mod_def(csg "MANIFOLD_PAR=-1")
_mod_inc(fbx "${_T}/ufbx")
_mod_inc(navigation_2d "${_T}/rvo2/rvo2_2d")
_mod_inc(navigation_3d "${_T}/recastnavigation/Recast/Include" "${_T}/rvo2/rvo2_2d" "${_T}/rvo2/rvo2_3d")
_mod_inc(jolt_physics "${_T}/jolt_physics")
_mod_inc(meshoptimizer "${_T}/meshoptimizer")
_mod_inc(noise "${_T}/noise")
_mod_inc(vhacd "${_T}/vhacd/inc")
_mod_inc(xatlas_unwrap "${_T}/xatlas")

# ---- XR ----------------------------------------------------------------------------------
_mod_inc(openxr "${_T}/openxr/include" "${_T}/openxr/src" "${_T}/openxr/src/common")
_mod_def(openxr XR_OS_WINDOWS NOMINMAX XR_USE_PLATFORM_WIN32 "JSON_USE_EXCEPTION=0")

# ---- Bare-basename generated includes (module shaders + gdscript templates) -------------
_mod_inc(betsy "${GODOT_GEN_DIR}/modules/betsy")
_mod_inc(lightmapper_rd "${GODOT_GEN_DIR}/modules/lightmapper_rd")
# gdscript editor includes "editor/script_templates/templates.gen.h" relative to the module root.
_mod_inc(gdscript "${GODOT_GEN_DIR}/modules/gdscript")

# gdscript script templates header (modules/gdscript/editor/script_templates/SCsub).
file(GLOB _gd_templates RELATIVE "${CMAKE_SOURCE_DIR}"
  "${CMAKE_SOURCE_DIR}/modules/gdscript/editor/script_templates/*/*.gd")
set(_gd_tmpl_specs "")
foreach(_gd IN LISTS _gd_templates)
  list(APPEND _gd_tmpl_specs "file:${_gd}")
endforeach()
godot_add_generated(OUTPUT modules/gdscript/editor/script_templates/templates.gen.h
  MODULE_PATH editor/template_builders.py FUNC make_templates
  SOURCES ${_gd_tmpl_specs})
if(TARGET module_gdscript)
  add_dependencies(module_gdscript godot_generated)
endif()

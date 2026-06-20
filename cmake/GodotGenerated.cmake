# GodotGenerated.cmake
#
# Wires every non-shader generated source/header to its Godot Python builder via
# godot_add_generated() (see GodotPython.cmake). Output paths mirror the source tree under
# ${GODOT_GEN_DIR}; the `gen` include root (godot_defines) makes the full-path #includes resolve.
#
# Module-dependent generated files (modules_enabled.gen.h, register_module_types.gen.cpp,
# editor doc/icons/translations) are wired in GodotModules.cmake once the module manifest exists.
# Texture/font/icon "asset" headers and shaders are wired in GodotShaders.cmake (Stage 4).

set(_CB "core/core_builders.py")

# ---- core/SCsub ---------------------------------------------------------------------------
godot_add_generated(OUTPUT core/version_generated.gen.h MODULE_PATH ${_CB}
  FUNC version_info_builder SOURCES "versioninfo:")
godot_add_generated(OUTPUT core/version_hash.gen.cpp MODULE_PATH ${_CB}
  FUNC version_hash_builder SOURCES "gitinfo:")
godot_add_generated(OUTPUT core/disabled_classes.gen.h MODULE_PATH ${_CB}
  FUNC disabled_class_builder SOURCES "jsonlit:[]")
godot_add_generated(OUTPUT core/script_encryption_key.gen.cpp MODULE_PATH ${_CB}
  FUNC encryption_key_builder SOURCES "jsonlit:null")
godot_add_generated(OUTPUT core/io/certs_compressed.gen.h MODULE_PATH ${_CB}
  FUNC make_certs_header SOURCES "file:thirdparty/certs/ca-bundle.crt" "jsonlit:true" "str:")
godot_add_generated(OUTPUT core/authors.gen.h MODULE_PATH ${_CB}
  FUNC make_authors_header SOURCES "file:AUTHORS.md")
godot_add_generated(OUTPUT core/donors.gen.h MODULE_PATH ${_CB}
  FUNC make_donors_header SOURCES "file:DONORS.md")
godot_add_generated(OUTPUT core/license.gen.h MODULE_PATH ${_CB}
  FUNC make_license_header SOURCES "file:COPYRIGHT.txt" "file:LICENSE.txt")

# ---- core/object/SCsub --------------------------------------------------------------------
godot_add_generated(OUTPUT core/object/gdvirtual.gen.h
  MODULE_PATH core/object/make_virtuals.py FUNC run)

# ---- core/extension/SCsub -----------------------------------------------------------------
godot_add_generated(OUTPUT core/extension/ext_wrappers.gen.h
  MODULE_PATH core/extension/make_wrappers.py FUNC run)
godot_add_generated(OUTPUT core/extension/gdextension_interface.gen.h
  MODULE_PATH core/extension/make_interface_header.py FUNC run
  SOURCES "file:core/extension/gdextension_interface.json")
godot_add_generated(OUTPUT core/extension/gdextension_interface_dump.gen.h
  MODULE_PATH core/extension/make_interface_dumper.py FUNC run
  SOURCES "file:core/extension/gdextension_interface.json")

# ---- core/profiling/SCsub (profiler=none -> empty header; builder reads env, not sources) --
godot_add_generated(OUTPUT core/profiling/profiling.gen.h
  MODULE_PATH core/profiling/profiling_builders.py FUNC profiler_gen_builder
  ENV "profiler=str:none" "profiler_sample_callstack=jsonlit:false"
      "profiler_track_memory=jsonlit:false" "profiler_record_on_demand=jsonlit:true")

# ---- core/input/SCsub ---------------------------------------------------------------------
godot_add_generated(OUTPUT core/input/default_controller_mappings.gen.cpp
  MODULE_PATH core/input/input_builders.py FUNC make_default_controller_mappings
  SOURCES "file:core/input/gamecontrollerdb.txt" "file:core/input/godotcontrollerdb.txt")

# ---- platform/SCsub (no platform/windows/api/api.cpp -> empty apis list) -------------------
godot_add_generated(OUTPUT platform/register_platform_apis.gen.cpp
  MODULE_PATH platform/platform_builders.py FUNC register_platform_apis_builder
  SOURCES "jsonlit:[]")

# Export icons for the current platform (platform/SCsub: <platform>/export/*.svg -> *_svg.gen.h).
file(GLOB _plat_export_svgs RELATIVE "${CMAKE_SOURCE_DIR}"
  "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/export/*.svg")
foreach(_svg IN LISTS _plat_export_svgs)
  string(REGEX REPLACE "\\.svg$" "_svg.gen.h" _icon_out "${_svg}")
  godot_add_generated(OUTPUT "${_icon_out}"
    MODULE_PATH platform/platform_builders.py FUNC export_icon_builder
    SOURCES "file:${_svg}")
endforeach()

# ---- Generated assets (fonts/icons/textures/splash) ---------------------------------------
# main/SCsub: splash + app icon (from PNGs).
godot_add_generated(OUTPUT main/splash.gen.h MODULE_PATH main/main_builders.py
  FUNC make_splash SOURCES "file:main/splash.png")
godot_add_generated(OUTPUT main/app_icon.gen.h MODULE_PATH main/main_builders.py
  FUNC make_app_icon SOURCES "file:main/app_icon.png")
# Editor splash only if the source image is present (else NO_EDITOR_SPLASH guards the include).
if(GODOT_EDITOR_BUILD AND EXISTS "${CMAKE_SOURCE_DIR}/main/splash_editor.png")
  godot_add_generated(OUTPUT main/splash_editor.gen.h MODULE_PATH main/main_builders.py
    FUNC make_splash_editor SOURCES "file:main/splash_editor.png")
endif()

# scene/theme: default font + default theme icons (all scene/theme/icons/*.svg).
godot_add_generated(OUTPUT scene/theme/default_font.gen.h
  MODULE_PATH scene/theme/default_theme_builders.py FUNC make_fonts_header
  SOURCES "file:thirdparty/fonts/OpenSans_SemiBold.woff2")

file(GLOB _scene_icons RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/scene/theme/icons/*.svg")
set(_scene_icon_specs "")
foreach(_svg IN LISTS _scene_icons)
  list(APPEND _scene_icon_specs "file:${_svg}")
endforeach()
godot_add_generated(OUTPUT scene/theme/default_theme_icons.gen.h
  MODULE_PATH scene/theme/icons/default_theme_icons_builders.py FUNC make_default_theme_icons_action
  SOURCES ${_scene_icon_specs})

# servers/rendering: LTC LUT + SMAA textures.
godot_add_generated(OUTPUT servers/rendering/storage/ltc_lut.gen.h
  MODULE_PATH servers/rendering/storage/make_ltc_lut.py FUNC run
  SOURCES "file:servers/rendering/storage/make_ltc_lut.py"
          "file:servers/rendering/storage/ltc/ltc_lut1.dds"
          "file:servers/rendering/storage/ltc/ltc_lut2.dds")
godot_add_generated(OUTPUT servers/rendering/renderer_rd/effects/smaa_area_tex.gen.h
  MODULE_PATH misc/cmake/effects_tex_builders.py FUNC areatex_builder
  SOURCES "file:thirdparty/smaa/AreaTex.png")
godot_add_generated(OUTPUT servers/rendering/renderer_rd/effects/smaa_search_tex.gen.h
  MODULE_PATH misc/cmake/effects_tex_builders.py FUNC searchtex_builder
  SOURCES "file:thirdparty/smaa/SearchTex.png")

# NOTE: the `godot_generated` aggregate target is created in the root CMakeLists after ALL
# generated wiring (incl. GodotModules) so its DEPENDS covers every output.

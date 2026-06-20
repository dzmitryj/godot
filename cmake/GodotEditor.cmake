# GodotEditor.cmake
#
# Editor codegen (editor/SCsub) + the godot_editor component library. Editor-build only.
# Several generators read large file sets (doc XML, icons, translations); those are passed via
# a --source-list file to avoid command-line length limits.

if(NOT GODOT_EDITOR_BUILD)
  return()
endif()

set(GODOT_EDITOR_GEN_CPP "" CACHE INTERNAL "")  # generated .cpp compiled into the editor lib

# godot_gen_globbed(OUTPUT <rel> [OUTPUT2 <rel>] MODULE_PATH <py> FUNC <fn> GLOBS <pattern>...)
# Globs the patterns, writes "file:<abs>" specs to a list file, and drives the builder.
function(godot_gen_globbed)
  cmake_parse_arguments(G "" "OUTPUT;OUTPUT2;MODULE_PATH;FUNC" "GLOBS" ${ARGN})
  set(_files "")
  foreach(_p IN LISTS G_GLOBS)
    file(GLOB _g CONFIGURE_DEPENDS "${_p}")
    list(APPEND _files ${_g})
  endforeach()
  list(SORT _files)
  string(MAKE_C_IDENTIFIER "${G_OUTPUT}" _id)
  set(_listfile "${CMAKE_BINARY_DIR}/srclists/${_id}.txt")
  set(_content "")
  foreach(_f IN LISTS _files)
    string(APPEND _content "file:${_f}\n")
  endforeach()
  file(WRITE "${_listfile}" "${_content}")

  set(_out "${GODOT_GEN_DIR}/${G_OUTPUT}")
  set(_targets --target "${_out}")
  set(_outputs "${_out}")
  if(G_OUTPUT2)
    list(APPEND _targets --target "${GODOT_GEN_DIR}/${G_OUTPUT2}")
    list(APPEND _outputs "${GODOT_GEN_DIR}/${G_OUTPUT2}")
  endif()
  add_custom_command(
    OUTPUT ${_outputs}
    COMMAND "${GODOT_PYTHON}" "${GODOT_RUN_BUILDER}" --repo-root "${CMAKE_SOURCE_DIR}"
            --module-path "${G_MODULE_PATH}" --func "${G_FUNC}" ${_targets} --source-list "${_listfile}"
    DEPENDS ${_files} "${GODOT_RUN_BUILDER}" "${CMAKE_SOURCE_DIR}/${G_MODULE_PATH}" "${_listfile}"
    COMMENT "gen ${G_OUTPUT}"
    VERBATIM
  )
  # Track compiled .gen.cpp outputs for the editor lib.
  foreach(_o IN LISTS _outputs)
    if(_o MATCHES "\\.cpp$")
      set(GODOT_EDITOR_GEN_CPP "${GODOT_EDITOR_GEN_CPP};${_o}" CACHE INTERNAL "")
      set_source_files_properties("${_o}" PROPERTIES GENERATED TRUE)
    endif()
  endforeach()
endfunction()

set(_EB "editor/editor_builders.py")

# Doc class paths (Value -> from manifest doc_class_path.json).
godot_add_generated(OUTPUT editor/doc/doc_data_class_path.gen.h MODULE_PATH ${_EB}
  FUNC doc_data_class_path_builder SOURCES "jsonfile:${GODOT_MODULES_DIR}/doc_class_path.json")

# Exporters registration (platform_exporters = windows has export/export.cpp).
godot_add_generated(OUTPUT editor/export/register_exporters.gen.cpp MODULE_PATH ${_EB}
  FUNC register_exporters_builder SOURCES "jsonlit:[\"${GODOT_PLATFORM}\"]")
set(GODOT_EDITOR_GEN_CPP "${GODOT_EDITOR_GEN_CPP};${GODOT_GEN_DIR}/editor/export/register_exporters.gen.cpp" CACHE INTERNAL "")
set_source_files_properties("${GODOT_GEN_DIR}/editor/export/register_exporters.gen.cpp" PROPERTIES GENERATED TRUE)

# Compressed class reference docs (core + every module's doc_classes).
godot_gen_globbed(OUTPUT editor/doc/doc_data_compressed.gen.h MODULE_PATH ${_EB} FUNC make_doc_header
  GLOBS "${CMAKE_SOURCE_DIR}/doc/classes/*.xml"
        "${CMAKE_SOURCE_DIR}/modules/*/doc_classes/*.xml"
        "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/doc_classes/*.xml")

# Editor icons (editor's own + each module's icons/).
godot_gen_globbed(OUTPUT editor/themes/editor_icons.gen.h
  MODULE_PATH editor/icons/editor_icons_builders.py FUNC make_editor_icons_action
  GLOBS "${CMAKE_SOURCE_DIR}/editor/icons/*.svg" "${CMAKE_SOURCE_DIR}/modules/*/icons/*.svg")

# Editor builtin fonts.
godot_gen_globbed(OUTPUT editor/themes/builtin_fonts.gen.h
  MODULE_PATH editor/themes/editor_theme_builders.py FUNC make_fonts_header
  GLOBS "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.ttf" "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.otf"
        "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.woff" "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.woff2")

# Translations (4 sets; each builder writes a .h + .cpp pair).
godot_gen_globbed(OUTPUT editor/translations/editor_translations.gen.h
  OUTPUT2 editor/translations/editor_translations.gen.cpp
  MODULE_PATH ${_EB} FUNC make_translations GLOBS "${CMAKE_SOURCE_DIR}/editor/translations/editor/*")
godot_gen_globbed(OUTPUT editor/translations/property_translations.gen.h
  OUTPUT2 editor/translations/property_translations.gen.cpp
  MODULE_PATH ${_EB} FUNC make_translations GLOBS "${CMAKE_SOURCE_DIR}/editor/translations/properties/*")
godot_gen_globbed(OUTPUT editor/translations/doc_translations.gen.h
  OUTPUT2 editor/translations/doc_translations.gen.cpp
  MODULE_PATH ${_EB} FUNC make_translations GLOBS "${CMAKE_SOURCE_DIR}/doc/translations/*")
godot_gen_globbed(OUTPUT editor/translations/extractable_translations.gen.h
  OUTPUT2 editor/translations/extractable_translations.gen.cpp
  MODULE_PATH ${_EB} FUNC make_translations GLOBS "${CMAKE_SOURCE_DIR}/editor/translations/extractable/*")

add_custom_target(godot_editor_gen DEPENDS
  "${GODOT_GEN_DIR}/editor/doc/doc_data_class_path.gen.h"
  "${GODOT_GEN_DIR}/editor/doc/doc_data_compressed.gen.h"
  "${GODOT_GEN_DIR}/editor/themes/editor_icons.gen.h"
  "${GODOT_GEN_DIR}/editor/themes/builtin_fonts.gen.h"
  ${GODOT_EDITOR_GEN_CPP})

# ---- Editor component library -------------------------------------------------------------
# shader_baker has per-renderer export plugins (editor/shader/shader_baker/SCsub); drop the
# disabled renderers' files (metal always off here; d3d12 unless enabled).
set(_editor_exclude "shader_baker_export_plugin_platform_metal")
if(NOT GODOT_D3D12)
  set(_editor_exclude "${_editor_exclude}|shader_baker_export_plugin_platform_d3d12")
endif()
godot_glob_sources(_editor_srcs ROOTS editor EXCLUDE_REGEX "${_editor_exclude}")
# Platform export plugin sources are compiled into the editor (editor/SCsub adds them).
file(GLOB_RECURSE _export_srcs CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/platform/${GODOT_PLATFORM}/export/*.cpp")
list(APPEND _editor_srcs ${_export_srcs} ${GODOT_EDITOR_GEN_CPP})

add_library(godot_editor STATIC ${_editor_srcs})
target_link_libraries(godot_editor PUBLIC godot_defines godot_platform_windows)
# register_exporters.gen.cpp does a bare #include "register_exporters.h" (sibling in editor/export).
target_include_directories(godot_editor PRIVATE
  "${GODOT_GEN_DIR}/platform/${GODOT_PLATFORM}/export" "${CMAKE_SOURCE_DIR}/editor/export")
add_dependencies(godot_editor godot_generated godot_shaders godot_editor_gen)
list(LENGTH _editor_srcs _n_editor)
message(STATUS "component godot_editor: ${_n_editor} sources")

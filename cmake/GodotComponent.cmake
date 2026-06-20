# GodotComponent.cmake
#
# Helpers to build the engine's component static libraries by globbing the source tree
# (the chosen "glob mirror" strategy). Globs are recursive over the listed root dirs and
# always exclude *.gen.cpp (those are added explicitly from the generated layer).
#
# Re-run CMake after adding/removing source files (CONFIGURE_DEPENDS keeps globs fresh at the
# cost of a stat each build).

# godot_glob_sources(<out_var> ROOTS <dir> ... [EXCLUDE_REGEX <regex>])
function(godot_glob_sources out_var)
  cmake_parse_arguments(P "" "EXCLUDE_REGEX" "ROOTS" ${ARGN})
  set(_patterns "")
  foreach(_root IN LISTS P_ROOTS)
    list(APPEND _patterns "${CMAKE_SOURCE_DIR}/${_root}/*.cpp")
  endforeach()
  file(GLOB_RECURSE _srcs CONFIGURE_DEPENDS ${_patterns})
  # Drop generated .cpp (added explicitly) and any caller-excluded paths.
  list(FILTER _srcs EXCLUDE REGEX "\\.gen\\.cpp$")
  if(P_EXCLUDE_REGEX)
    list(FILTER _srcs EXCLUDE REGEX "${P_EXCLUDE_REGEX}")
  endif()
  set(${out_var} "${_srcs}" PARENT_SCOPE)
endfunction()

# godot_add_component(<name>
#   ROOTS <dir> ...                 # source roots globbed recursively
#   [EXCLUDE_REGEX <regex>]         # paths to drop (conditional subdirs)
#   [GEN_SOURCES <abs .gen.cpp> ...]# generated .cpp to compile into this lib
#   [EXTRA_SOURCES <files> ...]     # explicit extra sources
# )
# Produces a STATIC library `<name>` linking godot_defines (+ platform interface), depending
# on the generated/shader layers so headers exist before compilation.
function(godot_add_component name)
  cmake_parse_arguments(C "" "EXCLUDE_REGEX" "ROOTS;GEN_SOURCES;EXTRA_SOURCES" ${ARGN})

  godot_glob_sources(_srcs ROOTS ${C_ROOTS} EXCLUDE_REGEX "${C_EXCLUDE_REGEX}")
  list(APPEND _srcs ${C_GEN_SOURCES} ${C_EXTRA_SOURCES})

  add_library(${name} STATIC ${_srcs})
  target_link_libraries(${name} PUBLIC godot_defines)
  if(TARGET godot_platform_windows)
    target_link_libraries(${name} PUBLIC godot_platform_windows)
  endif()
  # Generated headers + shader headers must exist before this lib compiles.
  add_dependencies(${name} godot_generated godot_shaders)
  # Mark generated .cpp as GENERATED (they live in the binary dir).
  if(C_GEN_SOURCES)
    set_source_files_properties(${C_GEN_SOURCES} PROPERTIES GENERATED TRUE)
  endif()

  list(LENGTH _srcs _n)
  message(STATUS "component ${name}: ${_n} sources")
endfunction()

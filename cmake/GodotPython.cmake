# GodotPython.cmake
#
# Locates the Python interpreter and provides godot_add_generated(), the wrapper around
# run_builder.py used to drive Godot's own codegen from add_custom_command. Every generated
# file lands under ${GODOT_GEN_DIR}/<OUTPUT> (binary dir, mirroring source layout).

find_package(Python3 COMPONENTS Interpreter REQUIRED)

set(GODOT_PYTHON "${Python3_EXECUTABLE}" CACHE FILEPATH "Python interpreter for build codegen")
set(GODOT_RUN_BUILDER "${CMAKE_SOURCE_DIR}/misc/cmake/run_builder.py")
set(GODOT_FAKE_ENV    "${CMAKE_SOURCE_DIR}/misc/cmake/fake_env.py")

# Accumulators (parent scope). GODOT_GENERATED_OUTPUTS = every generated file;
# GODOT_GENERATED_CPP = the compiled .gen.cpp subset (added explicitly to component libs).
set(GODOT_GENERATED_OUTPUTS "" CACHE INTERNAL "")
set(GODOT_GENERATED_CPP "" CACHE INTERNAL "")

# godot_add_generated(
#   OUTPUT <relative path under gen/, e.g. core/version_generated.gen.h>
#   FUNC <builder function name>
#   (MODULE_PATH <py file rel to source> | MODULE <dotted module>)
#   [SOURCES <spec> ...]   # file:/jsonfile:/jsonlit:/str:/versioninfo:/gitinfo:
#   [ENV <KEY=spec> ...]   # seed FakeEnv for builders that read env[...] instead of source
#   [DEPENDS <extra files> ...]
# )
function(godot_add_generated)
  cmake_parse_arguments(G "" "OUTPUT;FUNC;MODULE;MODULE_PATH" "SOURCES;ENV;DEPENDS" ${ARGN})

  set(_out "${GODOT_GEN_DIR}/${G_OUTPUT}")
  set(_cmd "${GODOT_PYTHON}" "${GODOT_RUN_BUILDER}"
           --repo-root "${CMAKE_SOURCE_DIR}" --func "${G_FUNC}" --target "${_out}")
  set(_deps "${GODOT_RUN_BUILDER}" "${GODOT_FAKE_ENV}")

  if(G_MODULE_PATH)
    list(APPEND _cmd --module-path "${G_MODULE_PATH}")
    list(APPEND _deps "${CMAKE_SOURCE_DIR}/${G_MODULE_PATH}")
  elseif(G_MODULE)
    list(APPEND _cmd --module "${G_MODULE}")
  else()
    message(FATAL_ERROR "godot_add_generated(${G_OUTPUT}): MODULE or MODULE_PATH required")
  endif()

  foreach(_s IN LISTS G_SOURCES)
    list(APPEND _cmd --source "${_s}")
    # Track file:/jsonfile: inputs as dependencies so edits trigger regeneration.
    if(_s MATCHES "^(file|jsonfile):(.+)$")
      set(_p "${CMAKE_MATCH_2}")
      if(NOT IS_ABSOLUTE "${_p}")
        set(_p "${CMAKE_SOURCE_DIR}/${_p}")
      endif()
      list(APPEND _deps "${_p}")
    endif()
  endforeach()
  foreach(_e IN LISTS G_ENV)
    list(APPEND _cmd --env "${_e}")
  endforeach()
  list(APPEND _deps ${G_DEPENDS})

  add_custom_command(
    OUTPUT "${_out}"
    COMMAND ${_cmd}
    DEPENDS ${_deps}
    COMMENT "gen ${G_OUTPUT}"
    VERBATIM
  )

  set(GODOT_GENERATED_OUTPUTS "${GODOT_GENERATED_OUTPUTS};${_out}" CACHE INTERNAL "")
  if(_out MATCHES "\\.(cpp|c|cc|cxx)$")
    set(GODOT_GENERATED_CPP "${GODOT_GENERATED_CPP};${_out}" CACHE INTERNAL "")
  endif()
endfunction()

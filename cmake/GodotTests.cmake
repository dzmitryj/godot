# GodotTests.cmake
#
# Unit-test suite (GODOT_TESTS, run with `godot --test`). Mirrors tests/SCsub + modules/SCsub:
#  - force_link.gen.h  : references each test TU's force_link_<name>() so the linker keeps them.
#  - modules_tests.gen.h : includes each enabled module's tests/*.h.
#  - a godot_tests static lib from tests/**/*.cpp, linked into the exe; TESTS_ENABLED is global.

if(NOT GODOT_TESTS)
  set(GODOT_TESTS_LIB "" CACHE INTERNAL "")
  return()
endif()

# TESTS_ENABLED is global: main.cpp gates the --test path on it and engine code adds test hooks.
target_compile_definitions(godot_defines INTERFACE TESTS_ENABLED)

# tests/*.cpp (top level) + tests/<subdir>/**/*.cpp (the force-link sources).
file(GLOB_RECURSE _tests_all RELATIVE "${CMAKE_SOURCE_DIR}" CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/tests/*.cpp")
list(FILTER _tests_all EXCLUDE REGEX "\\.gen\\.cpp$")
set(_tests_sub "")
foreach(_f IN LISTS _tests_all)
  if(NOT _f MATCHES "^tests/[^/]+\\.cpp$")
    list(APPEND _tests_sub "${_f}")
  endif()
endforeach()

# force_link.gen.h: feed the subdir cpp list (builder derives force_link_<stem>() from each path).
set(_fl_quoted "")
foreach(_f IN LISTS _tests_sub)
  list(APPEND _fl_quoted "\"${_f}\"")
endforeach()
string(JOIN "," _fl_body ${_fl_quoted})
file(WRITE "${CMAKE_BINARY_DIR}/tests_force_link.json" "[${_fl_body}]")
godot_add_generated(OUTPUT tests/force_link.gen.h MODULE_PATH tests/test_builders.py
  FUNC force_link_builder SOURCES "jsonfile:${CMAKE_BINARY_DIR}/tests_force_link.json")

# modules_tests.gen.h: each enabled module's tests/*.h.
set(_mtest_specs "")
foreach(_mod IN LISTS GODOT_ENABLED_MODULES)
  set(_mp "${GODOT_MODULE_PATH_${_mod}}")
  if(NOT IS_ABSOLUTE "${_mp}")
    set(_mp "${CMAKE_SOURCE_DIR}/${_mp}")
  endif()
  file(GLOB _mh "${_mp}/tests/*.h")
  foreach(_h IN LISTS _mh)
    list(APPEND _mtest_specs "file:${_h}")
  endforeach()
endforeach()
godot_add_generated(OUTPUT modules/modules_tests.gen.h MODULE_PATH modules/modules_builders.py
  FUNC modules_tests_builder SOURCES ${_mtest_specs})

# The tests library: all tests/**/*.cpp.
set(_tests_abs "")
foreach(_f IN LISTS _tests_all)
  list(APPEND _tests_abs "${CMAKE_SOURCE_DIR}/${_f}")
endforeach()
add_custom_target(godot_tests_gen DEPENDS
  "${GODOT_GEN_DIR}/tests/force_link.gen.h" "${GODOT_GEN_DIR}/modules/modules_tests.gen.h")
add_library(godot_tests STATIC ${_tests_abs})
target_link_libraries(godot_tests PUBLIC godot_defines godot_platform_windows)
add_dependencies(godot_tests godot_generated godot_shaders godot_tests_gen)
set(GODOT_TESTS_LIB godot_tests CACHE INTERNAL "")
message(STATUS "GodotTests: enabled (run the binary with --test)")

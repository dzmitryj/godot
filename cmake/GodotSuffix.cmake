# GodotSuffix.cmake
#
# Reproduces the SCons binary-suffix construction (SConstruct ~1034-1051):
#   .<platform>.<target>[.dev][.double].<arch>[.nothreads]<extra_suffix>
# e.g. godot.windows.editor.x86_64(.exe)
#
# Windows has no detect.get_program_suffix(), so the leading component is the platform name.

function(godot_compute_suffix out_var)
  set(_suffix ".${GODOT_PLATFORM}.${GODOT_TARGET}")
  if(GODOT_DEV_BUILD)
    string(APPEND _suffix ".dev")
  endif()
  if(GODOT_PRECISION STREQUAL "double")
    string(APPEND _suffix ".double")
  endif()
  string(APPEND _suffix ".${GODOT_ARCH}")
  if(NOT GODOT_THREADS)
    string(APPEND _suffix ".nothreads")
  endif()
  set(${out_var} "${_suffix}" PARENT_SCOPE)
endfunction()

# Apply the computed name/suffix and output directory to an executable target.
# Produces bin/godot<suffix>.exe (matching SCons #bin output).
function(godot_set_output target)
  godot_compute_suffix(_suffix)
  set_target_properties(${target} PROPERTIES
    OUTPUT_NAME "godot${_suffix}"
    SUFFIX ".exe"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
  )
  message(STATUS "${target} -> bin/godot${_suffix}.exe")
endfunction()

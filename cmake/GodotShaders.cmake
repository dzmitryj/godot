# GodotShaders.cmake
#
# Generates the ~110 *.glsl.gen.h shader headers via run_shader.py into ${GODOT_GEN_DIR},
# mirroring the source layout (RD/gles3 headers are #included by full source-relative path).
#
#  - RenderingDevice (RD) shaders: every dir under servers/rendering/renderer_rd/shaders.
#    *_inc.glsl -> raw header; other *.glsl -> RD header. (All subdir SCsubs share this pattern;
#    fsr2 only adds thirdparty include deps.)
#  - GLES3 shaders: an explicit top-level list (not all are converted) + globbed effects/.
#  - Module shaders (betsy, lightmapper_rd) are handled per-module in Stage 6.

set(GODOT_SHADER_OUTPUTS "" CACHE INTERNAL "")
set(GODOT_RUN_SHADER "${CMAKE_SOURCE_DIR}/misc/cmake/run_shader.py")
set(_glsl_builders "${CMAKE_SOURCE_DIR}/glsl_builders.py")
set(_gles3_builders "${CMAKE_SOURCE_DIR}/gles3_builders.py")

# godot_add_shader(KIND <rd|raw|gles3> SRC <repo-rel .glsl> DEPENDS <files...>)
function(godot_add_shader)
  cmake_parse_arguments(S "" "KIND;SRC" "DEPENDS" ${ARGN})
  set(_out "${GODOT_GEN_DIR}/${S_SRC}.gen.h")
  add_custom_command(
    OUTPUT "${_out}"
    COMMAND "${GODOT_PYTHON}" "${GODOT_RUN_SHADER}"
            --repo-root "${CMAKE_SOURCE_DIR}" --kind "${S_KIND}"
            --src "${S_SRC}" --out "${_out}"
    DEPENDS "${CMAKE_SOURCE_DIR}/${S_SRC}" "${GODOT_RUN_SHADER}" ${S_DEPENDS}
    COMMENT "shader ${S_SRC}"
    VERBATIM
  )
  set(GODOT_SHADER_OUTPUTS "${GODOT_SHADER_OUTPUTS};${_out}" CACHE INTERNAL "")
endfunction()

# ---- RenderingDevice shaders (Vulkan / RD) ------------------------------------------------
if(GODOT_VULKAN OR GODOT_D3D12)
  set(_rd_root "servers/rendering/renderer_rd/shaders")
  file(GLOB_RECURSE _rd_glsl RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/${_rd_root}/*.glsl")

  # Dependency set shared by all RD shaders: every include + fsr2 thirdparty + the builder.
  set(_rd_deps "${_glsl_builders}")
  foreach(_g IN LISTS _rd_glsl)
    if(_g MATCHES "_inc\\.glsl$")
      list(APPEND _rd_deps "${CMAKE_SOURCE_DIR}/${_g}")
    endif()
  endforeach()
  file(GLOB _fsr2_deps
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/shaders/*.h"
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/shaders/*.glsl")
  list(APPEND _rd_deps ${_fsr2_deps})

  foreach(_g IN LISTS _rd_glsl)
    if(_g MATCHES "_inc\\.glsl$")
      godot_add_shader(KIND raw SRC "${_g}" DEPENDS ${_rd_deps})
    else()
      godot_add_shader(KIND rd SRC "${_g}" DEPENDS ${_rd_deps})
    endif()
  endforeach()
endif()

# ---- GLES3 / OpenGL shaders ---------------------------------------------------------------
if(GODOT_OPENGL3)
  set(_gl_root "drivers/gles3/shaders")
  # Explicit top-level list (drivers/gles3/shaders/SCsub) -- not all files are converted.
  set(_gles3_top
    canvas.glsl feed.glsl scene.glsl sky.glsl canvas_occlusion.glsl canvas_sdf.glsl
    particles.glsl particles_copy.glsl skeleton.glsl tex_blit.glsl)
  # effects/ is fully converted -> glob it.
  file(GLOB _gles3_effects RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/${_gl_root}/effects/*.glsl")

  set(_gl_deps "${_gles3_builders}")
  file(GLOB_RECURSE _gl_incs RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/${_gl_root}/*_inc.glsl")
  foreach(_g IN LISTS _gl_incs)
    list(APPEND _gl_deps "${CMAKE_SOURCE_DIR}/${_g}")
  endforeach()

  foreach(_f IN LISTS _gles3_top)
    godot_add_shader(KIND gles3 SRC "${_gl_root}/${_f}" DEPENDS ${_gl_deps})
  endforeach()
  foreach(_g IN LISTS _gles3_effects)
    if(NOT _g MATCHES "_inc\\.glsl$")
      godot_add_shader(KIND gles3 SRC "${_g}" DEPENDS ${_gl_deps})
    endif()
  endforeach()
endif()

# ---- Module shaders (betsy, lightmapper_rd) — both use raw GLSL_HEADER ---------------------
# betsy: bc6h/bc1/bc4/alpha_stitch/rgb_to_rgba.glsl -> raw headers (bare-basename includes).
foreach(_b bc6h bc1 bc4 alpha_stitch rgb_to_rgba)
  godot_add_shader(KIND raw SRC "modules/betsy/${_b}.glsl")
endforeach()
# lightmapper_rd: lm_raster/lm_compute/lm_blendseams.glsl -> raw headers (+ lm_common_inc.glsl dep).
foreach(_l lm_raster lm_compute lm_blendseams)
  godot_add_shader(KIND raw SRC "modules/lightmapper_rd/${_l}.glsl"
    DEPENDS "${CMAKE_SOURCE_DIR}/modules/lightmapper_rd/lm_common_inc.glsl")
endforeach()

list(LENGTH GODOT_SHADER_OUTPUTS _n_shaders)
message(STATUS "GodotShaders: ${_n_shaders} shader headers wired")

add_custom_target(godot_shaders DEPENDS ${GODOT_SHADER_OUTPUTS})

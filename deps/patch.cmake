# Patches carried for a dependency live in patches/<name>/*.patch and are applied in name order, with
# patch -p1, to the freshly extracted source. CMake's FindPatch finds patch on PATH, or on Windows the
# copy Git for Windows ships.
include_guard(GLOBAL)

# gr_deps_patch_command(<name> <out var>)
#
# Sets <out var> to the PATCH_COMMAND, keyword included, that applies patches/<name>, for
# ExternalProject_Add.
function(gr_deps_patch_command name out_var)
  find_package(Patch REQUIRED)
  file(GLOB patches CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/patches/${name}/*.patch")
  if(NOT patches)
    message(FATAL_ERROR "No patches found under patches/${name}")
  endif()
  set(command "")
  foreach(patch IN LISTS patches)
    list(APPEND command COMMAND "${Patch_EXECUTABLE}" -p1 -i "${patch}")
  endforeach()
  list(POP_FRONT command)
  set_property(GLOBAL PROPERTY _GR_DEPS_${name}_PATCHES ${patches})
  set(${out_var}
      PATCH_COMMAND ${command}
      PARENT_SCOPE)
endfunction()

# gr_deps_patch_dependencies(<name>)
#
# Called after ExternalProject_Add: a changed or added patch re-extracts the source rather than
# patching an already patched tree.
function(gr_deps_patch_dependencies name)
  get_property(patches GLOBAL PROPERTY _GR_DEPS_${name}_PATCHES)
  ExternalProject_Add_StepDependencies(${name} download ${patches})
endfunction()

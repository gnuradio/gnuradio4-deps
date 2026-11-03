# vir-simd: header-only SIMD wrapper, pinned by gr-core's FetchContent_Declare.
# Installs its own CMake package (vir-simd-config), so a consumer finds it with find_package(vir-simd).
#
# 0.4.4 gates constexpr_wrapper.h and simd_concepts.h to GCC and Clang, so under MSVC vir::simdize,
# vir::simd_permute and the constexpr_wrapper GR uses do not exist. patches/vir-simd lifts the gates
# and works around what MSVC then trips over; they are the MSVC series proposed upstream, backported
# to 0.4.4, plus upstream's own <bit> include fix. Each is a no-op for GCC and Clang. Drop them once a
# vir-simd release carries them.
if(ENABLE_VIR_SIMD)
  include(patch)
  gr_deps_patch_command(vir-simd gr_deps_vir_simd_patch)

  ExternalProject_Add(
    vir-simd
    URL https://github.com/mattkretz/vir-simd/archive/refs/tags/v0.4.4.tar.gz
    URL_HASH SHA256=0d2953e1219798967b156aa392de6430099d85887770e5c81aefe8fb63e9464c
    ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
    ${gr_deps_vir_simd_patch}
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS} ${GR_DEPS_MSVC_RUNTIME_ARGS}
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
  gr_deps_patch_dependencies(vir-simd)
endif()

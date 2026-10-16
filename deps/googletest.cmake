# GoogleTest: gr-control-plane's tests reach it through find_package(GTest CONFIG) and link
# GTest::gtest_main.
#
# Built static, the upstream default. A static GoogleTest on MSVC rewrites the compiler flags for
# the static CRT unless gtest_force_shared_crt is on, so that option is matched to
# GR_DEPS_MSVC_RUNTIME_STATIC rather than left to disagree with CMAKE_MSVC_RUNTIME_LIBRARY.
if(ENABLE_GTEST)
  if(GR_DEPS_MSVC_RUNTIME_STATIC)
    set(gr_deps_gtest_shared_crt OFF)
  else()
    set(gr_deps_gtest_shared_crt ON)
  endif()

  ExternalProject_Add(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.18.0
    GIT_SHALLOW TRUE
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS} ${GR_DEPS_MSVC_RUNTIME_ARGS}
               -DINSTALL_GTEST=ON
               -Dgtest_force_shared_crt=${gr_deps_gtest_shared_crt}
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
endif()

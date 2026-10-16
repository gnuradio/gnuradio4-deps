# zlib: gr-control-plane links ZLIB::ZLIB through find_package(ZLIB), which is CMake's FindZLIB
# module rather than zlib's own package config.
#
# Only the shared library is built, so FindZLIB finds the one library named z instead of choosing
# between it and the static one (zs on Windows).
if(ENABLE_ZLIB)
  ExternalProject_Add(
    zlib
    GIT_REPOSITORY https://github.com/madler/zlib.git
    GIT_TAG v1.3.2
    GIT_SHALLOW TRUE
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS} ${GR_DEPS_MSVC_RUNTIME_ARGS}
               -DZLIB_BUILD_SHARED=ON
               -DZLIB_BUILD_STATIC=OFF
               -DZLIB_BUILD_TESTING=OFF
               -DZLIB_INSTALL=ON
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
endif()

# libsoundio: the cross-platform audio I/O library behind gr-blocks' audio block family. It ships no
# CMake or pkg-config package of its own, so patches/libsoundio exports the shared library as
# libsoundio::libsoundio through a CMake config package, and through a CPS package as well when the
# CMake running this superbuild is 4.3 or newer; gr-blocks finds it with find_package(libsoundio).
#
# Shared only: on Windows the static library and the DLL's import library are both soundio.lib, and
# gr-blocks does not define SOUNDIO_STATIC_LIBRARY, so its headers expect the DLL. patches/libsoundio
# installs that DLL into bin rather than lib. The backends are whatever the build finds: WASAPI on
# Windows, CoreAudio on macOS, and on Linux ALSA, PulseAudio or JACK only when their development
# packages are installed. 2.0.0 declares cmake_minimum_required 2.8.5, below what CMake 4 accepts
# without CMAKE_POLICY_VERSION_MINIMUM.
if(ENABLE_LIBSOUNDIO)
  include(patch)
  gr_deps_patch_command(libsoundio gr_deps_libsoundio_patch)

  ExternalProject_Add(
    libsoundio
    URL https://github.com/andrewrk/libsoundio/archive/refs/tags/2.0.0.tar.gz
    URL_HASH SHA256=67a8fc1c9bef2b3704381bfb3fb3ce99e3952bc4fea2817729a7180fddf4a71e
    ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
    ${gr_deps_libsoundio_patch}
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS}
               ${GR_DEPS_MSVC_RUNTIME_ARGS}
               -DCMAKE_POLICY_VERSION_MINIMUM=3.5
               -DBUILD_DYNAMIC_LIBS=ON
               -DBUILD_STATIC_LIBS=OFF
               -DBUILD_EXAMPLE_PROGRAMS=OFF
               -DBUILD_TESTS=OFF
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
  gr_deps_patch_dependencies(libsoundio)
endif()

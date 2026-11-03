# cppzmq: the header-only C++ binding for libzmq that gr-blocks' zeromq and network families include
# as zmq.hpp. Its CMake package (find_package(cppzmq)) finds libzmq through ZeroMQ's package in turn,
# both at configure time here and for a consumer, so it builds after libzmq when that is built here.
# Only the cppzmq target is usable: cppzmq-static names libzmq-static, which libzmq.cmake does not
# build.
if(ENABLE_CPPZMQ)
  set(gr_deps_cppzmq_depends "")
  if(ENABLE_LIBZMQ)
    set(gr_deps_cppzmq_depends libzmq)
  endif()

  ExternalProject_Add(
    cppzmq
    URL https://github.com/zeromq/cppzmq/archive/refs/tags/v4.11.0.tar.gz
    URL_HASH SHA256=0fff4ff311a7c88fdb76fceefba0e180232d56984f577db371d505e4d4c91afd
    ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
    DEPENDS ${gr_deps_cppzmq_depends}
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS} -DCPPZMQ_BUILD_TESTS=OFF
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
endif()

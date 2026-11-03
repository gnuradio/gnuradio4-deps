# libzmq: the ZeroMQ messaging library behind gr-blocks' zeromq and network block families. Installs
# its own CMake package, so a consumer finds it with find_package(ZeroMQ), as cppzmq does, and the
# targets libzmq names. On Windows the package lands in <prefix>/CMake, a location find_package
# searches.
#
# Shared only. Everything optional is off (CURVE, TLS for WebSocket, libbsd, drafts), so the install
# depends on nothing beyond the platform. 4.3.5 declares cmake_minimum_required 2.8.12, below what
# CMake 4 accepts without CMAKE_POLICY_VERSION_MINIMUM.
if(ENABLE_LIBZMQ)
  ExternalProject_Add(
    libzmq
    URL https://github.com/zeromq/libzmq/releases/download/v4.3.5/zeromq-4.3.5.tar.gz
    URL_HASH SHA256=6653ef5910f17954861fe72332e68b03ca6e4d9c7160eb3a8de5a5a913bfab43
    ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS}
               ${GR_DEPS_MSVC_RUNTIME_ARGS}
               -DCMAKE_POLICY_VERSION_MINIMUM=3.5
               -DBUILD_SHARED=ON
               -DBUILD_STATIC=OFF
               -DBUILD_TESTS=OFF
               -DWITH_DOCS=OFF
               -DWITH_PERF_TOOL=OFF
               -DENABLE_CPACK=OFF
               -DENABLE_DRAFTS=OFF
               -DENABLE_CURVE=OFF
               -DWITH_LIBSODIUM=OFF
               -DWITH_TLS=OFF
               -DWITH_LIBBSD=OFF
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
endif()

# Boost: gr-control-plane's HTTP server includes Asio and Beast, both header-only, and reaches them
# through the FindBoost module (Boost_NO_BOOST_CMAKE ON) and its Boost::headers target.
#
# Fetched as the release's CMake tarball rather than the git superproject, which would clone every
# library's submodule. BOOST_INCLUDE_LIBRARIES narrows the build to Asio, Beast and what they depend
# on. BOOST_INSTALL_LAYOUT=system puts the headers in include/boost on Windows as well, where the
# default versioned layout (include/boost-1_92) is a path FindBoost only searches for the releases
# it knows about.
if(ENABLE_BOOST)
  ExternalProject_Add(
    boost
    URL https://github.com/boostorg/boost/releases/download/boost-1.92.0/boost-1.92.0-cmake.tar.xz
    URL_HASH SHA256=9bed76128d4e46755dbe818487788c6fceb6f72b378f4daa49b7e1e600d9088d
    ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
    LIST_SEPARATOR |
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS} ${GR_DEPS_MSVC_RUNTIME_ARGS}
               -DBOOST_INCLUDE_LIBRARIES=asio|beast
               -DBOOST_INSTALL_LAYOUT=system
               -DBUILD_TESTING=OFF
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
endif()

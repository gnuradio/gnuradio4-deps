cmake_minimum_required(VERSION 3.21..4.5)

project(GR_DEPS LANGUAGES NONE)

include(ExternalProject)

# target groups
option(TARGET_ALL "Build Dependencies needed for all GR libraries" OFF)
option(TARGET_GR_CORE "Build dependencies needed for core GR development" ON)
option(TARGET_GR_BLOCKS "Build dependencies needed for GR Blocks development" OFF)
option(TARGET_GR_CONTROL_PLANE "Build dependencies needed for GR Control Plane development" OFF)
option(TARGET_GR_STUDIO "Build dependencies needed for GR Studio development" OFF)

option(ENABLE_VIR_SIMD "Build vir-simd subproject" ${TARGET_GR_CORE})
option(ENABLE_HTTPLIB "Build cpp-httplib subproject" ${TARGET_GR_CORE})
option(ENABLE_BOOST_UT "Build boost.ut subproject" ${TARGET_GR_CORE})
option(ENABLE_MAGIC_ENUM "Build magic-enum subproject" ${TARGET_GR_CORE})

if(TARGET_ALL)
  set(TARGET_GR_CORE ON)
  set(TARGET_GR_BLOCKS ON)
  set(TARGET_GR_CONTROL_PLANE ON)
  set(TARGET_GR_STUDIO ON)
endif()

# Test-only dependencies (boost.ut, GoogleTest) are wanted only when the consuming projects build
# their tests, so they also need this. Kept apart from the TARGET_GR_* groups, which say which
# projects are being built rather than how.
option(TARGET_TESTS "Build the dependencies GR projects need only for their tests" ON)

# gr_deps_option(<name> <doc> <default>)
#
# A dependency toggle whose default comes from the target groups. option() reads its default only
# on the first configure, so in an existing build tree turning a group on would enable nothing; this
# re-derives the value on every configure instead. A value that differs from the one last derived
# was set by the user, and is left alone from then on until it is removed with -U<name>, which
# hands it back to its groups.
function(gr_deps_option name doc default)
  if(default)
    set(default ON)
  else()
    set(default OFF)
  endif()
  set(derived_entry "_GR_DEPS_${name}_DERIVED")
  set(user_entry "_GR_DEPS_${name}_USER_SET")

  if(NOT DEFINED CACHE{${name}})
    set(user_set OFF)
  elseif("$CACHE{${user_entry}}")
    set(user_set ON)
  else()
    # nothing derived yet means a first configure given -D<name>, or a tree from before this
    # function, so the value is measured against the default it would have had
    if(DEFINED CACHE{${derived_entry}})
      set(last_derived "$CACHE{${derived_entry}}")
    else()
      set(last_derived "${default}")
    endif()
    if("$CACHE{${name}}")
      set(current ON)
    else()
      set(current OFF)
    endif()
    if(current STREQUAL last_derived)
      set(user_set OFF)
    else()
      set(user_set ON)
    endif()
  endif()

  if(user_set)
    set(${name}
        "$CACHE{${name}}"
        CACHE BOOL "${doc}")
  else()
    set(${name}
        ${default}
        CACHE BOOL "${doc}" FORCE)
  endif()
  set(${derived_entry}
      ${default}
      CACHE INTERNAL "Group-derived value last offered for ${name}")
  set(${user_entry}
      ${user_set}
      CACHE INTERNAL "Whether ${name} was set by the user rather than derived from the groups")
endfunction()

# defaults for dependencies shared by more than one group, or gated on TARGET_TESTS
if(TARGET_GR_CORE OR TARGET_GR_CONTROL_PLANE OR TARGET_GR_STUDIO)
  set(gr_deps_httplib_default ON)
else()
  set(gr_deps_httplib_default OFF)
endif()
if(TARGET_GR_CORE AND TARGET_TESTS)
  set(gr_deps_boost_ut_default ON)
else()
  set(gr_deps_boost_ut_default OFF)
endif()
if(TARGET_GR_CONTROL_PLANE AND TARGET_TESTS)
  set(gr_deps_gtest_default ON)
else()
  set(gr_deps_gtest_default OFF)
endif()

# individual dependencies, batch enabled by group
# core requirements, each individually togglable, enabled by group
gr_deps_option(ENABLE_VIR_SIMD "Build vir-simd subproject" ${TARGET_GR_CORE})
gr_deps_option(ENABLE_HTTPLIB "Build cpp-httplib subproject" ${gr_deps_httplib_default})
gr_deps_option(ENABLE_BOOST_UT "Build boost.ut subproject" ${gr_deps_boost_ut_default})
gr_deps_option(ENABLE_MAGIC_ENUM "Build magic-enum subproject" ${TARGET_GR_CORE})

gr_deps_option(ENABLE_SOAPY_SDR "Build soapysdr" ${TARGET_GR_BLOCKS})

gr_deps_option(ENABLE_NLOHMANN_JSON "Build nlohmann-json subproject" ${TARGET_GR_CONTROL_PLANE})
gr_deps_option(ENABLE_BOOST "Build Boost subproject (Asio, Beast)" ${TARGET_GR_CONTROL_PLANE})
gr_deps_option(ENABLE_ZLIB "Build zlib subproject" ${TARGET_GR_CONTROL_PLANE})
gr_deps_option(ENABLE_GTEST "Build GoogleTest subproject" ${gr_deps_gtest_default})

gr_deps_option(ENABLE_OPENSSL "Build OpenSSL subproject (needs Perl, and NASM on Windows)" ${TARGET_GR_STUDIO})

# located rather than built: toolchain or system provided
option(ENABLE_TBB "Locate TBB, for std::execution::par under libstdc++" OFF)
gr_deps_option(ENABLE_PYTHON3 "Locate CPython and NumPy" ${TARGET_GR_CORE})

# every subproject installs here, and every subproject searches here, so that a dependency that
# needs another one finds the copy this superbuild just installed
set(GR_DEPS_INSTALL_PREFIX
    "${CMAKE_INSTALL_PREFIX}"
    CACHE PATH "Shared install prefix for every dependency built here")

set(GR_DEPS_BUILD_TYPE
    "${CMAKE_BUILD_TYPE}"
    CACHE STRING "Build type used for every dependency built here")
if(NOT GR_DEPS_BUILD_TYPE)
  set(GR_DEPS_BUILD_TYPE Release)
endif()

# MSVC runtime. A dependency that links a different C runtime than the GR project consuming it ends
# up with a second heap and a second set of CRT globals, so the choice is forced on every subproject
# rather than left to each one's own default.
option(GR_DEPS_MSVC_RUNTIME_STATIC "Link the static MSVC runtime (/MT) rather than the DLL runtime (/MD)" OFF)
set(GR_DEPS_MSVC_RUNTIME_DEBUG
    "DEFAULT"
    CACHE STRING "Debug MSVC runtime (/MDd, /MTd): ON, OFF, or DEFAULT to follow GR_DEPS_BUILD_TYPE")
set_property(
  CACHE GR_DEPS_MSVC_RUNTIME_DEBUG
  PROPERTY STRINGS
           DEFAULT
           ON
           OFF)

if(GR_DEPS_MSVC_RUNTIME_DEBUG STREQUAL "DEFAULT")
  if(GR_DEPS_BUILD_TYPE STREQUAL "Debug")
    set(gr_deps_runtime_debug ON)
  else()
    set(gr_deps_runtime_debug OFF)
  endif()
else()
  set(gr_deps_runtime_debug ${GR_DEPS_MSVC_RUNTIME_DEBUG})
endif()

set(GR_DEPS_MSVC_RUNTIME_LIBRARY "MultiThreaded")
if(gr_deps_runtime_debug)
  string(APPEND GR_DEPS_MSVC_RUNTIME_LIBRARY "Debug")
endif()
if(NOT GR_DEPS_MSVC_RUNTIME_STATIC)
  string(APPEND GR_DEPS_MSVC_RUNTIME_LIBRARY "DLL")
endif()

set(GR_DEPS_MSVC_RUNTIME_ARGS -DCMAKE_MSVC_RUNTIME_LIBRARY=${GR_DEPS_MSVC_RUNTIME_LIBRARY}
                              -DCMAKE_POLICY_DEFAULT_CMP0091=NEW)

set(GR_DEPS_EXTRA_CMAKE_ARGS
    ""
    CACHE STRING "Additional CMake arguments passed to every CMake dependency build")

# All CMake dependencies will need to define these common arguments to establish a unified
# dependency layout
set(GR_DEPS_INSTALL_ARGS -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
                         -DCMAKE_PREFIX_PATH=${GR_DEPS_INSTALL_PREFIX}
                         -DCMAKE_BUILD_TYPE=${GR_DEPS_BUILD_TYPE}
                         ${GR_DEPS_EXTRA_CMAKE_ARGS}
                        )


# set CMake module path so includes look slightly nicer
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/deps)

include(deps)

message(STATUS "")
message(STATUS "gr-deps install prefix : ${GR_DEPS_INSTALL_PREFIX}")
message(STATUS "  vir-simd             : ${ENABLE_VIR_SIMD}")
message(STATUS "  cpp-httplib          : ${ENABLE_HTTPLIB}")
message(STATUS "  boost.ut             : ${ENABLE_BOOST_UT}")
message(STATUS "  magic-enum           : ${ENABLE_MAGIC_ENUM}")
message(STATUS "  SoapySDR             : ${ENABLE_SOAPY_SDR}")
message(STATUS "  nlohmann-json        : ${ENABLE_NLOHMANN_JSON}")
message(STATUS "  Boost                : ${ENABLE_BOOST}")
message(STATUS "  zlib                 : ${ENABLE_ZLIB}")
message(STATUS "  GoogleTest           : ${ENABLE_GTEST}")
message(STATUS "  OpenSSL              : ${ENABLE_OPENSSL}")
message(STATUS "  TBB (located)        : ${ENABLE_TBB}")
message(STATUS "  Python3 (located)    : ${ENABLE_PYTHON3}")
message(STATUS "gr-deps build type     : ${GR_DEPS_BUILD_TYPE}")
message(STATUS "gr-deps MSVC runtime   : ${GR_DEPS_MSVC_RUNTIME_LIBRARY}")
message(STATUS "")

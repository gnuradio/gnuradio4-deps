# Perl: a build tool, run by OpenSSL's Configure and by NASM's source generators. An installed perl
# is used when one is suitable, otherwise Perl is built from source following Spack's recipe.
#
# Suitable means at least 5.10, OpenSSL's minimum, and on Windows a native perl ($^O is MSWin32)
# such as Strawberry Perl. OpenSSL's Configure only produces Windows paths under a native perl, so
# an MSYS or Cygwin perl, like the one Git for Windows ships, is passed over.
#
# Sets GR_DEPS_PERL to the perl to run, and GR_DEPS_PERL_TARGET to the step that builds it (empty
# for an installed perl) for consumers to add to their DEPENDS.
include_guard(GLOBAL)
include(build-tools)

function(gr_deps_perl_validator result perl)
  set(${result}
      FALSE
      PARENT_SCOPE)
  execute_process(
    COMMAND "${perl}" -e "print qq($^O $])"
    OUTPUT_VARIABLE out
    RESULT_VARIABLE rc
    ERROR_QUIET)
  if(NOT rc EQUAL 0 OR NOT out MATCHES "^([^ ]+) ([0-9.]+)$")
    return()
  endif()
  if(CMAKE_MATCH_2 LESS 5.010)
    return()
  endif()
  if(WIN32 AND NOT CMAKE_MATCH_1 STREQUAL "MSWin32")
    return()
  endif()
  set(${result}
      TRUE
      PARENT_SCOPE)
endfunction()

gr_deps_find_tool(PERL perl gr_deps_perl_validator "C:/Strawberry/perl/bin")

set(GR_DEPS_PERL_TARGET "")
if(GR_DEPS_PERL)
  message(STATUS "Perl: ${GR_DEPS_PERL}")
else()
  message(STATUS "Perl: no suitable perl found or GR_DEPS_BUILD_PERL is on, building it")
  set(GR_DEPS_PERL_TARGET perl)
  set(gr_deps_perl_url https://www.cpan.org/src/5.0/perl-5.42.3.tar.gz)
  set(gr_deps_perl_hash SHA256=1137740985837b5cdf15f0cfab932279dcb4352f912fed6fc144e8b4f0823627)

  if(WIN32)
    # win32/Makefile has to be told the compiler generation; MSVC143 (Visual Studio 2022) is the
    # newest it knows and also holds for later toolsets.
    set(GR_DEPS_PERL_CCTYPE
        "MSVC143"
        CACHE STRING "CCTYPE for Perl's win32/Makefile: MSVC141, MSVC142 or MSVC143")
    set(GR_DEPS_PERL "${GR_DEPS_TOOLS_PREFIX}/bin/perl.exe")
    file(TO_NATIVE_PATH "${GR_DEPS_TOOLS_PREFIX}" gr_deps_perl_inst_top)
    set(gr_deps_perl_nmake_args CCTYPE=${GR_DEPS_PERL_CCTYPE} INST_TOP=${gr_deps_perl_inst_top})
    gr_deps_msvc_wrapper(gr_deps_perl_env perl)

    # nmake runs in win32/, which BUILD_IN_SOURCE with SOURCE_SUBDIR makes the working directory.
    # installbare skips the HTML documentation that the install target also builds.
    ExternalProject_Add(
      perl
      URL ${gr_deps_perl_url}
      URL_HASH ${gr_deps_perl_hash}
      ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
      SOURCE_SUBDIR win32
      BUILD_IN_SOURCE TRUE
      INSTALL_DIR "${GR_DEPS_TOOLS_PREFIX}"
      CONFIGURE_COMMAND ""
      BUILD_COMMAND "${gr_deps_perl_env}" nmake ${gr_deps_perl_nmake_args}
      INSTALL_COMMAND "${gr_deps_perl_env}" nmake installbare ${gr_deps_perl_nmake_args}
      USES_TERMINAL_BUILD TRUE
      USES_TERMINAL_INSTALL TRUE)
  else()
    set(GR_DEPS_PERL "${GR_DEPS_TOOLS_PREFIX}/bin/perl")
    ExternalProject_Add(
      perl
      URL ${gr_deps_perl_url}
      URL_HASH ${gr_deps_perl_hash}
      ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
      BUILD_IN_SOURCE TRUE
      INSTALL_DIR "${GR_DEPS_TOOLS_PREFIX}"
      CONFIGURE_COMMAND sh Configure -des -Dprefix=<INSTALL_DIR>
      BUILD_COMMAND make
      INSTALL_COMMAND make install
      USES_TERMINAL_CONFIGURE TRUE
      USES_TERMINAL_BUILD TRUE
      USES_TERMINAL_INSTALL TRUE)
  endif()
endif()

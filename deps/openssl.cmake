# OpenSSL: gr-studio's blocks compute the WebSocket handshake with SHA1 and find it through
# find_package(OpenSSL REQUIRED COMPONENTS Crypto), CMake's FindOpenSSL module. Pinned to the 3.5
# long term support series.
#
# OpenSSL builds with its own Perl Configure script and make, or on Windows nmake with NASM
# assembling its x86_64 code, so it pulls in those tools through perl.cmake and nasm.cmake.
# install_sw installs the libraries, headers and openssl program without the documentation, and
# --libdir=lib keeps the libraries out of lib64.
#
# MSVC runtime: OpenSSL picks its own CRT flag rather than reading CMAKE_MSVC_RUNTIME_LIBRARY. A
# shared build uses /MD, or /MDd under --debug, and a static (no-shared) build compiles with
# /MT /Zl, leaving the CRT to the consumer, so GR_DEPS_MSVC_RUNTIME_STATIC maps to no-shared and a
# debug runtime to --debug.
if(ENABLE_OPENSSL)
  include(perl)
  if(WIN32)
    include(nasm)
  endif()

  file(TO_NATIVE_PATH "${GR_DEPS_INSTALL_PREFIX}" gr_deps_openssl_prefix)
  file(TO_NATIVE_PATH "${GR_DEPS_INSTALL_PREFIX}/ssl" gr_deps_openssl_dir)
  set(gr_deps_openssl_args --prefix=${gr_deps_openssl_prefix} --openssldir=${gr_deps_openssl_dir} --libdir=lib
                           no-tests)
  if(WIN32 AND GR_DEPS_MSVC_RUNTIME_STATIC)
    list(APPEND gr_deps_openssl_args no-shared)
  else()
    list(APPEND gr_deps_openssl_args shared)
  endif()
  if(gr_deps_runtime_debug OR (NOT WIN32 AND GR_DEPS_BUILD_TYPE STREQUAL "Debug"))
    list(APPEND gr_deps_openssl_args --debug)
  endif()

  set(gr_deps_openssl_url https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz)
  set(gr_deps_openssl_hash SHA256=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a)

  if(WIN32)
    # Configure finds NASM only through PATH, both when configuring and when nmake assembles
    get_filename_component(gr_deps_perl_dir "${GR_DEPS_PERL}" DIRECTORY)
    get_filename_component(gr_deps_nasm_dir "${GR_DEPS_NASM}" DIRECTORY)
    gr_deps_msvc_wrapper(gr_deps_openssl_env openssl "${gr_deps_perl_dir}" "${gr_deps_nasm_dir}")

    ExternalProject_Add(
      openssl
      URL ${gr_deps_openssl_url}
      URL_HASH ${gr_deps_openssl_hash}
      ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
      DEPENDS ${GR_DEPS_PERL_TARGET} ${GR_DEPS_NASM_TARGET}
      INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
      CONFIGURE_COMMAND "${gr_deps_openssl_env}" perl <SOURCE_DIR>/Configure VC-WIN64A ${gr_deps_openssl_args}
      BUILD_COMMAND "${gr_deps_openssl_env}" nmake
      INSTALL_COMMAND "${gr_deps_openssl_env}" nmake install_sw
      USES_TERMINAL_CONFIGURE TRUE
      USES_TERMINAL_BUILD TRUE
      USES_TERMINAL_INSTALL TRUE)
  else()
    ExternalProject_Add(
      openssl
      URL ${gr_deps_openssl_url}
      URL_HASH ${gr_deps_openssl_hash}
      ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
      DEPENDS ${GR_DEPS_PERL_TARGET}
      INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
      CONFIGURE_COMMAND "${GR_DEPS_PERL}" <SOURCE_DIR>/Configure ${gr_deps_openssl_args}
      BUILD_COMMAND make
      INSTALL_COMMAND make install_sw
      USES_TERMINAL_CONFIGURE TRUE
      USES_TERMINAL_BUILD TRUE
      USES_TERMINAL_INSTALL TRUE)
  endif()
endif()

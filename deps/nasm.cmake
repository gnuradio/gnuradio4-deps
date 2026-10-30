# NASM: the assembler OpenSSL's x86_64 Windows build feeds its perlasm output to. An installed nasm
# is used when one is suitable, otherwise NASM is built from source following Spack's recipe.
#
# Suitable means 2.09 or newer, below which OpenSSL warns SHA3 may be miscompiled. Besides PATH,
# the directories the NASM installer uses for an all users and a per user install are searched.
#
# Sets GR_DEPS_NASM to the nasm to run, and GR_DEPS_NASM_TARGET to the step that builds it (empty
# for an installed nasm) for consumers to add to their DEPENDS.
include_guard(GLOBAL)
include(build-tools)

function(gr_deps_nasm_validator result nasm)
  set(${result}
      FALSE
      PARENT_SCOPE)
  execute_process(
    COMMAND "${nasm}" -v
    OUTPUT_VARIABLE out
    RESULT_VARIABLE rc
    ERROR_QUIET)
  if(rc EQUAL 0
     AND out MATCHES "NASM version ([0-9]+\\.[0-9]+)"
     AND CMAKE_MATCH_1 VERSION_GREATER_EQUAL 2.09)
    set(${result}
        TRUE
        PARENT_SCOPE)
  endif()
endfunction()

gr_deps_find_tool(NASM nasm gr_deps_nasm_validator "$ENV{ProgramFiles}/NASM" "$ENV{LOCALAPPDATA}/bin/NASM")

set(GR_DEPS_NASM_TARGET "")
if(GR_DEPS_NASM)
  message(STATUS "NASM: ${GR_DEPS_NASM}")
else()
  message(STATUS "NASM: no suitable nasm found or GR_DEPS_BUILD_NASM is on, building it")
  set(GR_DEPS_NASM_TARGET nasm)
  set(gr_deps_nasm_url https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.gz)
  set(gr_deps_nasm_hash SHA256=5bc940dd8a4245686976a8f7e96ba9340a0915f2d5b88356874890e207bdb581)

  if(WIN32)
    # Mkfiles/msvc.mak regenerates some distributed sources with perl, so perl goes on PATH. It
    # has no install target, so the two programs are copied into bin/ by hand.
    include(perl)
    get_filename_component(gr_deps_perl_dir "${GR_DEPS_PERL}" DIRECTORY)
    gr_deps_msvc_wrapper(gr_deps_nasm_env nasm "${gr_deps_perl_dir}")
    set(GR_DEPS_NASM "${GR_DEPS_TOOLS_PREFIX}/bin/nasm.exe")

    # asm/warnings.time is touched, as Spack does, so the warning tables shipped in the tarball are
    # used rather than regenerated.
    ExternalProject_Add(
      nasm
      URL ${gr_deps_nasm_url}
      URL_HASH ${gr_deps_nasm_hash}
      ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
      DEPENDS ${GR_DEPS_PERL_TARGET}
      BUILD_IN_SOURCE TRUE
      INSTALL_DIR "${GR_DEPS_TOOLS_PREFIX}"
      PATCH_COMMAND ${CMAKE_COMMAND} -E touch <SOURCE_DIR>/asm/warnings.time
      CONFIGURE_COMMAND ""
      BUILD_COMMAND "${gr_deps_nasm_env}" nmake /f Mkfiles\\msvc.mak
      INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/bin
      COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/nasm.exe <SOURCE_DIR>/ndisasm.exe <INSTALL_DIR>/bin
      USES_TERMINAL_BUILD TRUE
      USES_TERMINAL_INSTALL TRUE)
  else()
    set(GR_DEPS_NASM "${GR_DEPS_TOOLS_PREFIX}/bin/nasm")
    ExternalProject_Add(
      nasm
      URL ${gr_deps_nasm_url}
      URL_HASH ${gr_deps_nasm_hash}
      ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
      BUILD_IN_SOURCE TRUE
      INSTALL_DIR "${GR_DEPS_TOOLS_PREFIX}"
      CONFIGURE_COMMAND sh configure --prefix=<INSTALL_DIR>
      BUILD_COMMAND make
      INSTALL_COMMAND make install
      USES_TERMINAL_CONFIGURE TRUE
      USES_TERMINAL_BUILD TRUE
      USES_TERMINAL_INSTALL TRUE)
  endif()
endif()

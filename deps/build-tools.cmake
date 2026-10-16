# Infrastructure for the build tools that some dependencies need but no GR project links (Perl,
# NASM): finding an installed copy that is fit for the job, falling back to building one into
# GR_DEPS_TOOLS_PREFIX, and running the nmake driven builds inside an MSVC environment on Windows.
include_guard(GLOBAL)

set(GR_DEPS_TOOLS_PREFIX
    "${CMAKE_BINARY_DIR}/tools"
    CACHE PATH "Install prefix for build tools built here, kept apart from the dependencies")

# gr_deps_find_tool(<NAME> <program> <validator> [<hint dir>...])
#
# Sets GR_DEPS_<NAME> to an installed <program> that <validator>(<result var> <path>) accepts.
# GR_DEPS_<NAME>_EXECUTABLE, when set, is the only candidate and must pass. Otherwise the first copy
# on PATH, then in the hint directories, that passes is taken; unlike find_program, a copy that
# fails does not hide a later one that passes. GR_DEPS_<NAME> is left empty, meaning build one,
# when nothing passes or when GR_DEPS_BUILD_<NAME> is on.
function(gr_deps_find_tool name program validator)
  option(GR_DEPS_BUILD_${name} "Build ${program} from source even when a suitable one is installed" OFF)
  set(GR_DEPS_${name}_EXECUTABLE
      ""
      CACHE FILEPATH "${program} to use instead of searching for one")

  set(found "")
  if(GR_DEPS_BUILD_${name})
    # forced source build
  elseif(GR_DEPS_${name}_EXECUTABLE)
    cmake_language(CALL ${validator} ok "${GR_DEPS_${name}_EXECUTABLE}")
    if(NOT ok)
      message(FATAL_ERROR "GR_DEPS_${name}_EXECUTABLE (${GR_DEPS_${name}_EXECUTABLE}) is not a usable ${program}")
    endif()
    set(found "${GR_DEPS_${name}_EXECUTABLE}")
  else()
    file(TO_CMAKE_PATH "$ENV{PATH}" dirs)
    list(APPEND dirs ${ARGN})
    set(file_name "${program}")
    if(WIN32)
      string(APPEND file_name ".exe")
    endif()
    foreach(dir IN LISTS dirs)
      set(candidate "${dir}/${file_name}")
      if(EXISTS "${candidate}" AND NOT IS_DIRECTORY "${candidate}")
        cmake_language(CALL ${validator} ok "${candidate}")
        if(ok)
          set(found "${candidate}")
          break()
        endif()
      endif()
    endforeach()
  endif()

  set(GR_DEPS_${name}
      "${found}"
      PARENT_SCOPE)
endfunction()

# MSVC environment for the dependencies built with nmake rather than CMake. A CMake subproject gets
# its compiler from the generator, but nmake, cl and link are only on PATH inside a Visual Studio
# developer prompt, which the Visual Studio generator does not provide. When this configure did not
# run inside one, the newest Visual Studio with the x64 C++ tools is found with vswhere and entered
# through its vcvars64.bat.
if(WIN32 AND NOT DEFINED ENV{VCINSTALLDIR})
  set(gr_deps_program_files_x86 "ProgramFiles(x86)")
  find_program(
    GR_DEPS_VSWHERE vswhere
    PATHS "$ENV{${gr_deps_program_files_x86}}/Microsoft Visual Studio/Installer"
    NO_DEFAULT_PATH)
  set(gr_deps_vcvars_default "")
  if(GR_DEPS_VSWHERE)
    execute_process(
      COMMAND "${GR_DEPS_VSWHERE}" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
              -property installationPath
      OUTPUT_VARIABLE gr_deps_vs_path
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(gr_deps_vs_path)
      file(TO_CMAKE_PATH "${gr_deps_vs_path}" gr_deps_vs_path)
      set(gr_deps_vcvars_default "${gr_deps_vs_path}/VC/Auxiliary/Build/vcvars64.bat")
    endif()
  endif()
  set(GR_DEPS_VCVARS
      "${gr_deps_vcvars_default}"
      CACHE FILEPATH "vcvars script that sets up MSVC for the nmake driven builds")
endif()

# gr_deps_msvc_wrapper(<out var> <name> [<dir>...])
#
# Writes a batch script that enters the MSVC environment, when this configure is not already in one,
# prepends each <dir> to PATH, then runs its arguments, and sets <out var> to that script's path.
# Commands that need cl, nmake or the given tools run as "<script>" <command> <args>...
function(gr_deps_msvc_wrapper out_var name)
  # file(WRITE) writes in text mode, so \n already lands as CRLF on Windows. Perl's win32/Makefile
  # runs the miniperl it just built from the current directory, which cmd refuses to search when a
  # hardened environment sets NoDefaultCurrentDirectoryInExePath, so that is cleared.
  set(content "@echo off\nset NoDefaultCurrentDirectoryInExePath=\n")
  if(NOT DEFINED ENV{VCINSTALLDIR})
    if(NOT GR_DEPS_VCVARS OR NOT EXISTS "${GR_DEPS_VCVARS}")
      message(FATAL_ERROR "${name} is built with nmake and needs MSVC: configure from a Visual Studio developer "
                          "prompt, or set GR_DEPS_VCVARS to a vcvars64.bat")
    endif()
    file(TO_NATIVE_PATH "${GR_DEPS_VCVARS}" vcvars)
    string(APPEND content "call \"${vcvars}\" >nul || exit /b 1\n")
  endif()
  # Under Git Bash, as on GitHub's Windows runners, Git's usr/bin sits ahead of MSVC on PATH and
  # its coreutils link shadows link.exe, so MSVC's own bin directory is put first.
  string(APPEND content "if defined VSCMD_ARG_TGT_ARCH set \"PATH=%VCToolsInstallDir%bin\\Host%VSCMD_ARG_HOST_ARCH%\\%VSCMD_ARG_TGT_ARCH%;%PATH%\"\n")
  set(dirs ${ARGN})
  list(REMOVE_DUPLICATES dirs)
  foreach(dir IN LISTS dirs)
    file(TO_NATIVE_PATH "${dir}" dir)
    string(APPEND content "set \"PATH=${dir};%PATH%\"\n")
  endforeach()
  string(APPEND content "%*\nexit /b %ERRORLEVEL%\n")

  set(script "${CMAKE_BINARY_DIR}/msvc-env/${name}.bat")
  file(WRITE "${script}" "${content}")
  set(${out_var}
      "${script}"
      PARENT_SCOPE)
endfunction()

# nlohmann/json: header-only JSON library. gr-control-plane pins v3.12.0 in its Emscripten
# FetchContent_Declare and otherwise expects find_package(nlohmann_json CONFIG) to supply it.
#
# Fetched as the release's json.tar.xz, which carries only the headers and CMake files, rather than
# cloned: the repository's benchmark reports have file names too long for a Windows checkout
# without long path support.
if(ENABLE_NLOHMANN_JSON)
  ExternalProject_Add(
    nlohmann-json
    URL https://github.com/nlohmann/json/releases/download/v3.12.0/json.tar.xz
    URL_HASH SHA256=42f6e95cad6ec532fd372391373363b62a14af6d771056dbfc86160e6dfff7aa
    ${GR_DEPS_DOWNLOAD_TIMESTAMP_ARGS}
    INSTALL_DIR "${GR_DEPS_INSTALL_PREFIX}"
    CMAKE_GENERATOR "${CMAKE_GENERATOR}"
    CMAKE_ARGS ${GR_DEPS_INSTALL_ARGS} ${GR_DEPS_MSVC_RUNTIME_ARGS}
               -DJSON_BuildTests=OFF
               -DJSON_Install=ON
    USES_TERMINAL_CONFIGURE TRUE
    USES_TERMINAL_BUILD TRUE
    USES_TERMINAL_INSTALL TRUE)
endif()

# gnuradio4-deps

A CMake superbuild for the third-party dependencies of GNU Radio 4.

`gr-super` builds the GNU Radio projects themselves. This builds what they depend on, into one
install prefix, with one toolchain and one MSVC runtime, so that a GR project configured against
that prefix gets a consistent set.

Each dependency is declared in its own module under `deps/`. The few things more than one module
needs are shared: `deps/build-tools.cmake` finds or builds the Perl and NASM that OpenSSL needs, and
`deps/patch.cmake` applies the patches under `patches/`.

## Quick start

```sh
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/path/to/prefix
cmake --build build
```

Then point the GR projects at it:

```sh
cmake -S ../gr-core -B ../gr-core/build -DCMAKE_PREFIX_PATH=/path/to/prefix
```

Dependencies are built on demand, so `cmake --build build --target boost.ut` builds just that one.

Every dependency installs a CMake package; libsoundio ships none of its own, so a patch adds one,
and with CMake 4.3 or newer a CPS package beside it. The GR projects are expected to find them with
CMake alone; no pkg-config is involved.

## GitHub Action

The GR projects no longer build these dependencies inside their own CMake graph, so their CI has to
build them first. This repository is a composite action that does that and caches the result:

```yaml
steps:
  - uses: actions/checkout@v4

  - id: deps
    uses: gnuradio/gnuradio4-deps@main
    with:
      target-gr-blocks: ON

  # CMAKE_PREFIX_PATH now includes the prefix, so this finds the dependencies without extra flags
  - run: cmake -S . -B build && cmake --build build
```

On a cache miss the action configures and builds the superbuild, then saves the install prefix. On
a hit it restores the prefix and builds nothing. Either way, later steps in the job see the same
prefix.

### Inputs

Each toggle takes `ON` or `OFF` (or `true`/`false`, `yes`/`no`, `1`/`0`) and mirrors the CMake
option of the same name. An empty dependency toggle follows its group, as the CMake default does.
[docs/action-inputs.md](docs/action-inputs.md) has worked examples.

| Input | Default | CMake option |
| --- | --- | --- |
| `target-all` | `OFF` | `TARGET_ALL` |
| `target-gr-core` | `ON` | `TARGET_GR_CORE` |
| `target-gr-blocks` | `OFF` | `TARGET_GR_BLOCKS` |
| `target-gr-control-plane` | `OFF` | `TARGET_GR_CONTROL_PLANE` |
| `target-gr-studio` | `OFF` | `TARGET_GR_STUDIO` |
| `target-tests` | `ON` | `TARGET_TESTS` |
| `enable-vir-simd` | follows core | `ENABLE_VIR_SIMD` |
| `enable-httplib` | follows core, control-plane or Studio | `ENABLE_HTTPLIB` |
| `enable-boost-ut` | follows core and tests | `ENABLE_BOOST_UT` |
| `enable-magic-enum` | follows core | `ENABLE_MAGIC_ENUM` |
| `enable-soapy-sdr` | follows blocks | `ENABLE_SOAPY_SDR` |
| `enable-libzmq` | follows blocks | `ENABLE_LIBZMQ` |
| `enable-cppzmq` | follows blocks | `ENABLE_CPPZMQ` |
| `enable-libsoundio` | follows blocks | `ENABLE_LIBSOUNDIO` |
| `enable-nlohmann-json` | follows control-plane | `ENABLE_NLOHMANN_JSON` |
| `enable-boost` | follows control-plane | `ENABLE_BOOST` |
| `enable-zlib` | follows control-plane | `ENABLE_ZLIB` |
| `enable-gtest` | follows control-plane and tests | `ENABLE_GTEST` |
| `enable-openssl` | follows Studio | `ENABLE_OPENSSL` |
| `enable-tbb` | `OFF` | `ENABLE_TBB` |
| `enable-python3` | follows core | `ENABLE_PYTHON3` |
| `build-type` | `Release` | `GR_DEPS_BUILD_TYPE` |
| `msvc-runtime-static` | `OFF` | `GR_DEPS_MSVC_RUNTIME_STATIC` |
| `msvc-runtime-debug` | `DEFAULT` | `GR_DEPS_MSVC_RUNTIME_DEBUG` |

The toolchain and the build itself:

| Input | Default | Effect |
| --- | --- | --- |
| `generator` | CMake's default | passed as `-G` |
| `c-compiler` | the default | exported as `CC` to the dependency builds |
| `cxx-compiler` | the default | exported as `CXX` to the dependency builds |
| `cmake-args` | none | extra superbuild configure arguments, one per line |
| `install-prefix` | `<runner.temp>/gr-deps` | where the dependencies install, and what is cached |
| `build-dir` | `<runner.temp>/gr-deps-build` | superbuild binary directory, not cached |
| `cache` | `true` | `false` always builds and neither restores nor saves |
| `cache-key-prefix` | `gr-deps-v1` | first part of the key; change it to throw every entry away |
| `export-env` | `true` | see below |

Compilers are set through `CC` and `CXX`, not `-DCMAKE_CXX_COMPILER`, because the superbuild is
`LANGUAGES NONE`. The subprojects take their compiler from the environment, not from the
superbuild's cache. For the same reason, `cmake-args` only sets superbuild cache variables; to reach
the dependency builds themselves, pass `-DGR_DEPS_EXTRA_CMAKE_ARGS=...` through it.

### Outputs and environment

| Output | Value |
| --- | --- |
| `install-prefix` | absolute path of the prefix |
| `cache-hit` | `true` when the prefix was restored and nothing was built |
| `cache-key` | the key that was restored or saved |
| `toolchain` | the C and C++ compiler IDs and versions that were found |

With `export-env` on, later steps also get:

- `GR_DEPS_PREFIX` set to the prefix
- the prefix prepended to `CMAKE_PREFIX_PATH`
- `<prefix>/bin` added to `PATH`, so a test executable finds the dependency DLLs (`SoapySDR.dll`,
  `soundio.dll`, libzmq's) on Windows

### The cache key

A key looks like

```
gr-deps-v1-ubuntu24-X64-GNU-13.3.0-Release-vir1-http1-ut1-soapy0-zmq0-cppzmq0-sio0-magic1-json0-boost0-zlib0-gtest0-ssl0-tbb0-py1-3f9c0a17d2b84e61
```

The readable part names the runner image, architecture, C++ compiler, build type and selected
dependencies. The trailing hash covers everything that can change the installed files:

- **Selection.** The resolved toggles, not the group inputs. `target-gr-core: ON` and the matching
  explicit `enable-*: ON` inputs build the same thing, so they share one entry.
- **Toolchain.** The C and C++ compiler IDs and versions and the target processor. The superbuild
  enables no languages itself, so the action finds these by configuring a throwaway project with
  the same generator, `CC` and `CXX`. A runner image that upgrades its compiler gets a new entry.
- **Platform.** `runner.os`, `runner.arch`, and the image (`ImageOS`, e.g. `ubuntu22` vs `ubuntu24`).
- **Build settings.** Generator, build type, MSVC runtime settings, `cmake-args`, and the
  install prefix.
- **Recipes.** A hash of `CMakeLists.txt`, `deps/*.cmake`, `patches/*/*.patch` and `action.yml`, so
  moving a pin, changing a build flag or editing a patch rebuilds.

Restores need an exact match: there are no `restore-keys`. A partial match would restore a prefix
built for a different selection, and the stale extra dependencies would then be saved under the
new key.

### Platform notes

- **Windows with Ninja** needs the MSVC environment set up first, for example with
  `ilammy/msvc-dev-cmd`. The default Visual Studio generator does not. If no working compiler is
  found, the action stops with an error before building anything.
- **Multi-config generators** are built with `--config <build-type>`. Without it, ExternalProject
  builds and installs each dependency in the superbuild's own default configuration (`Debug` for
  Visual Studio), whatever `GR_DEPS_BUILD_TYPE` says.
- **TBB and Python** are only located, never installed. Install TBB first if you enable it (it is
  `REQUIRED`). For the Python pieces, set up Python 3.12 and NumPy first. On a cache hit the
  configure is skipped, so neither is looked for.
- **libsoundio on Linux** gets the ALSA, PulseAudio and JACK backends only for the development
  packages installed on the runner (`libasound2-dev`, `libpulse-dev`, `libjack-dev`). Install them
  before the action if the audio blocks need a real device; without them only the dummy backend is
  built.
- **A custom `install-prefix` should be empty.** The action clears its own default prefix and build
  directory before building, but leaves any path you give it alone. Anything already there would
  be cached along with the build.

## What is built, and what is only located

Built from source and pinned:

| Target | Source | Pin | Used by |
| --- | --- | --- | --- |
| `vir-simd` | mattkretz/vir-simd | `v0.4.4`, patched | gr-core |
| `boost.ut` | boost-ext/ut | `53e17f25` | gr-core, gr-library, gr-blocks |
| `cpp-httplib` | yhirose/cpp-httplib | `v0.18.1` | gr-core, gr-library, control-plane, Studio |
| `magic-enum` | Neargye/magic_enum | `e1ea11a9` | gr-core |
| `soapysdr` | pothosware/SoapySDR | `soapy-sdr-0.9.0` | gr-blocks |
| `libzmq` | zeromq/libzmq | `v4.3.5` | gr-blocks |
| `cppzmq` | zeromq/cppzmq | `v4.11.0` | gr-blocks |
| `libsoundio` | andrewrk/libsoundio | `2.0.0`, patched | gr-blocks |
| `nlohmann-json` | nlohmann/json | `v3.12.0` | control-plane |
| `boost` | boostorg/boost (Asio, Beast) | `1.92.0` | control-plane |
| `zlib` | madler/zlib | `v1.3.2` | control-plane |
| `googletest` | google/googletest | `v1.18.0` | control-plane |
| `openssl` | openssl/openssl | `3.5.9` | Studio |

OpenSSL needs Perl to configure, and NASM on Windows to assemble. Both are build tools only: an
installed copy is used when one is suitable, otherwise they are built from source into
`GR_DEPS_TOOLS_PREFIX`, apart from the dependencies (Perl `5.42.3`, NASM `2.16.03`). On Windows the
Perl must be a native one; the MSYS Perl that comes with Git for Windows cannot configure OpenSSL
and is skipped.

Located with `find_package`, never built, because they are toolchain or distribution provided:

| Module | Call |
| --- | --- |
| `deps/tbb.cmake` | `find_package(TBB REQUIRED)` |
| `deps/python3.cmake` | `find_package(Python3 3.12 COMPONENTS Interpreter Development NumPy)` |

Python3 is intentionally not `REQUIRED`, matching gr-core, which enables its Python-facing pieces
only when the interpreter, the development files and NumPy are all present.

### Patches

`patches/<dependency>/*.patch` are applied in name order with `patch -p1` to the freshly extracted
source. CMake's `FindPatch` finds `patch` on `PATH`, or on Windows the copy Git for Windows ships.
Changing or adding a patch re-extracts the source on the next build rather than patching an
already patched tree.

- **vir-simd** gates `vir::simdize`, `vir::simd_permute` and `constexpr_wrapper` to GCC and Clang.
  The patches are the MSVC series proposed upstream, backported to 0.4.4, plus upstream's own
  `<bit>` include fix. Every edit is a no-op for GCC and Clang; drop them once a release carries
  them.
- **libsoundio** installs its DLL into `bin` rather than `lib`, and compiles as C++ under MSVC with
  every generator (its `/TP` flag is ignored by the Visual Studio generators, and the C build needs
  C11 atomics MSVC lacks). It also exports the shared library as `libsoundio::libsoundio` through a
  CMake config package, and, when the CMake building it is 4.3 or newer (the first release that
  writes and reads CPS without an experimental gate), through a CPS package too; a consumer's
  `find_package(libsoundio)` prefers the `.cps` file where its CMake reads one. The backends are
  linked privately, so neither package names them.

## Options

Groups, which set the defaults for the individual toggles:

| Option | Default | Effect |
| --- | --- | --- |
| `TARGET_ALL` | `OFF` | turns every group below on |
| `TARGET_GR_CORE` | `ON` | the dependencies gr-core needs |
| `TARGET_GR_BLOCKS` | `OFF` | the dependencies gr-blocks needs |
| `TARGET_GR_CONTROL_PLANE` | `OFF` | the dependencies gnuradio4-control-plane needs |
| `TARGET_GR_STUDIO` | `OFF` | the dependencies gnuradio4-studio needs |
| `TARGET_TESTS` | `ON` | the dependencies those projects need only for their tests |

Individual dependencies, each overridable on its own:

| Option | Default |
| --- | --- |
| `ENABLE_VIR_SIMD` | core |
| `ENABLE_HTTPLIB` | core, control-plane or Studio |
| `ENABLE_BOOST_UT` | core and tests |
| `ENABLE_MAGIC_ENUM` | core |
| `ENABLE_SOAPY_SDR` | blocks |
| `ENABLE_LIBZMQ` | blocks |
| `ENABLE_CPPZMQ` | blocks |
| `ENABLE_LIBSOUNDIO` | blocks |
| `ENABLE_NLOHMANN_JSON` | control-plane |
| `ENABLE_BOOST` | control-plane |
| `ENABLE_ZLIB` | control-plane |
| `ENABLE_GTEST` | control-plane and tests |
| `ENABLE_OPENSSL` | Studio |
| `ENABLE_TBB` | `OFF` |
| `ENABLE_PYTHON3` | core |

A toggle follows its groups on every configure, so turning a group on in an existing build tree
takes effect. A toggle you set yourself (`-DENABLE_BOOST=OFF`) keeps your value from then on, whatever
the groups do, until you remove it with `-UENABLE_BOOST`, which hands it back to its groups.

Build-wide:

| Option | Default | Effect |
| --- | --- | --- |
| `GR_DEPS_INSTALL_PREFIX` | `${CMAKE_INSTALL_PREFIX}` | where every dependency installs |
| `GR_DEPS_BUILD_TYPE` | `${CMAKE_BUILD_TYPE}`, else `Release` | build type for every dependency |
| `GR_DEPS_EXTRA_CMAKE_ARGS` | empty | a list of arguments passed to every CMake dependency build, e.g. a toolchain file |

`GR_DEPS_EXTRA_CMAKE_ARGS` exists because the superbuild enables no languages, so nothing in its own
cache reaches the builds it spawns. An embedding superbuild passes the list with a
`LIST_SEPARATOR`. Perl, NASM and OpenSSL are not CMake builds and ignore it.

Build tools (only consulted when OpenSSL is enabled):

| Option | Default | Effect |
| --- | --- | --- |
| `GR_DEPS_PERL_EXECUTABLE` | empty | use this Perl; it must pass the same checks as one found on `PATH` |
| `GR_DEPS_NASM_EXECUTABLE` | empty | use this NASM (Windows), likewise |
| `GR_DEPS_BUILD_PERL` | `OFF` | build Perl from source even when a suitable one is installed |
| `GR_DEPS_BUILD_NASM` | `OFF` | build NASM from source even when a suitable one is installed |
| `GR_DEPS_TOOLS_PREFIX` | `<build>/tools` | where a built Perl or NASM installs |
| `GR_DEPS_VCVARS` | found with `vswhere` | Windows: the `vcvars64.bat` the nmake builds run under, when configure was not run from a developer prompt |
| `GR_DEPS_PERL_CCTYPE` | `MSVC143` | Windows: the `CCTYPE` Perl's nmake build is given |

## The install prefix

Every subproject is configured with both

- `-DCMAKE_INSTALL_PREFIX=${GR_DEPS_INSTALL_PREFIX}`, so everything lands in one tree, and
- `-DCMAKE_PREFIX_PATH=${GR_DEPS_INSTALL_PREFIX}`, so a dependency that needs an earlier one finds
  the copy this superbuild just installed rather than a system copy (cppzmq finds libzmq this way).

After a build the prefix looks like a normal install root, and the CMake packages the GR projects
look for are in it:

```
<prefix>/include/boost/ut.hpp
<prefix>/include/vir/
<prefix>/include/zmq.hpp
<prefix>/include/soundio/soundio.h
<prefix>/lib/cmake/libsoundio/libsoundioConfig.cmake
<prefix>/lib/cps/libsoundio/libsoundio.cps     (built with CMake 4.3 or newer)
<prefix>/lib/cmake/ut/utConfig.cmake
<prefix>/lib/cmake/vir-simd/vir-simd-config.cmake
<prefix>/lib/cmake/ZeroMQ/ZeroMQConfig.cmake     (<prefix>/CMake/ZeroMQConfig.cmake on Windows)
<prefix>/share/cmake/cppzmq/cppzmqConfig.cmake
```

## MSVC runtime

Mixing C runtimes across a program is a real failure, not a warning: memory allocated by one CRT
and freed by another, two sets of CRT globals, two `errno`. Every subproject is therefore forced
onto one runtime rather than left to its own default.

| Option | Default | Effect |
| --- | --- | --- |
| `GR_DEPS_MSVC_RUNTIME_STATIC` | `OFF` | `ON` selects the static runtime (`/MT`), `OFF` the DLL runtime (`/MD`) |
| `GR_DEPS_MSVC_RUNTIME_DEBUG` | `DEFAULT` | `DEFAULT` follows `GR_DEPS_BUILD_TYPE`; `ON` or `OFF` decides it independently |

Which resolves to:

| Build type | Static | Runtime | Flag |
| --- | --- | --- | --- |
| Release | `OFF` | `MultiThreadedDLL` | `/MD` |
| Debug | `OFF` | `MultiThreadedDebugDLL` | `/MDd` |
| Release | `ON` | `MultiThreaded` | `/MT` |
| Debug | `ON` | `MultiThreadedDebug` | `/MTd` |

The resolved value is printed at the end of configure, and the override exists because a debug
build against a release runtime is occasionally what you want when matching a prebuilt library.

**Why the policy is forced.** `CMAKE_MSVC_RUNTIME_LIBRARY` is only honoured under `CMP0091` set to
`NEW`, and a project inherits that policy from its own `cmake_minimum_required`. SoapySDR declares
`3.3...3.10`, vir-simd `3.5`, cpp-httplib `3.14`, libzmq `2.8.12` and libsoundio `2.8.5` — all
below the 3.15 that introduced the policy. Without `-DCMAKE_POLICY_DEFAULT_CMP0091=NEW` the runtime
setting would be accepted and then silently ignored by them. Both arguments are passed together,
from `GR_DEPS_MSVC_RUNTIME_ARGS`.

**OpenSSL picks its own runtime.** It is not a CMake build: a shared build uses `/MD` (`/MDd` with
`--debug`), and a static one compiles with `/MT /Zl`, leaving the runtime to the consumer. So
`GR_DEPS_MSVC_RUNTIME_STATIC` selects a static OpenSSL, and a debug runtime selects `--debug`.

The setting is harmless on non-MSVC toolchains, which ignore it.

## Notes

- **The SoapySDR pin is a choice, not a requirement.** Nothing in gr-blocks states a version; it
  only does `find_package(SoapySDR CONFIG QUIET)` and links the `SoapySDR` target. This tracks the
  newest release tag. Change `GIT_TAG` in `deps/soapysdr.cmake` if you need a specific one.
- **cpp-httplib is built even though gr-core only fetches it under Emscripten.** Elsewhere gr-core
  expects `find_package(httplib CONFIG)` or pkg-config to supply it, so building it here is what
  gives that path something to find. It stays header-only (`HTTPLIB_COMPILE=OFF`), which is the
  form gr-core and gr-library consume through `httplib::httplib`.
- **Boost.UT's toggles are set explicitly.** `BOOST_UT_BUILD_TESTS`, `BOOST_UT_BUILD_EXAMPLES` and
  `BOOST_UT_ENABLE_INSTALL` all default to `PROJECT_IS_TOP_LEVEL`, which is false when the GR repos
  fetch it as a subproject but true here, so leaving them unset would build its test suite.
- **SoapySDR's SWIG bindings** build only when SWIG and Python are found. This superbuild provides
  neither, so only the library and its CMake package are installed.
- **libzmq is built shared and self-contained.** CURVE, TLS for WebSocket, libsodium, libbsd and the
  draft API are all off, so it depends on nothing beyond the platform. Only cppzmq's `cppzmq`
  target is usable; `cppzmq-static` names a static libzmq that is not built.
- **libzmq and cppzmq also install pkg-config files**, as their own builds do, but nothing here
  relies on them. gr-blocks finds both through `find_package(cppzmq)`, whose `cppzmq` target carries
  libzmq with it.
- **libsoundio is built shared only.** On Windows its static library and its DLL's import library
  would both be `soundio.lib`, and gr-blocks does not define `SOUNDIO_STATIC_LIBRARY`, so its
  headers expect the DLL.
- **libzmq and libsoundio predate CMake 3.5** in their `cmake_minimum_required`, which CMake 4
  refuses outright, so both are configured with `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`.

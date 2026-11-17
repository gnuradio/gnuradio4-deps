# Installed-package smoke tests

These programs use the installed CMake packages to compile, link, and run small
operations with each dependency. They require no SDR hardware or network services.
They complement the composite action's cache and file-presence checks.

Build and install the dependencies, then configure the consumers in a separate tree:

```sh
cmake -S . -B build-deps -DTARGET_ALL=ON -DENABLE_PYTHON3=OFF -DCMAKE_INSTALL_PREFIX=/path/to/prefix
cmake --build build-deps --config Release --parallel 4
cmake -S tests/consumer -B build-consumer -DCMAKE_PREFIX_PATH=/path/to/prefix -DCHECK_BLOCKS=ON -DCHECK_CONTROL_PLANE=ON -DCHECK_STUDIO=ON
cmake --build build-consumer --config Release --parallel 4
ctest --test-dir build-consumer -C Release --output-on-failure
```

Without the `CHECK_*` flags, only the core dependencies are checked. The CI workflow
checks all groups on Linux, Windows, and macOS. It configures the superbuild directly,
so it does not depend on additions to the composite action's input interface.

On Windows, add `<prefix>/bin` to `PATH` before running tests. On Unix platforms,
shared libraries must also be discoverable at runtime; CI sets `LD_LIBRARY_PATH`
or `DYLD_LIBRARY_PATH` to the installed library directory. These tests cover the
Release configuration with the default compiler and runtime; they do not validate
cross compilation, hardware drivers, or every MSVC runtime combination.

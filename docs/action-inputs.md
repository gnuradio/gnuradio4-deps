# Action dependency selection

The composite action supports every superbuild group:

| Input | Default |
| --- | --- |
| `target-all` | `OFF` |
| `target-gr-core` | `ON` |
| `target-gr-blocks` | `OFF` |
| `target-gr-control-plane` | `OFF` |
| `target-gr-studio` | `OFF` |
| `target-tests` | `ON` |

`target-all` enables every group. `target-tests` gates Boost.UT and GoogleTest group
defaults. An explicit dependency input overrides its group defaults. Empty inputs
follow the groups; boolean inputs accept `ON`/`OFF`, `true`/`false`,
`yes`/`no`, `y`/`n`, and `1`/`0`, without regard to case.

| Dependency input | Default enabled when |
| --- | --- |
| `enable-vir-simd` | core |
| `enable-magic-enum` | core |
| `enable-httplib` | core, control-plane, or Studio |
| `enable-boost-ut` | core and tests |
| `enable-soapy-sdr` | blocks |
| `enable-nlohmann-json` | control-plane |
| `enable-boost` | control-plane |
| `enable-zlib` | control-plane |
| `enable-gtest` | control-plane and tests |
| `enable-openssl` | Studio |
| `enable-python3` | core |
| `enable-tbb` | never (explicit opt-in) |

For example:

```yaml
- uses: gnuradio/gnuradio4-deps@main
  with:
    target-gr-core: OFF
    target-gr-control-plane: ON
    target-tests: OFF
```

The cache key includes all resolved dependency selections. Equivalent selections
share a key regardless of which groups supplied the defaults. Recipe changes also
invalidate the cache, so prefixes created before these inputs were added are rebuilt.
Use the named inputs for dependency selection; reserve `cmake-args` for other
superbuild settings. Extra arguments remain part of the cache key.

Run the local script tests with `python -m pip install PyYAML==6.0.3` followed by
`python tests/test_action.py`. They execute the action's Bash scripts and verify
real CMake configuration, while skipping dependency builds and cache-service calls.

"""Run the actual composite-action scripts locally, without downloads or a cache service.

Requires PyYAML. The build-step tests configure real CMake projects but skip --build.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

import yaml

SOURCE = Path(__file__).resolve().parents[1]
ACTION = yaml.safe_load((SOURCE / "action.yml").read_text())
STEPS = {step["name"]: step for step in ACTION["runs"]["steps"]}
DEPENDENCIES = {
    "vir-simd": "VIR_SIMD", "httplib": "HTTPLIB", "boost-ut": "BOOST_UT",
    "magic-enum": "MAGIC_ENUM", "soapy-sdr": "SOAPY_SDR", "nlohmann-json": "NLOHMANN_JSON",
    "boost": "BOOST", "zlib": "ZLIB", "gtest": "GTEST", "openssl": "OPENSSL",
    "tbb": "TBB", "python3": "PYTHON3",
}


class ActionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gr-deps-action-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.inputs = {name: str(value["default"]) for name, value in ACTION["inputs"].items()}
        self.inputs["enable-python3"] = "OFF"
        self.outputs = {}

    def run_step(self, name, success=True, skip_build=False):
        step = STEPS[name]
        env = dict(os.environ, RUNNER_TEMP=str(self.root), GITHUB_WORKSPACE=str(SOURCE),
                   GITHUB_ACTION_PATH=str(SOURCE), RUNNER_OS="Linux", RUNNER_ARCH="X64",
                   ImageOS="ubuntu24", GITHUB_OUTPUT=str(self.root / "outputs"))
        for key, expression in step["env"].items():
            match = re.fullmatch(r"\$\{\{ inputs\.([\w-]+) \}\}", expression)
            if match:
                env[key] = self.inputs[match[1]]
            else:
                match = re.fullmatch(r"\$\{\{ steps.config.outputs\.([\w-]+) \}\}", expression)
                self.assertIsNotNone(match, expression)
                env[key] = self.outputs[match[1]]
        script = step["run"]
        if skip_build:
            script = 'cmake() { if [ "$1" = --build ]; then return 0; else command cmake "$@"; fi; }\n' + script
        result = subprocess.run(["bash", "-c", script], env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def resolve(self, **inputs):
        self.inputs.update(inputs)
        (self.root / "outputs").write_text("")
        self.run_step("Resolve configuration")
        self.outputs = dict(line.split("=", 1) for line in (self.root / "outputs").read_text().splitlines())
        return self.outputs

    def enabled(self):
        return {name for name in DEPENDENCIES if self.outputs[name] == "ON"}

    def test_default_selection(self):
        self.resolve()
        self.assertEqual(self.enabled(), {"vir-simd", "httplib", "boost-ut", "magic-enum"})

    def test_standalone_groups(self):
        for group, expected in [
            ("target-gr-blocks", {"soapy-sdr"}),
            ("target-gr-control-plane", {"httplib", "nlohmann-json", "boost", "zlib", "gtest"}),
            ("target-gr-studio", {"httplib", "openssl"}),
        ]:
            with self.subTest(group=group):
                for name in ("target-gr-blocks", "target-gr-control-plane", "target-gr-studio"):
                    self.inputs[name] = "OFF"
                self.resolve(**{"target-gr-core": "OFF", group: "ON"})
                self.assertEqual(self.enabled(), expected)

    def test_all_and_tests_off(self):
        self.resolve(**{"target-all": "ON", "target-gr-core": "OFF", "target-tests": "OFF"})
        self.assertEqual(self.enabled(), set(DEPENDENCIES) - {"boost-ut", "gtest", "tbb", "python3"})

    def test_explicit_test_overrides(self):
        self.resolve(**{"target-all": "ON", "target-tests": "OFF", "enable-boost-ut": "ON", "enable-gtest": "ON"})
        self.assertEqual(self.outputs["boost-ut"], "ON")
        self.assertEqual(self.outputs["gtest"], "ON")

    def test_equivalent_selections_share_key(self):
        group_key = self.resolve(**{"target-all": "ON"})["key"]
        explicit = {"enable-" + name: "ON" for name in DEPENDENCIES if name not in {"tbb", "python3"}}
        explicit.update({"target-all": "OFF", "target-gr-core": "OFF"})
        self.assertEqual(self.resolve(**explicit)["key"], group_key)

    def test_every_dependency_changes_key(self):
        baseline = self.resolve(**{"target-gr-core": "OFF"})["key"]
        for name in DEPENDENCIES:
            with self.subTest(dependency=name):
                key = self.resolve(**{"enable-" + name: "ON"})["key"]
                self.assertNotEqual(key, baseline)
                self.inputs["enable-" + name] = "OFF"

    def test_boolean_aliases(self):
        self.resolve(**{"target-gr-studio": "true", "enable-openssl": "", "enable-vir-simd": "no"})
        self.assertEqual(self.outputs["openssl"], "ON")
        self.assertEqual(self.outputs["vir-simd"], "OFF")

    def test_invalid_toggle(self):
        self.inputs["enable-openssl"] = "invalid"
        result = self.run_step("Resolve configuration", success=False)
        self.assertIn("enable-openssl must be ON or OFF", result.stdout)

    def test_build_forwards_resolved_selection(self):
        # This also runs against the original superbuild: no selection-fix PR is required.
        for selection in [
            {"target-gr-core": "OFF", "target-gr-control-plane": "ON"},
            {"target-gr-core": "OFF", "target-gr-studio": "ON"},
            {"target-all": "ON", "target-tests": "OFF"},
        ]:
            with self.subTest(selection=selection):
                for name in ("target-all", "target-gr-control-plane", "target-gr-studio"):
                    self.inputs[name] = "OFF"
                self.resolve(**selection)
                self.run_step("Build dependencies", skip_build=True)
                cache = (Path(self.outputs["build-dir"]) / "CMakeCache.txt").read_text()
                for name, variable in DEPENDENCIES.items():
                    self.assertRegex(cache, rf"ENABLE_{variable}:(?:BOOL|STRING)={self.outputs[name]}\n")


if __name__ == "__main__":
    unittest.main()

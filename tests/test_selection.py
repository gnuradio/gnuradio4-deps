"""Configure-only regression tests; no dependency downloads or third-party modules."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]
CMAKE = os.environ.get("CMAKE_COMMAND", "cmake")


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gr-deps-selection-")
        self.addCleanup(self.temp.cleanup)
        self.build = Path(self.temp.name) / "build"

    def configure(self, *args, success=True):
        result = subprocess.run(
            [CMAKE, "-S", str(SOURCE), "-B", str(self.build),
             "-DENABLE_PYTHON3=OFF", *args],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        if not success:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            return result.stdout
        self.assertEqual(result.returncode, 0, result.stdout)
        return dict(re.findall(r"^--   (.*?)\s+: (ON|OFF)$", result.stdout, re.MULTILINE))

    def enabled(self, selection):
        return {name for name, value in selection.items() if value == "ON"}

    def test_core(self):
        self.assertEqual(self.enabled(self.configure()),
                         {"vir-simd", "cpp-httplib", "boost.ut", "magic-enum"})

    def test_empty(self):
        self.assertEqual(self.enabled(self.configure("-DTARGET_GR_CORE=OFF")), set())

    def test_blocks(self):
        self.assertEqual(self.enabled(self.configure(
            "-DTARGET_GR_CORE=OFF", "-DTARGET_GR_BLOCKS=ON")), {"SoapySDR"})

    def test_control_plane(self):
        self.assertEqual(self.enabled(self.configure(
            "-DTARGET_GR_CORE=OFF", "-DTARGET_GR_CONTROL_PLANE=ON")),
            {"cpp-httplib", "nlohmann-json", "Boost", "zlib", "GoogleTest"})

    def test_studio(self):
        self.assertEqual(self.enabled(self.configure(
            "-DTARGET_GR_CORE=OFF", "-DTARGET_GR_STUDIO=ON")),
            {"cpp-httplib", "OpenSSL"})

    def test_all_overrides_disabled_groups(self):
        self.assertEqual(self.enabled(self.configure(
            "-DTARGET_GR_CORE=OFF", "-DTARGET_ALL=ON")),
            {"vir-simd", "cpp-httplib", "boost.ut", "magic-enum", "SoapySDR",
             "nlohmann-json", "Boost", "zlib", "GoogleTest", "OpenSSL"})

    def test_tests_off(self):
        result = self.configure("-DTARGET_ALL=ON", "-DTARGET_TESTS=OFF")
        self.assertEqual(result["boost.ut"], "OFF")
        self.assertEqual(result["GoogleTest"], "OFF")

    def test_explicit_test_dependency(self):
        result = self.configure("-DTARGET_TESTS=OFF", "-DENABLE_BOOST_UT=ON")
        self.assertEqual(result["boost.ut"], "ON")

    def test_group_reconfiguration(self):
        self.configure("-DTARGET_GR_CORE=OFF")
        self.assertEqual(self.configure("-DTARGET_GR_CORE=ON")["vir-simd"], "ON")
        self.assertEqual(self.configure("-DTARGET_GR_CORE=OFF")["vir-simd"], "OFF")

    def test_override_survives_group_changes(self):
        self.assertEqual(self.configure("-DENABLE_VIR_SIMD=OFF")["vir-simd"], "OFF")
        self.configure("-DTARGET_GR_CORE=OFF")
        self.assertEqual(self.configure("-DTARGET_GR_CORE=ON")["vir-simd"], "OFF")

    def test_unset_restores_group_default(self):
        self.configure("-DENABLE_VIR_SIMD=OFF")
        self.assertEqual(self.configure("-UENABLE_VIR_SIMD")["vir-simd"], "ON")

    def test_cache_remains_boolean(self):
        self.configure()
        self.assertIn("ENABLE_VIR_SIMD:BOOL=ON", (self.build / "CMakeCache.txt").read_text())


if __name__ == "__main__":
    unittest.main()

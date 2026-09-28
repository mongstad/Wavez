import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tools.application_version import PROJECT, read_version


class ApplicationVersionTests(unittest.TestCase):
    def test_authoritative_source_and_cli(self):
        value = read_version()
        tool = PROJECT.parents[1] / "tools" / "application_version.py"
        for args, expected in [([], value["full"]), (["--release"], value["release"]), (["--json"], json.dumps(value))]:
            result = subprocess.run([sys.executable, str(tool), *args], capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.strip(), expected)

    def test_metadata_contract(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "project.godot"
            for value in ["v0.1.0.1", "v0.1.1.37", "v1.0.0.1000", "v2.0.0.1001", "v1.0.0.99999999999999999999"]:
                with self.subTest(value=value):
                    path.write_text('config_version=5\n[application]\nconfig/version=' + json.dumps(value) + '\n')
                    self.assertEqual(read_version(path)["full"], value)
                    self.assertEqual(read_version(path)["build"], value.rsplit(".", 1)[1])
            for value in [None, 12, True, [], "", "0.1.0.1", "v1.2.3", "v1.2.3.0", "v1.2.3.-1", "v01.2.3.4", "v1.2.3.04", "v1.2.3.4\n", "v1.2.3.4-dev"]:
                with self.subTest(value=value):
                    path.write_text('[application]\nconfig/version=' + json.dumps(value) + '\n')
                    with self.assertRaisesRegex(ValueError, "application/config/version"):
                        read_version(path)
            for text in ['', '[application]\nconfig/name="SimScope"', '[application]\nconfig/version=broken']:
                path.write_text(text)
                with self.assertRaises(ValueError):
                    read_version(path)
            path.unlink()
            with self.assertRaisesRegex(ValueError, "Cannot read"):
                read_version(path)
            result = subprocess.run([sys.executable, str(PROJECT.parents[1] / "tools/application_version.py"), "--project", str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")
            self.assertIn("application/config/version", result.stderr)

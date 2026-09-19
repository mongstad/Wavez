"""The current validator must not silently claim historical source invariance."""
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.validate_ux2 import historical_source_invariance, source_invariance, source_snapshot


class SourceValidationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git("init", "-q")
        (self.root / "viewer").mkdir()
        self.source = self.root / "viewer/main.gd"
        self.source.write_text("extends Node\n")
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-qm", "fixture")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True)

    def test_current_snapshot_accepts_unchanged_source(self):
        self.assertEqual(source_invariance(source_snapshot(self.root), self.root)["status"], "PASS")

    def test_current_snapshot_detects_modified_removed_and_added_source(self):
        for change in ("modify", "remove", "add"):
            with self.subTest(change=change):
                self.source.write_text("extends Node\n")
                added = self.root / "viewer/new.gd"
                added.unlink(missing_ok=True)
                before = source_snapshot(self.root)
                if change == "modify":
                    self.source.write_text("extends Node2D\n")
                elif change == "remove":
                    self.source.unlink()
                else:
                    added.write_text("extends Node\n")
                with self.assertRaisesRegex(RuntimeError, "Validation changed source"):
                    source_invariance(before, self.root)

    def test_missing_historical_commit_is_explicit_failure(self):
        with self.assertRaisesRegex(ValueError, "omit --source-baseline"):
            historical_source_invariance("7037f5f", self.root)

    def test_requested_historical_comparison_checks_bytes(self):
        report = historical_source_invariance("HEAD", self.root)
        self.assertEqual(report["baseline"], self.git("rev-parse", "HEAD").strip())
        self.source.write_text("extends Node2D\n")
        with self.assertRaisesRegex(RuntimeError, "differs"):
            historical_source_invariance("HEAD", self.root)


if __name__ == "__main__":
    unittest.main()

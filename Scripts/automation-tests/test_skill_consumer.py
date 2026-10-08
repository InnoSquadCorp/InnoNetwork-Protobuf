"""Exercise the skill validator without Swift, Xcode, or network access."""

from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "skills/innonetwork-protobuf/scripts/validate_consumer.py"
spec = importlib.util.spec_from_file_location("validate_consumer", SCRIPT)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class SkillConsumerTests(unittest.TestCase):
    """Check command limits and persisted evidence across validation outcomes."""

    def validate(self, failure=None, exit_code=0):
        """Simulate the exact remote graph and optionally fail a labeled command."""
        expected = json.loads((SCRIPT.parents[1] / "references/support.json").read_text())["resolved_dependencies"]
        with tempfile.TemporaryDirectory() as directory:
            scratch = Path(directory).resolve()

            def run(argv, *, stdout, stderr, check, timeout):
                """Write deterministic command output with no external processes."""
                label = Path(stdout.name).stem
                self.assertEqual(stderr, subprocess.STDOUT)
                self.assertFalse(check)
                self.assertGreater(timeout, 0)
                if label == failure:
                    stdout.write("partial command output\n")
                    if exit_code:
                        return subprocess.CompletedProcess(argv, exit_code)
                    raise subprocess.TimeoutExpired(argv, timeout)
                if label == "resolve":
                    dependencies = [
                        {"packageRef": {"identity": identity, "kind": "remoteSourceControl",
                                        "location": pin["repository"]},
                         "state": {"name": "sourceControlCheckout",
                                   "checkoutState": {key: pin[key] for key in ("version", "revision") if key in pin}},
                         "subpath": identity}
                        for identity, pin in expected.items()
                    ]
                    (scratch / "workspace-state.json").write_text(json.dumps({"object": {"dependencies": dependencies}}))
                elif label == "graph":
                    stdout.write(json.dumps({"identity": "consumer", "dependencies": [
                        {"identity": identity, "url": pin["repository"], "version": pin.get("version", "unspecified"),
                         "path": str(scratch / "checkouts" / identity)}
                        for identity, pin in expected.items()
                    ]}))
                elif label.endswith("-head"):
                    stdout.write(expected[Path(argv[2]).name]["revision"])
                elif label == "swift-test":
                    stdout.write("Test run with 14 tests in 1 suite passed")
                return subprocess.CompletedProcess(argv, 0)

            output = io.StringIO()
            with patch.object(sys, "argv", [str(SCRIPT), "--scratch-path", str(scratch)]), \
                    patch.object(sys, "platform", "darwin"), \
                    patch.dict(os.environ, {"INNONETWORK_LOCAL_PATH": ""}), \
                    patch.object(validator.subprocess, "run", side_effect=run), redirect_stdout(output):
                result = validator.main()
            summary = json.loads(output.getvalue())
            evidence = json.loads(Path(summary["evidence"]).read_text())
            logs = {Path(entry["log"]).stem: Path(entry["log"]).read_text() for entry in evidence["commands"]}
            self.assertIn("finished_at", evidence)
            self.assertEqual(summary["status"], evidence["status"])
            return result, evidence, logs

    def test_success_records_every_command_limit(self):
        """Every external command has a finite, recorded time budget."""
        result, evidence, _ = self.validate()
        self.assertEqual(result, 0)
        self.assertEqual(evidence["status"], "passed")
        for entry in evidence["commands"]:
            label = Path(entry["log"]).stem
            expected = {"resolve": 600, "graph": 120, "swift-test": 1800}.get(label, 60)
            self.assertEqual(entry["timeout_seconds"], expected)
            self.assertEqual(entry["exit_code"], 0)
            self.assertNotIn("timed_out", entry)

    def test_timeout_preserves_failed_evidence_and_partial_log(self):
        """Tool, resolve, graph, Git, and test timeouts fail closed with evidence."""
        for label in ("swift-version", "xcode-version", "resolve", "graph", "innonetwork-head", "swift-test"):
            with self.subTest(label=label):
                result, evidence, logs = self.validate(failure=label)
                self.assertEqual(result, 1)
                self.assertEqual(evidence["status"], "failed")
                command = evidence["commands"][-1]
                self.assertEqual(Path(command["log"]).stem, label)
                self.assertTrue(command["timed_out"])
                self.assertIsNone(command["exit_code"])
                self.assertIn(f"{label} timed out after {command['timeout_seconds']} seconds", evidence["error"])
                self.assertIn("partial command output", logs[label])
                self.assertIn(evidence["error"], logs[label])
                self.assertNotIn("swift_test_result", evidence)

    def test_nonzero_exit_still_records_failure(self):
        """Ordinary command failures retain their actual exit status."""
        result, evidence, _ = self.validate(failure="resolve", exit_code=42)
        self.assertEqual(result, 1)
        self.assertEqual(evidence["status"], "failed")
        self.assertEqual(evidence["commands"][-1]["exit_code"], 42)
        self.assertNotIn("timed_out", evidence["commands"][-1])
        self.assertIn("resolve failed (42)", evidence["error"])


if __name__ == "__main__":
    unittest.main()

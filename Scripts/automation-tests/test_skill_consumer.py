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

    def validate(self, failure=None, exit_code=0, release=False, tag_case="valid", release_tag="6.1.1"):
        """Simulate the exact remote graph and optionally fail a labeled command."""
        expected = json.loads((SCRIPT.parents[1] / "references/support.json").read_text())["resolved_dependencies"]
        baseline_bytes = (SCRIPT.parents[1] / "assets/consumer/Package.resolved").read_bytes()
        if release:
            expected["innonetwork-protobuf"]["revision"] = "a" * 40
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
                if label.startswith("release-tag-"):
                    ref = "refs/tags/" + release_tag
                    obj = "b" * 40
                    revision = "a" * 40
                    if tag_case == "wrong-commit": revision = "c" * 40
                    if tag_case == "wrong-object" or (tag_case == "moved" and label.endswith("after")): obj = "c" * 40
                    if tag_case == "missing": return subprocess.CompletedProcess(argv, 0)
                    stdout.write(obj + "\t" + ref + "\n")
                    if tag_case != "lightweight": stdout.write(revision + "\t" + ref + "^{}\n")
                elif label == "resolve":
                    if tag_case == "normalize-lock":
                        package = Path(argv[argv.index("--package-path") + 1])
                        lock_path = package / "Package.resolved"
                        lock_path.write_text(json.dumps(json.loads(lock_path.read_text()), sort_keys=True, separators=(",", ":")))
                    if tag_case == "resolve-drift":
                        package = Path(argv[argv.index("--package-path") + 1])
                        lock_path = package / "Package.resolved"
                        lock = json.loads(lock_path.read_text())
                        lock["pins"][0]["state"]["revision"] = "c" * 40
                        lock_path.write_text(json.dumps(lock))
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
            argv = [str(SCRIPT), "--scratch-path", str(scratch)]
            if release:
                argv += ["--release-tag", release_tag, "--expected-adapter-revision", "a" * 40,
                         "--expected-tag-object", "b" * 40]
            with patch.object(sys, "argv", argv), \
                    patch.object(sys, "platform", "darwin"), \
                    patch.dict(os.environ, {"INNONETWORK_LOCAL_PATH": ""}), \
                    patch.object(validator.subprocess, "run", side_effect=run), redirect_stdout(output):
                result = validator.main()
            summary = json.loads(output.getvalue())
            evidence = json.loads(Path(summary["evidence"]).read_text())
            logs = {Path(entry["log"]).stem: Path(entry["log"]).read_text() for entry in evidence["commands"]}
            self.assertIn("finished_at", evidence)
            self.assertEqual(summary["status"], evidence["status"])
            self.assertEqual((SCRIPT.parents[1] / "assets/consumer/Package.resolved").read_bytes(), baseline_bytes)
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



    def test_release_uses_verified_remote_identity_and_preserves_history(self):
        result, evidence, logs = self.validate(release=True)
        self.assertEqual(result, 0)
        self.assertEqual(evidence["historical_baseline"]["revision"], "5e5f8316c94358235c3997e70e5e97aadc11df3a")
        self.assertEqual(evidence["dependencies"]["innonetwork-protobuf"]["revision"], "a" * 40)
        self.assertEqual(evidence["release_identity"]["tag_object"], "b" * 40)
        self.assertIn("release-tag-before", logs)
        self.assertIn("release-tag-after", logs)
        self.assertNotEqual(evidence["source_sha256"]["Package.resolved"], evidence["validation_input_sha256"]["Package.resolved"])

    def test_release_rejects_wrong_missing_lightweight_and_moving_tags(self):
        for case in ["missing", "lightweight", "wrong-commit", "wrong-object", "moved"]:
            with self.subTest(case=case):
                result, evidence, logs = self.validate(release=True, tag_case=case)
                self.assertEqual(result, 1)
                self.assertEqual(evidence["status"], "failed")
                if case != "moved": self.assertNotIn("resolve", logs)
                else: self.assertEqual(Path(evidence["commands"][-1]["log"]).stem, "release-tag-after")

    def test_release_remote_lookup_timeout_is_recorded(self):
        result, evidence, logs = self.validate(release=True, failure="release-tag-before")
        self.assertEqual(result, 1)
        self.assertTrue(evidence["commands"][-1]["timed_out"])
        self.assertNotIn("resolve", logs)

    def test_release_rejects_resolution_drift(self):
        result, evidence, logs = self.validate(release=True, tag_case="resolve-drift")
        self.assertEqual(result, 1)
        self.assertIn("Resolution changed", evidence["error"])
        self.assertNotIn("swift-test", logs)

    def test_release_accepts_semantically_identical_resolved_lock_serialization(self):
        result, evidence, _ = self.validate(release=True, tag_case="normalize-lock")
        self.assertEqual(result, 0)
        self.assertNotEqual(evidence["seed_input_sha256"]["Package.resolved"], evidence["validation_input_sha256"]["Package.resolved"])

    def test_release_preserves_exact_prefixed_tag_identity(self):
        result, evidence, _ = self.validate(release=True, release_tag="v6.1.1")
        self.assertEqual(result, 0)
        self.assertEqual(evidence["release_identity"]["tag"], "v6.1.1")
        self.assertIn("refs/tags/v6.1.1", evidence["commands"][0]["argv"])

if __name__ == '__main__':
    unittest.main()

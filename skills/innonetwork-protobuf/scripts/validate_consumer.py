#!/usr/bin/env python3
"""Validate an isolated exact-revision consumer and record reproducible evidence."""

import argparse
import copy
from contextlib import ExitStack
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    """Validate the pinned consumer and persist evidence for success or failure."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scratch-path", type=Path, help="External SwiftPM cache and logs, retained after the run")
    parser.add_argument("--release-tag", help="Validate this current annotated release tag")
    parser.add_argument("--expected-adapter-revision", help="Reviewed commit bound by release identity validation")
    parser.add_argument("--expected-tag-object", help="Annotated tag object bound by release identity validation")
    args = parser.parse_args()
    release_values = (args.release_tag, args.expected_adapter_revision, args.expected_tag_object)
    if any(release_values) and not all(release_values):
        parser.error("Release mode requires tag, expected adapter revision and expected tag object together")
    skill = Path(__file__).resolve().parents[1]
    scratch = (args.scratch_path or Path(tempfile.mkdtemp(prefix="innonetwork-protobuf-skill-"))).resolve()
    if scratch == skill or skill in scratch.parents:
        parser.error("Choose a scratch directory outside the installed skill")
    runs = scratch / "skill-runs"
    runs.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="run-", dir=runs))
    evidence_file = run / "evidence.json"
    evidence = {"status": "running", "started_at": datetime.now(timezone.utc).isoformat(), "commands": []}

    def check(condition, message):
        """Stop validation when a required contract does not hold."""
        if not condition:
            raise RuntimeError(message)

    def command(label, argv, timeout=60, structured_output=False):
        """Run a bounded command, retaining its output and failure evidence."""
        log = run / (label + ".log")
        entry = {"argv": [str(a) for a in argv], "log": str(log), "timeout_seconds": timeout}
        evidence["commands"].append(entry)
        with log.open("w") as output, ExitStack() as stack:
            error_output = subprocess.STDOUT
            if structured_output:
                error_log = run / (label + ".stderr.log")
                entry["stderr_log"] = str(error_log)
                error_output = stack.enter_context(error_log.open("w"))
            try:
                result = subprocess.run(entry["argv"], stdout=output, stderr=error_output,
                                        check=False, timeout=timeout)
            except subprocess.TimeoutExpired as error:
                entry.update(exit_code=None, timed_out=True)
                message = f"{label} timed out after {timeout} seconds; see {log}"
                output.write(f"\n{message}\n")
                raise RuntimeError(message) from error
        entry["exit_code"] = result.returncode
        check(result.returncode == 0, f"{label} failed ({result.returncode}); see {log}")
        return log.read_text(errors="replace").strip()

    def flatten(node):
        """Yield each node in SwiftPM's dependency graph."""
        yield node
        for child in node.get("dependencies", []):
            yield from flatten(child)

    def pins(path):
        """Index the lockfile's pins by package identity."""
        return {p["identity"]: p for p in json.loads(path.read_text())["pins"]}

    try:
        check(sys.platform == "darwin", "The fixture requires an Apple Swift development host")
        check(not os.environ.get("INNONETWORK_LOCAL_PATH"), "Unset INNONETWORK_LOCAL_PATH for exact remote validation")
        support = json.loads((skill / "references/support.json").read_text())
        evidence["supported_range"] = support["supported_range"]
        evidence["include_prereleases"] = support["include_prereleases"]
        evidence["validation_scope"] = support["baseline_kind"]
        expected = copy.deepcopy(support["resolved_dependencies"])
        evidence["historical_baseline"] = {k: support[k] for k in ("version", "revision", "tag_object") }
        check(expected["innonetwork-protobuf"] == {k: support[k] for k in ("repository", "version", "revision")},
              "Library support and dependency record disagree")
        source = skill / "assets/consumer"
        original_pins = pins(source / "Package.resolved")
        check(set(original_pins) == set(expected), "Fixture lock and supported graph differ")
        for identity, baseline in expected.items():
            pin = original_pins[identity]
            check(pin["kind"] == "remoteSourceControl" and pin["location"] == baseline["repository"]
                  and pin["state"] == {k: baseline[k] for k in ("version", "revision") if k in baseline},
                  f"{identity} fixture pin differs from support record")
        release_identity = None
        if args.release_tag:
            release_version = args.release_tag[1:] if args.release_tag.startswith("v") else args.release_tag
            check(release_version == support["version"], "Release mode must use the fixture's exact adapter version")
            check(all(re.fullmatch(r"[0-9a-f]{40}", value) for value in
                      (args.expected_adapter_revision, args.expected_tag_object)), "Expected identities must be exact SHAs")

            def remote_identity(label):
                repository = "https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git"
                check(support["repository"] == repository, "Unexpected adapter repository")
                ref = "refs/tags/" + args.release_tag
                output = command(label, ["git", "ls-remote", repository, ref, ref + "^{}"])
                entries = [line.split() for line in output.splitlines()]
                check(len(entries) == 2 and all(len(row) == 2 and re.fullmatch(r"[0-9a-f]{40}", row[0]) for row in entries),
                      "An existing annotated remote tag and peeled commit are required")
                refs = {name: sha for sha, name in entries}
                check(set(refs) == {ref, ref + "^{}"}, "Unexpected remote tag identity")
                check(refs[ref] == args.expected_tag_object and refs[ref + "^{}"] == args.expected_adapter_revision,
                      "Official annotated tag differs from reviewed release identity")
                return {"tag": args.release_tag, "tag_object": refs[ref], "revision": refs[ref + "^{}"]}

            release_identity = remote_identity("release-tag-before")
            evidence["release_identity"] = release_identity
            evidence["validation_scope"] = "current_annotated_release_tag"
            expected["innonetwork-protobuf"]["revision"] = release_identity["revision"]
            original_pins["innonetwork-protobuf"]["state"]["revision"] = release_identity["revision"]
        evidence["swift"] = command("swift-version", ["swift", "--version"])
        evidence["xcode"] = command("xcode-version", ["xcodebuild", "-version"])
        evidence["source_sha256"] = {
            str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(source.rglob("*")) if p.is_file() and p.suffix in (".swift", ".resolved")
            and not {".build", ".swiftpm"}.intersection(p.relative_to(source).parts)
        }
        package = run / "consumer"
        shutil.copytree(source, package, ignore=shutil.ignore_patterns(".build", ".swiftpm", ".DS_Store"))
        if release_identity:
            lock_path = package / "Package.resolved"
            lock = json.loads(lock_path.read_text())
            for pin in lock["pins"]:
                if pin["identity"] == "innonetwork-protobuf":
                    pin["state"]["revision"] = release_identity["revision"]
            lock_path.write_text(json.dumps(lock, indent=2) + "\n")
        # A release seed changes only in the isolated copy; source evidence remains historical.
        evidence["seed_input_sha256"] = {
            relative: hashlib.sha256((package / relative).read_bytes()).hexdigest()
            for relative in evidence["source_sha256"]
        }
        options = ["--package-path", package, "--scratch-path", scratch]
        command("resolve", ["swift", "package", *options, "resolve"], timeout=600)
        check(pins(package / "Package.resolved") == original_pins, "Resolution changed the fixture's exact pins")
        evidence["validation_input_sha256"] = {
            relative: hashlib.sha256((package / relative).read_bytes()).hexdigest()
            for relative in evidence["source_sha256"]
        }
        for relative, digest in evidence["seed_input_sha256"].items():
            if relative != "Package.resolved":
                check(evidence["validation_input_sha256"][relative] == digest,
                      f"Resolution changed consumer source: {relative}")
        graph = json.loads(command("graph", ["swift", "package", *options, "show-dependencies", "--format", "json"], timeout=120, structured_output=True))
        nodes = {n["identity"]: n for n in flatten(graph)}
        # SwiftPM can omit SwiftSyntax from show-dependencies when using a prebuilt.
        # Verify its resolved checkout through workspace state instead of ignoring it.
        workspace = json.loads((scratch / "workspace-state.json").read_text())["object"]
        resolved = {d["packageRef"]["identity"]: d for d in workspace["dependencies"]}
        check(set(resolved) == set(expected), "Unexpected resolved workspace dependencies")
        prebuilts = {p["identity"]: p for p in workspace.get("prebuilts", [])}
        active = set(nodes) - {graph["identity"]}
        check(active <= set(expected) and set(expected) - active <= set(prebuilts),
              "Unexpected active dependency graph")
        evidence["dependencies"] = {}
        for identity, baseline in expected.items():
            dependency = resolved[identity]
            ref, state = dependency["packageRef"], dependency["state"]
            check(ref["kind"] == "remoteSourceControl" and ref["location"] == baseline["repository"]
                  and dependency.get("basedOn") is None and state["name"] == "sourceControlCheckout"
                  and {k: v for k, v in state["checkoutState"].items() if v is not None} == {k: baseline[k] for k in ("version", "revision") if k in baseline},
                  f"{identity} workspace differs from baseline lock")
            checkout = (scratch / "checkouts" / dependency["subpath"]).resolve()
            check((scratch / "checkouts").resolve() in checkout.parents, f"{identity} uses a local override")
            if identity in nodes:
                node = nodes[identity]
                check(node["url"] == baseline["repository"] and node["version"] == baseline.get("version", "unspecified")
                      and Path(node["path"]).resolve() == checkout,
                      f"{identity} active graph differs from baseline lock")
            if identity in prebuilts:
                prebuilt = prebuilts[identity]
                check(identity == "swift-syntax" and prebuilt["version"] == baseline["version"]
                      and Path(prebuilt["checkoutPath"]).resolve() == checkout
                      and (scratch / "prebuilts").resolve() in Path(prebuilt["path"]).resolve().parents,
                      f"{identity} has an unexpected prebuilt selection")
            revision = command(identity + "-head", ["git", "-C", checkout, "rev-parse", "HEAD"])
            check(revision == baseline["revision"], f"{identity} checkout revision differs from baseline lock")
            check(not command(identity + "-status", ["git", "-C", checkout, "status", "--porcelain", "--untracked-files=all"]),
                  f"{identity} checkout has modifications")
            evidence["dependencies"][identity] = {"version": baseline.get("version"), "revision": revision,
                                                   "clean": True, "prebuilt_selected": identity in prebuilts}
        output = command("swift-test", ["swift", "test", *options, "--jobs", "2", "--no-parallel", "-Xswiftc",
                                         "-strict-concurrency=complete", "-Xswiftc", "-warnings-as-errors"], timeout=1800)
        summaries = re.findall(r"Test run with (\d+) tests? in (\d+) suites? passed", output)
        check(bool(summaries), "Swift Testing passed summary not found; inspect the test log")
        evidence["swift_test_result"] = {"tests": sum(int(x) for x, _ in summaries),
                                         "suites": sum(int(x) for _, x in summaries), "failures": 0,
                                         "strict_concurrency": "complete", "warnings_as_errors": True}
        check(pins(package / "Package.resolved") == original_pins, "Tests changed exact pins")
        for relative, digest in evidence["validation_input_sha256"].items():
            check(hashlib.sha256((package / relative).read_bytes()).hexdigest() == digest,
                  f"Validation changed consumer input: {relative}")
        for identity, dependency in resolved.items():
            checkout = (scratch / "checkouts" / dependency["subpath"]).resolve()
            check(command(identity + "-final-head", ["git", "-C", checkout, "rev-parse", "HEAD"]) == expected[identity]["revision"],
                  f"{identity} revision changed during build")
            check(not command(identity + "-final-status", ["git", "-C", checkout, "status", "--porcelain", "--untracked-files=all"]),
                  f"{identity} changed during build")
        if release_identity:
            check(remote_identity("release-tag-after") == release_identity, "Release tag changed during validation")
        evidence["status"] = "passed"
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        evidence["status"] = "failed"
        evidence["error"] = str(error)
    finally:
        evidence["finished_at"] = datetime.now(timezone.utc).isoformat()
        evidence_file.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"status": evidence["status"], "evidence": str(evidence_file), "error": evidence.get("error")}, indent=2))
    return 0 if evidence["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())

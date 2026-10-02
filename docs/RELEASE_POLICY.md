# Release Policy

## Versioning

- Public releases follow semantic versioning from `3.0.1`.
- Stable API must not break in patch or minor releases.
- Breaking changes require a major version bump and migration guidance.
- The adapter reset is `6.0.0`, requiring the public encoded-request boundary
  planned for core `6.1.0`. Versions need not be numerically identical.

## Release Process

1. Publish and verify the matching InnoNetwork tag first. For the 6.0 line,
   InnoNetwork `6.1.0` must resolve without `INNONETWORK_LOCAL_PATH`.
2. Resolve, build, test, and run both smoke targets without a local override.
3. Update `CHANGELOG.md` and confirm `docs/releases/<version>.md`.
4. Push an annotated tag such as `6.0.0`.
5. Let the `Release` workflow run:
   - `swift test`
   - docs contract sync
   - doc smoke build/run
   - consumer smoke build/run against the local adapter and remote core
   - No publication on tag push or default manual validation.
6. After exact-SHA validation, run the workflow on the existing annotated tag
   with the same version and explicit `publish: true`. The tag must belong to
   reviewed main, and committed notes must say `Release-Status: Ready`.
   Publication is a separate write-permission job under the release environment;
   configure required environment reviewers before enabling production use.
7. After publication, resolve both remote tags from a clean external consumer
   and verify the resolved revisions. The pre-tag local-adapter fixture is not
   a substitute for this post-publication check.

Local compatibility evidence is recorded in [COMPATIBILITY_6_0.md](COMPATIBILITY_6_0.md).
Passing it does not authorize a push, tag, workflow dispatch or publication.

## Support Posture

- Release quality is expected for Stable API.
- Response time remains best-effort under the lightweight maintainer model.

# Deployment plan local progress

> Historical record — retained for the source, date and environment below.
> For the published 6.1.1 contract, use the [current quick start](../README.md)
> and [documentation map](README.md). Unexecuted checks are not implied passes.


Baseline: 4976e729b3c2cd47e13fbab55584972d203881e1. Core remains exact 6.1.1.

| Plan item | Local implementation | Evidence | Still required |
| --- | --- | --- | --- |
| A1 error assertion | 0xff -> malformedMessage; separate truncated case | Reviewed SwiftProtobuf 1.38.1 source; fixture-shape guard | Actual Swift domain/code/redaction tests |
| A2 CI repetition | Public matrix owns consumers; retained context checks its success; docs-only compile remains; duplicate resolve removed | Policy/metadata/gate tests, shell negative control, actionlint | Real CI on the final SHA and elapsed-time observation |
| A3 loopback repetition | One ValidationSupport package shared by both sample consumers | Single-source/dependency-boundary guards | SwiftPM resolution, macro-off graph and socket run |
| A4 factory/options repetition | Private assembly owner and one factory encoding validation | Source ownership guards, public API ledger unchanged | Nil/zero-byte/optional overload compile and behavior |
| A5 repeated Set | One local Set reused | Source guard | Existing MIME runtime regression suite |

Executed: Python 41 tests; static Core 23, dependency 34, public pin 8, workflow 12;
release/Git/docs fixtures; actionlint 1.7.12 with exact existing queue exception;
shell/Ruby syntax; Git whitespace checks. Fake-tool orchestration tests do not
compile or execute Swift.

Next: B1 actual Xcode 26/27 compile/resolve/test. Swift and xcrun are absent from
this VM. No new installation, Mac task, remote push/PR/merge/tag/release has been
performed. Further code should follow actual compiler/runtime evidence rather
than expanding functionality while execution remains unverified.

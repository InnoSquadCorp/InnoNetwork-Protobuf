# Security Policy

## Reporting a Vulnerability

- Do not open public issues for security reports.
- Prefer GitHub private vulnerability reporting if it is enabled for this repository.
- If private reporting is not available, contact the maintainers directly before public disclosure.

Include:

- affected module and version
- reproduction steps
- expected impact
- proof-of-concept or logs if available

## Supported Versions

- Stable 6.1.1 is published; the latest 6.x is the primary supported line. Critical 3.x reports remain triaged on a best-effort basis; no routine 3.x feature backports are promised.
- Codec byte budgets do not bound intermediate encoder allocations. Do not log message bodies or credential-bearing codec errors. Select server-specific request, response and nesting limits.

## Disclosure

- We will validate the report, assess impact, and coordinate a fix before public disclosure.
- Release notes will identify security-relevant fixes when it is safe to do so.

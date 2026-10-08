# Library-owned AI skill

[`innonetwork-protobuf`](innonetwork-protobuf/SKILL.md) is the canonical skill for
implementing and testing Protocol Buffers over HTTP with this library. It targets
stable 6.1.x and validates the exact 6.1.1 adapter/Core pair. The full directory
contains portable instructions, references, discovery metadata, an exact-tag
consumer, a validation helper and the source license notice.

Copy the complete `innonetwork-protobuf` directory to `.agents/skills/` for Codex
or `.claude/skills/` for Claude Code. Preserve its resources; compare an existing
destination before replacement. Standalone invocation is
`$innonetwork-protobuf` or `/innonetwork-protobuf` respectively. Normal implicit
selection is enabled.

The central [innosquad-agent-skills](https://github.com/InnoSquadCorp/innosquad-agent-skills)
repository assembles exact source snapshots into native Codex/Claude plugins.
Library API guidance is authored here; plugin metadata, distribution and actual
host evaluation belong there. A source PR is not a published plugin or a change
to an existing library tag. See [validation](validation.md) for local evidence.

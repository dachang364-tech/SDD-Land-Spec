---
name: doctor
description: Diagnose SDD plugin installation and project consistency. Use for /sdd:doctor.
---

# /sdd:doctor

Diagnose plugin installation integrity and minimum project consistency.

## Plugin installation checks

Check existence of:

```text
.claude-plugin/plugin.json
skills/init/SKILL.md
skills/new/SKILL.md
skills/research/SKILL.md
skills/prd/SKILL.md
skills/spec/SKILL.md
skills/plan/SKILL.md
skills/code/SKILL.md
skills/dr/SKILL.md
skills/status/SKILL.md
skills/doctor/SKILL.md
skills/archive/SKILL.md
hooks/hooks.json
scripts/install-deps.sh
scripts/hooks/pre-tool-use.sh
CONSTITUTION.default.md
```

Check dependency reachability:

```text
superpowers
spec-kit
```

## Project consistency checks

1. Whether `docs/CONSTITUTION.md` exists.
2. Whether there is exactly one active version.
3. Whether status lines are parseable.
4. Whether status values are legal.
5. Whether closed DRs have `closed_reason`.
6. Whether accepted code-class DRs have matching plans after removing `NNN-` prefix.
7. Whether done code-class DR plan corresponding DR is still accepted.
8. Report: `done 的代码类 DR plan 对应 DR 是否仍 accepted`.

## Non-goals

Do not inspect git log.
Do not audit source-code changes.
Do not machine-parse `docs/CONSTITUTION.md` must/should rules.

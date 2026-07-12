# SDD Plugin

SDD Plugin provides an MVP Specification Driven Development workflow for Claude Code.

## Install

From this repository root:

```bash
scripts/install-deps.sh
```

Then install the plugin with Claude Code's plugin installation flow for a local plugin directory.

## Commands

- `/sdd:init`
- `/sdd:new vX.Y.Z`
- `/sdd:research <topic>`
- `/sdd:prd`
- `/sdd:spec`
- `/sdd:plan <work-item>`
- `/sdd:code <NNN|work-item>`
- `/sdd:dr <tag> <title>`
- `/sdd:dr accept <id>`
- `/sdd:dr dismiss <id> <reason>`
- `/sdd:status`
- `/sdd:doctor`
- `/sdd:archive`

## Main Workflow

```text
/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive
```

## Code Change Workflow

```text
/sdd:dr fix|feat|chg|arch <title> → /sdd:dr accept <id> → /sdd:plan <id> → /sdd:code <NNN|id>
```

## Document Change Workflow

```text
/sdd:dr spec|doc|typo <title> → /sdd:dr accept <id> → /sdd:spec → DR closed
```

## Verification

```bash
bash tests/test-doctor-contract.sh && bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

Expected output:

```text
PASS: skeleton contract
PASS: common library
PASS: pre-tool-use hook
PASS: skill contracts
PASS: MVP acceptance
```

## MVP Non-Goals

- No `.sdd/state.json`.
- No multi-active-version support.
- No `src/**` hook gate.
- No machine parsing of `docs/CONSTITUTION.md` must/should rules.
- No git log CONFORMANCE scan.
- No PostToolUse progress accounting.
- No PreCompact state persistence.
- No automatic modification of `CLAUDE.md` or `AGENTS.md`.

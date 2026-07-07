# SDD CodeAgent Plugin — Design

- **Date**: 2026-07-07
- **Status**: Approved (brainstorming complete)
- **Owner**: Dachang (@dachang364-tech)
- **Repository**: `SDD-Land-Spec` (root of this repo)

## 1. Purpose & Context

Build a CodeAgent plugin (manifest-based) that encapsulates the author's
spec-driven development (SDD) workflow as a set of Skills, Commands, Hooks,
and runtime state. The plugin is a **process orchestrator**, not a
methodology re-implementation: it composes the best parts of existing
frameworks (Superpowers, Spec-Kit, OpenSpec) and glues them together with
project-local conventions.

### Goals

- Drive projects from **requirement → shipped & archived** via a small set
  of explicit slash commands and natural-language triggers.
- Treat documentation (`spec.md`, `trd.md`, `feature plans`, `ADRs`) as
  first-class artifacts under `docs/vX.Y.Z/`.
- Enforce a **TRD-bounded** guard rail: code that does not violate the
  current version's `trd.md` coverage scope is allowed freely (Superpowers
  TDD takes over); code that steps out of scope is **hard-blocked** at the
  write hook.
- Run on **Claude Code** first, with explicit adapter layers for OpenCode,
  CodeX, and other CodeAgents later.

### Non-Goals

- Re-implement brainstorming, TDD, or verification — those are
  consumed from Superpowers.
- Re-implement spec / plan / tasks templates from scratch — those are
  borrowed from Spec-Kit (and customised minimally).
- Build a cross-platform runtime abstraction. Each platform gets its own
  thin adapter directory.

## 2. Architecture Overview

```
┌────────────────────────────────────────────────────────────┐
│            SDD CodeAgent Plugin (manifest-based)            │
├────────────────────────────────────────────────────────────┤
│  Commands (thin aliases into Skills)                        │
│   /sdd.init /sdd.new /sdd.spec /sdd.trd                    │
│   /sdd.feature /sdd.code /sdd.bugfix /sdd.adr              │
│   /sdd.status /sdd.archive                                 │
├────────────────────────────────────────────────────────────┤
│  Skills (the actual methodology)                            │
│   sdd-init / sdd-new-version                               │
│   sdd-spec-writer / sdd-trd-writer                         │
│   sdd-feature-planner / sdd-code-orchestrator              │
│   sdd-bugfix-triage / sdd-adr-writer                       │
│   sdd-status-reader / sdd-archiver                         │
├────────────────────────────────────────────────────────────┤
│  Hooks (path / state guards)                                │
│   SessionStart        — inject project state into context  │
│   PreToolUse Write/Edit  — enforce TRD coverage            │
│   PostToolUse Write/Edit — bump state.json timestamps       │
│   PreCompact          — snapshot current phase artifacts   │
├────────────────────────────────────────────────────────────┤
│  State (.sdd/state.json)                                    │
│   version, phase, branch, artifacts, guards, adr_pending    │
└────────────────────────────────────────────────────────────┘
           ↓ consumes ↓
┌────────────────────────────────────────────────────────────┐
│  External frameworks (not re-implemented)                   │
│   Superpowers: brainstorming / writing-plans / TDD /        │
│                verification-before-completion /             │
│                subagent-driven-development                  │
│   Spec-Kit:    specify / plan / tasks / converge templates  │
│   OpenSpec:    archive / change-management model            │
└────────────────────────────────────────────────────────────┘
```

## 3. State Machine

```
NONE ──/sdd.init──▶ INITED ──/sdd.new vX.Y.Z──▶ SPEC
                                                 │
                                                 ▼
                                               TRD
                                                 │
                                                 ▼
                                       (per feature)
                                          FEATURE_PLAN ──/sdd.code──▶ CODE
                                                                      │
                                                                      │ /sdd.bugfix
                                                                      ▼
                                                                  BUGFIX ──▶ CODE
                                                                      │
                                                                      ▼
                                                                  RELEASE
                                                                      │ /sdd.archive
                                                                      ▼
                                                                  ARCHIVED
```

Phases can be re-entered (e.g. editing `spec.md` from `TRD` phase writes a
new revision without resetting downstream artifacts). `state.json.phase`
records the highest reached phase; the relevant artifact statuses live
in `state.json.artifacts.<name>.status`.

### 3.1 `.sdd/state.json` schema

```json
{
  "version": "1.0.1",
  "phase": "TRD",
  "branch": "feat/v1.0.1-payment",
  "artifacts": {
    "spec":  { "path": "docs/v1.0.1/specs/spec.md",  "status": "approved", "updated_at": "2026-07-07T10:00:00Z" },
    "trd":   { "path": "docs/v1.0.1/plans/trd.md",   "status": "draft",    "updated_at": "2026-07-07T11:00:00Z" },
    "features": [
      { "name": "feature-login",  "path": "docs/v1.0.1/plans/feature-login.md",  "status": "planned" },
      { "name": "feature-payment","path": "docs/v1.0.1/plans/feature-payment.md","status": "coding" }
    ],
    "adrs": [
      { "id": "0001-use-postgresql", "path": "docs/v1.0.1/decisions/0001-use-postgresql.md", "status": "accepted" }
    ]
  },
  "guards": {
    "trd_covered_modules": ["src/payment/**", "src/checkout/**"],
    "code_writes_outside_covered": "block"
  },
  "compaction_snapshot": null
}
```

## 4. Directory Layout

```
<project root>/
├── .sdd/
│   └── state.json
├── docs/
│   ├── vX.Y.Z/                         # current in-flight version
│   │   ├── specs/
│   │   │   └── spec.md                 # pure requirements (Spec-Kit style)
│   │   ├── plans/
│   │   │   ├── trd.md                  # version-level tech design
│   │   │   ├── feature-login.md        # per-feature impl plan
│   │   │   └── feature-payment.md
│   │   └── decisions/
│   │       ├── 0001-use-postgresql.md  # ADR
│   │       └── bugfix-0002-fix-null.md # bugfix record (lightweight ADR)
│   └── archive/
│       └── v1.0.0/                     # archived snapshot
│           ├── specs/spec.md
│           ├── plans/
│           └── decisions/
└── (source code, untouched)
```

## 5. Commands & Skill Mapping

| Command          | Internal Skill                | Writes to                                            | Pre-req                |
| ---------------- | ----------------------------- | ---------------------------------------------------- | ---------------------- |
| `/sdd.init`      | `sdd-init`                    | `.sdd/`, `docs/`                                     | —                      |
| `/sdd.new vX.Y.Z`| `sdd-new-version`             | `docs/vX.Y.Z/{specs,plans,decisions}/`, `state.json`| project initialised    |
| `/sdd.spec`      | `sdd-spec-writer`             | `docs/vX.Y.Z/specs/spec.md`                          | phase ≥ INITED         |
| `/sdd.trd`       | `sdd-trd-writer`              | `docs/vX.Y.Z/plans/trd.md` + `state.json.guards`     | spec approved          |
| `/sdd.feature X` | `sdd-feature-planner`         | `docs/vX.Y.Z/plans/feature-X.md`                     | trd approved           |
| `/sdd.code X`    | `sdd-code-orchestrator`       | source files (via subagent + TDD)                    | `feature-X.md` exists  |
| `/sdd.bugfix`    | `sdd-bugfix-triage`           | `decisions/bugfix-*.md` + code                       | phase = CODE           |
| `/sdd.adr`       | `sdd-adr-writer`              | `docs/vX.Y.Z/decisions/NNNN-*.md`                    | —                      |
| `/sdd.status`    | `sdd-status-reader`           | (none)                                               | —                      |
| `/sdd.archive`   | `sdd-archiver`                | `docs/archive/vX.Y.Z/`                               | phase = RELEASE        |

Every Skill is also reachable through natural language: the Skill's
`description` field is written to match likely user phrasings, so a user
who says "write the spec for the payment feature" reaches
`sdd-spec-writer` without typing a slash command.

## 6. Stage-by-Stage Framework Composition

| Stage              | Plugin Skill           | External framework layer                              |
| ------------------ | ---------------------- | ----------------------------------------------------- |
| Requirements       | `sdd-spec-writer`      | Superpowers `brainstorming` flow + Spec-Kit spec.md   |
|                    |                        | template (User Story, Given-When-Then)                |
| Tech design (TRD)  | `sdd-trd-writer`       | Spec-Kit `plan.md` template (Technical Context,       |
|                    |                        | Constitution Check, Coverage Scope)                   |
| Feature plan       | `sdd-feature-planner`  | Superpowers `writing-plans` flow (file-level tasks,   |
|                    |                        | TDD steps, commit granularity)                        |
| Coding             | `sdd-code-orchestrator`| Superpowers `subagent-driven-development` +           |
|                    |                        | `test-driven-development` + `verification-before-     |
|                    |                        | completion`                                           |
| Bugfix             | `sdd-bugfix-triage`    | Plugin decision tree (see §7.2)                       |
| ADR                | `sdd-adr-writer`       | (plugin-native; follows MADR-style template)          |
| Status             | `sdd-status-reader`    | (plugin-native)                                       |
| Archive            | `sdd-archiver`         | Spec-Kit `/speckit.converge` for gap check +          |
|                    |                        | OpenSpec archive model for layout                     |

## 7. Key Skills — Internal Behaviour

### 7.1 `sdd-spec-writer`

1. Read `state.json`. Refuse if `phase < INITED`.
2. Invoke **Superpowers `brainstorming`** flow: ask one clarifying
   question at a time, max 5.
3. Fill Spec-Kit `spec-template.md` skeleton: User Stories (P1/P2/P3),
   Acceptance Scenarios (Given-When-Then).
4. Write `docs/vX.Y.Z/specs/spec.md`.
5. Update `state.json.artifacts.spec.status = draft`.
6. **Hard gate**: do not advance `phase` until user explicitly approves
   the spec. Approval bumps `status = approved` and `phase = TRD`.

### 7.2 `sdd-trd-writer`

1. Read spec.md; refuse if not approved.
2. Invoke **Superpowers `writing-plans`** flow to collect technical
   decisions (one question at a time).
3. Populate Spec-Kit `plan-template.md` skeleton (Technical Context,
   Constitution Check, Project Structure, Coverage Scope).
4. **Mandatory** section: `## Coverage Scope` listing file globs
   this version is allowed to modify.
5. Persist parsed globs to `state.json.guards.trd_covered_modules`.
6. On approval, `phase = FEATURE_PLAN` is reached once at least one
   feature plan exists.

### 7.3 `sdd-feature-planner`

1. Read trd.md; refuse if not approved.
2. Invoke **Superpowers `writing-plans`** full flow for the named
   feature.
3. Produce `docs/vX.Y.Z/plans/feature-<name>.md` with sections:
   - File structure (precise files to touch)
   - Task list `[ID] [P?] [Story] <description with file paths>`
   - TDD steps per task (test → fail → impl → pass → commit)
   - Commit granularity suggestions
4. **No separate `tasks.md` is created** — tasks live inside the plan
   document, per Superpowers convention.
5. On user approval, mark `artifacts.features[name].status = planned`.

### 7.4 `sdd-code-orchestrator`

1. Confirm `feature-<name>.md` exists and is approved.
2. Invoke **Superpowers `subagent-driven-development`**: dispatch the
   plan to a subagent.
3. Subagent loop:
   - For each task: write failing test → implement → pass → commit.
   - Before each commit: invoke `verification-before-completion`.
4. **PreToolUse hook** checks every `Write/Edit` against
   `state.json.guards.trd_covered_modules`. Writes outside scope are
   refused with exit code 2.
5. On task completion, mark `artifacts.features[name].status = coding`
   → `done`.

### 7.5 `sdd-bugfix-triage`

Decision tree (executed by Skill body, not by user):

```
Q1: Does the fix change spec-defined behaviour or acceptance criteria?
    Yes → Spec bug → offer ADR
    No  → Code bug → lightweight bugfix record

Q2 (if spec bug): does the fix change TRD coverage scope?
    Yes → update trd.md first
    No  → spec.md diff only
```

Outcomes:

- **Code bug (lightweight)**
  - Write `docs/vX.Y.Z/decisions/bugfix-NNNN-<title>.md` (MADR-style
    but with a Symptom / Root Cause / Fix / Impact layout).
  - Apply code fix via TDD loop; append the task to the relevant
    feature plan's task list.
- **Spec bug (full)**
  - Create ADR `000N-<title>.md`.
  - Update `spec.md` with an explicit `[CHANGED]` diff block.
  - If coverage scope shifts, update `trd.md` and re-parse
    `state.json.guards.trd_covered_modules`.
  - Continue through `/sdd.code` for the affected feature.

### 7.6 `sdd-adr-writer`

Native to plugin. Template:

```md
# ADR NNNN: <Title>

- Status: proposed | accepted | deprecated
- Date: YYYY-MM-DD
- Context: <forces at play>
- Decision: <what we chose>
- Consequences: <positive, negative, follow-ups>
```

### 7.7 `sdd-archiver`

1. Require `phase = RELEASE` (set manually by user or via release hook).
2. Invoke Spec-Kit `/speckit.converge` to detect unbuilt work in any
   feature plan; refuse if any task is incomplete unless user
   explicitly confirms archival.
3. Create `docs/archive/vX.Y.Z/`; copy (not move) `spec.md`, all
   `plans/*.md`, all `decisions/*.md` into it.
4. Delete the in-flight `docs/vX.Y.Z/` directory.
5. Mark `state.json.phase = ARCHIVED` and clear `guards`.

### 7.8 `sdd-status-reader`

Reports: current `version`, `phase`, missing artifacts, open
`proposed` ADRs, and the next recommended slash command.

## 8. Hooks

| Hook                      | Trigger                     | Action                                                                |
| ------------------------- | --------------------------- | --------------------------------------------------------------------- |
| `SessionStart`            | Agent start / resume        | Read `state.json`; inject summary `<plugin>active version=...phase=...missing=[...] next=/sdd.<x>` into context (Claude Code `hookSpecificOutput.additionalContext`). |
| `PreToolUse Write/Edit`   | About to write source       | Compare target file path against `state.json.guards.trd_covered_modules`. In scope → allow. Out of scope → exit 2 + message `"<path> is outside vX.Y.Z coverage scope. Update trd.md or run /sdd.spec to extend scope."`. |
| `PostToolUse Write/Edit`  | Source write completed      | Update `state.json.last_modified`; if the file adds a new top-level module, post a hint to add an ADR. |
| `PreCompact`              | Conversation compaction     | Snapshot current phase artifact paths into `state.json.compaction_snapshot`. |

The hooks **do not** second-guess methodology (no quality checks on
spec prose, no TDD enforcement — those live inside Skills). They only
enforce path and state-machine invariants.

## 9. Error Handling

| Failure                              | Surface to user                                                       | Recovery                                                  |
| ------------------------------------ | --------------------------------------------------------------------- | --------------------------------------------------------- |
| `state.json` missing / malformed     | "Project not initialised. Run `/sdd.init`."                           | `/sdd.init`                                               |
| Phase jump (e.g. `/sdd.trd` w/o spec) | Command refuses with reason.                                          | Run pre-req command.                                      |
| `trd.md` missing `## Coverage Scope`  | `/sdd.trd` refuses completion.                                        | Edit `trd.md` to include the section.                      |
| Write outside coverage               | PreToolUse exit 2 with message.                                       | Edit `trd.md` or run `/sdd.spec` to extend.               |
| Archive with open tasks              | `/sdd.archive` refuses + lists unbuilt tasks.                         | Finish or explicitly confirm "archive anyway".            |
| IO / network failure in script       | Surface error, do **not** corrupt `state.json`.                       | Re-run; consider restoring from `compaction_snapshot`.    |

## 10. Testing Strategy

| Layer                          | What is tested                                       | Tooling                                      |
| ------------------------------ | ---------------------------------------------------- | -------------------------------------------- |
| Templates                      | Required sections exist (e.g. `## Coverage Scope`).  | Plain `bash` / `node` snapshot script.       |
| Hook & archive scripts         | Unit-level behaviour.                                | `bats` / `shunit2`.                          |
| Skill behaviour (E2E)          | Mock `state.json`, feed user input, assert outputs.  | Claude Code headless invocation; assert    |
|                                |                                                      | generated files against golden snapshots.   |
| Hook behaviour (integration)   | Prepare a temp repo, drive a Write, assert refused.  | `bats` driving a real agent subprocess.      |
| Cross-platform adapter smoke   | Generate each adapter, run its consumer's loader.   | Manual for v0.1; CI scripts later.           |

**YAGNI**: no abstract platform mock layer; no test coverage targets
beyond the above matrix.

## 11. Platform Adapter Strategy

Source-of-truth content lives in `sources/`. Each platform gets a thin
adapter that re-shapes that content for its expected layout.

```
sources/
├── skills/        (the 10 Skills, one per directory)
├── templates/     (spec / trd / feature-plan / adr / bugfix)
├── hooks/         (session-start, pre-write-guard, post-write-track)
└── scripts/       (init, archive, status)

adapters/
├── claude-code/
│   ├── .claude-plugin/plugin.json
│   ├── commands/                   # thin /sdd.* aliases into Skills
│   └── hooks/hooks.json
├── opencode/
│   └── loadout.json                # OpenCode loadout definition
└── codex/
    └── (CodeX-specific layout)
```

A `build.sh` script in the Plugin root:
1. Copies `sources/skills/` to each adapter's expected location.
2. Generates each platform's manifest / config.
3. Renders `sources/templates/` to `docs/vX.Y.Z/` when a Skill
   actually needs them at runtime.
4. Runs smoke tests.

### 11.1 Versioning of adapters

- v0.1 — Claude Code only.
- v0.2 — OpenCode adapter (validate that loadout model supports the
  required Skills / Hooks; if not, restrict the Plugin's surface for
  that platform).
- v0.3+ — CodeX, Cursor, Copilot CLI as demand warrants.

## 12. Open Questions / Future Work

- **Hook script language**: Claude Code supports both bash and node
  hooks; OpenCode may differ. Decide per adapter rather than picking
  globally.
- **Bugfix auto-classification**: today the Skill body asks the
  decision tree. If users find it too rigid, future revision can add
  a heuristic (file count, LOC, spec surface match) to pre-classify.
- **Multi-version in flight**: design currently assumes one active
  version at a time. If parallel maintenance branches appear, the
  state model will need to key `guards` by `version`.
- **Plugin distribution**: target a public plugin marketplace
  (Claude Code's `claude-plugins-official`, OpenCode's loadout
  registry) once v0.1 stabilises.

## 13. Acceptance Criteria

- v0.1 is considered done when:
  1. The Plugin installs into Claude Code from this repo.
  2. A user can run `/sdd.init` → `/sdd.new v0.0.1` → `/sdd.spec` →
     `/sdd.trd` → `/sdd.feature demo` → `/sdd.code demo` on a
     scratch repo without manual intervention.
  3. Writing a file outside the declared coverage scope is hard-blocked
     with a clear error message.
  4. `/sdd.status` accurately reflects the state at every phase.
  5. `/sdd.archive` moves `v0.0.1/` to `archive/v0.0.1/` and clears
     `state.json.guards`.
- All external framework calls (Superpowers / Spec-Kit / OpenSpec) are
  composed through Skills, never duplicated inside the Plugin.


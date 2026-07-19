# Task 2 Report: Materialize template packs during `/sdd:init` and package them

## What I implemented

- Updated `skills/init/SKILL.md` to require listing selectable template packs, defaulting to `default-backend` when the user does not switch, and fully materializing PRD / Spec / Plan templates and standards into `.sdd/templates/`.
- Updated the `/sdd:init` output contract to report `.sdd/templates/` and retained the no-version-state, no-document-generation, and dependency-prompt constraints.
- Updated `scripts/package-local.sh` to copy `assets/` into local packages.
- Updated the packaged README skeleton with the project runtime template asset behavior and `.sdd/templates/{prd,spec,plan}` structure.
- Updated the repository README quick-start expectations with the initialized template directories and default pack behavior.
- Added contract assertions for the init skill, template-pack source assets, and both tar and zip package artifacts.

## What I tested and results

All required focused tests pass:

```text
PASS: skill contracts
PASS: local package script
PASS: DR filename contract
PASS: MVP acceptance
```

The package test also verified the three required template assets in both tar.gz and zip listings.

## TDD Evidence

### RED

Commands:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-package-local.sh
bash tests/test-mvp-acceptance.sh
```

Relevant output:

```text
FAIL: expected skills/init/SKILL.md to contain: 展示可选模板包列表
FAIL: expected /tmp/sdd-package-local-contents.out to contain: sdd-local/assets/template-packs/default-backend/prd/template.md
FAIL: expected skills/init/SKILL.md to contain: 展示可选模板包列表
```

### GREEN

Commands:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-package-local.sh
bash tests/test-mvp-acceptance.sh
```

Relevant output:

```text
PASS: skill contracts
PASS: local package script
PASS: DR filename contract
PASS: MVP acceptance
```

## Files changed

Committed task files:

- `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/init/SKILL.md`
- `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/package-local.sh`
- `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/README.md`
- `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
- `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-package-local.sh`
- `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-mvp-acceptance.sh`

This report:

- `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.superpowers/sdd/task-2-report.md`

## Self-review findings

- Confirmed the package copy loop includes `assets`, while retaining conditional copying for optional paths.
- Confirmed both archive formats contain the required default-backend PRD, Spec, and Plan assets.
- Confirmed the init skill no longer contains the forbidden English centralized-state assertion text and explicitly reports `.sdd/templates/`.
- Ran `git diff --check`; no whitespace errors were reported.
- Existing unrelated modified and untracked files were not changed or staged.

## Concerns

None for Task 2. Runtime routing of `/sdd:prd`, `/sdd:spec`, `/sdd:plan`, and independent reviewer behavior are intentionally deferred to Task 3 and later per the task brief.

## Review Fix: Explicit template-pack interface consumption

Addressed the Important review finding that `/sdd:init` described template-pack behavior only in natural language without specifying the required interfaces or selection flow.

Updated `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/init/SKILL.md` so the runtime steps now explicitly require:

```text
sdd_list_template_packs <plugin_root>
sdd_default_template_pack
sdd_copy_template_pack <plugin_root> <project_root> <pack_name>
```

The contract now defines that `sdd_list_template_packs` resolves and displays the available packs under Plugin `assets/template-packs/`, `sdd_default_template_pack` supplies the default identifier when the user does not select another pack, and `sdd_copy_template_pack` materializes the selected pack into `.sdd/templates/`.

Added assertions to `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh` for all three interfaces in the init skill contract and their definitions in `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-template-assets.sh`.

### Review-fix verification

Commands run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-package-local.sh
bash tests/test-mvp-acceptance.sh
git diff --check
```

Output summary:

```text
PASS: skill contracts
PASS: package-local
PASS: DR filename contract
PASS: MVP acceptance
```

`git diff --check` produced no output and exited successfully.

# SDD Plugin MVP 测试指南

本文档用于在合并到 `main` 前，手动验证 SDD Plugin MVP 是否可用。

## 1. 进入插件项目

在插件仓库根目录运行以下命令。

## 2. 运行自动化验证

```bash
bash tests/test-template-assets.sh && \
bash tests/test-template-runtime-contract.sh && \
bash tests/test-common-library.sh && \
bash tests/test-pre-tool-use.sh && \
bash tests/test-reference-validation.sh && \
bash tests/test-skill-contracts.sh && \
bash tests/test-template-governance-matrix.sh && \
bash tests/test-init-project-context.sh && \
bash tests/test-package-local.sh && \
bash tests/test-mvp-acceptance.sh
```

期望输出：

```text
PASS: template assets
PASS: template runtime contract
PASS: common library
PASS: pre-tool-use hook
PASS: reference validation
PASS: skill contracts
PASS: template governance matrix
PASS: init project context
PASS: local package script
PASS: MVP acceptance
```

## 模板包与 reviewer 手工验证

1. 运行 `/sdd:init`，确认会提示模板包选择，未显式切换时默认使用 `backend`。
2. 确认项目生成 `.sdd/templates/research/`、`.sdd/templates/prd/`、`.sdd/templates/spec/`、`.sdd/templates/plan/`、`.sdd/templates/dr/`。
3. 手工删除 `.sdd/templates/research/quality.standard.md` 后再次运行 `/sdd:research demo`，期望命令明确失败，并提示缺少项目模板资产。
4. 手工删除 `.sdd/templates/spec/feasibility.standard.md` 后再次运行 `/sdd:spec`，期望命令明确失败，并提示缺少项目模板资产。
5. 重新执行 `/sdd:init` 恢复缺失模板资产，并确认已有项目自定义模板不会被覆盖。
6. 如果项目根目录没有 `CLAUDE.md`，执行 `/sdd:init` 后确认自动生成默认 `CLAUDE.md`。
7. 编辑项目根 `CLAUDE.md` 为自定义内容后再次执行 `/sdd:init`，确认内容保持不变。
8. 预先放置 `AGENTS.md` 后执行 `/sdd:init`，确认该文件未被修改；如果不存在，也确认 `/sdd:init` 不会创建它。
9. 生成新 `research`、`prd`、`dr`、`spec`、`plan` 文档后，确认所属 Skill 显式进入 `/sdd:review <doc-path>`。
10. 确认 `research`、`prd`、`dr` create 只触发 `quality`；`spec` 与 `plan` create 按顺序触发 `quality -> feasibility`。
11. 更新已有文档时，确认不会自动 review，只输出手工复审提示。
12. 确认插件安装后的组件目录包含 `agents/doc-reviewer.md`。
13. 对可 review 文档执行 `/sdd:review <doc-path>`，确认 reviewer 使用该 agent，而不是仅依据 review skill 文本模拟执行，并且只返回一份聚合用户回执。
14. 对 archived version 下的 `research`、`prd/prd.md`、`spec/*.md`、`plan/*.md`、`dr/*.md` 执行 `/sdd:review`，期望直接失败。
15. 对一个可 review 文档执行 `/sdd:review <doc-path>`，确认系统按路径自动识别文档类型，而不是要求用户手工指定类型。
16. 对 `/sdd:code <plan>` 执行前，确认目标 plan 的 `## 文档引用` 中仍保持 `implements` 闭包指向 approved spec 或 accepted code-class DR。

## 3. 检查禁止路径

```bash
test ! -e .sdd/state.json && test ! -d commands && test ! -d templates
```

期望：无输出，退出码为 `0`。

## 4. 检查 Hook 注册

```bash
grep -F '${CLAUDE_PLUGIN_ROOT}/scripts/hooks/pre-tool-use.sh' hooks/hooks.json
grep -F '${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh' hooks/hooks.json
```

期望：两条命令都能输出匹配行。

## 5. 手动验证 PreToolUse 门控

创建临时项目：

```bash
tmp="$(mktemp -d)"
mkdir -p "$tmp/docs/versions/v0.1.0/spec" "$tmp/docs/versions/v0.1.0/plan" "$tmp/docs/versions/v0.1.0/dr" "$tmp/docs/versions/v0.1.0/prd"
```

验证缺少 PRD 时禁止写 spec：

```bash
cd "$tmp"
printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/spec/spec.md"}}' | /path/to/sdd-plugin/scripts/hooks/pre-tool-use.sh
```

期望：退出码为 `2`，并输出中文错误，提示先完成 `/sdd:prd`。

验证没有 approved spec 时禁止写普通 spec-mode plan：

```bash
printf '# PRD\n' > docs/versions/v0.1.0/prd/prd.md
printf '# Functional Specification\n\n- 状态：draft\n' > docs/versions/v0.1.0/spec/spec.md
printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/plan/001-login.md"}}' | /path/to/sdd-plugin/scripts/hooks/pre-tool-use.sh
```

期望：退出码为 `2`，并输出中文错误，提示先完成 `/sdd:spec` 并批准目标 Functional Specification。

验证存在 approved spec 后允许写普通 spec-mode plan：

```bash
printf '# Functional Specification\n\n- 状态：approved\n' > docs/versions/v0.1.0/spec/document-references.md
printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/plan/001-login.md"}}' | /path/to/sdd-plugin/scripts/hooks/pre-tool-use.sh
```

期望：无输出，退出码为 `0`。

清理临时项目：

```bash
rm -rf "$tmp"
```

## 6. 可选：本地安装后试用

在 Claude Code 2.1.29 中，先把插件目录添加为本地 marketplace，再安装 `sdd` plugin：

```bash
claude plugin marketplace add /path/to/sdd-plugin
claude plugin install sdd@sdd-local
claude plugin list
```

然后在一个空白测试仓库中尝试：

```text
/sdd:init
/sdd:new v0.2.0
/sdd:research demo
/sdd:prd
/sdd:spec
/sdd:plan demo
```

重点确认：

- `/sdd:init` 创建 `docs/CONSTITUTION.md`、`docs/versions/`、`docs/archive/`。
- `/sdd:init` 在项目根目录缺失 `CLAUDE.md` 时创建默认项目协作说明；若已存在则保持不变。
- `/sdd:init` 不处理 `AGENTS.md`。
- `/sdd:init` 创建 `.sdd/templates/research/`、`.sdd/templates/prd/`、`.sdd/templates/spec/`、`.sdd/templates/plan/`、`.sdd/templates/dr/`。
- `/sdd:init` 不自动安装依赖插件。
- `/sdd:init` 会提示用户手动安装 `superpowers` 与 `spec-kit`。
- `/sdd:new v0.2.0` 创建 `docs/versions/v0.2.0/state.json`、`research/`、`prd/`、`spec/`、`plan/`、`dr/`。
- `research` 缺少 `quality.standard.md` 时会明确失败。
- feature plan 在 `spec.md` 未 `approved` 时会被拒绝。
- archived version 下的文档不能执行 `/sdd:review`。
- `/sdd:review <doc-path>` 会按路径自动识别 `research / prd / dr / spec / plan` 类型。
- `/sdd:code <plan>` 依赖 plan 的 `## 文档引用` 闭包仍然完整。

## 7. 验收通过后

完成合并或发布所需的仓库流程。

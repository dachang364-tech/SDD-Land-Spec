# SDD Plugin MVP 测试指南

本文档用于在合并到 `main` 前，手动验证 SDD Plugin MVP 是否可用。

## 1. 进入实现分支

```bash
cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.worktrees/document-references-advanced-fresh
```

确认当前分支：

```bash
git branch --show-current
```

期望输出：

```text
feature-document-references-advanced-fresh
```

## 2. 运行自动化验证

```bash
bash tests/test-doctor-contract.sh && bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-reference-validation.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

期望输出：

```text
PASS: skeleton contract
PASS: common library
PASS: pre-tool-use hook
PASS: reference validation
PASS: skill contracts
PASS: MVP acceptance
```

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
mkdir -p "$tmp/docs/versions/v0.1.0/specs" "$tmp/docs/versions/v0.1.0/plans" "$tmp/docs/versions/v0.1.0/decisions"
```

验证缺少 PRD 时禁止写 spec：

```bash
cd "$tmp"
printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/specs/spec.md"}}' | /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.worktrees/document-references-advanced-fresh/scripts/hooks/pre-tool-use.sh
```

期望：退出码为 `2`，并输出中文错误，提示先完成 `/sdd:prd`。

验证 spec approved 后允许写 feature plan：

```bash
printf '# PRD\n' > docs/versions/v0.1.0/prd.md
printf '# Functional Specification\n\n- 状态：approved\n' > docs/versions/v0.1.0/specs/spec.md
printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/plans/001-feature-login.md"}}' | /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.worktrees/document-references-advanced-fresh/scripts/hooks/pre-tool-use.sh
```

期望：无输出，退出码为 `0`。

清理临时项目：

```bash
rm -rf "$tmp"
```

## 6. 可选：本地安装后试用

在 Claude Code 2.1.29 中，先把当前 worktree 添加为本地 marketplace，再安装 `sdd` plugin：

```bash
claude plugin marketplace add /path/to/sdd-plugin
claude plugin install sdd@sdd-local
claude plugin list
```

然后在一个空白测试仓库中尝试：

```text
/sdd:init
/sdd:new v0.2.0
/sdd:status
/sdd:research demo
/sdd:prd
/sdd:spec
/sdd:plan demo
```

重点确认：

- `/sdd:init` 创建 `docs/CONSTITUTION.md`、`docs/requirements/`、`docs/archive/`。
- `/sdd:new v0.2.0` 创建 `docs/versions/v0.2.0/state.json`、`docs/versions/v0.2.0/specs/`、`plans/`、`decisions/`。
- `/sdd:status` 能展示当前版本状态和下一步建议。
- feature plan 在 `spec.md` 未 `approved` 时会被拒绝。

## 7. 验收通过后

如果测试无误，再执行合并流程：

```text
Merge back to main locally
```

当前实现分支：

```text
feature-document-references-advanced-fresh
```

# Task 2 实现报告

## 结果

已将 `research / prd / dr / spec / plan` 五个文档 Skill 的 review 合同改为 create / update 双态：create 显式触发 `/sdd:review <doc-path>` 或等价共享 runner 流程，update 不自动 review；同时保留 `PostToolUse Hook`、`共享 review runner`、`/sdd:review`、`doc-reviewer` 等关键字符串，但不再把 Hook 写成主触发职责。

## 变更

- 将 `skills/research/SKILL.md` 与 `skills/prd/SKILL.md` 的 frontmatter `description` 改为中文，并把 Review 段落改为 create / update 分流。
- 将 `skills/dr/SKILL.md` 的 frontmatter `description` 改为中文，并在 create mode 中引入 create / update 分流语义。
- 将 `skills/spec/SKILL.md` 与 `skills/plan/SKILL.md` 的 frontmatter `description` 改为中文，并在 Review 段落中明确：
  - 写入前先判断 create / update
  - create 必须显式 review
  - update 不自动 review
  - 新建文档拿不到有效 review 结果时保持 `draft`
- 更新 `tests/test-skill-contracts.sh`：
  - 断言五个 Skill 都包含 create / update 文案
  - 断言 create 必须显式 review，update 不自动 review
  - 断言移除“成功写入后由运行时 Hook 触发 review”等旧主流程文案
  - 同步将五个 Skill 的 frontmatter `description` 断言改为中文
  - 增补 `spec / plan` 的 update 不自动 review 断言
- 调整 `tests/test-template-governance-matrix.sh` 与 `tests/test-mvp-acceptance.sh`，保留关键字符串校验，但不再要求文档 Skill 把 Hook 描述为主流程。

## TDD 与验证

先更新 `tests/test-skill-contracts.sh` 让 create / update 分流成为必需合同，再最小改写五个 Skill 文案并同步收敛相关测试。

通过：

```text
bash tests/test-skill-contracts.sh
bash tests/test-template-governance-matrix.sh
bash tests/test-mvp-acceptance.sh
git diff --check
```

以上检查均通过。

## 自检

- 未新增命令名。
- 未修改 plugin metadata。
- 未修改模板资产。
- 保留了 `PostToolUse Hook`、`共享 review runner`、`/sdd:review`、`doc-reviewer` 关键字符串。
- 未把 Hook 写成文档 Skill 的 review 主触发职责。
- 变更范围保持在 Task 2 允许的 Skill 与测试文件内。

## 提交

- 已有中间提交：`6775928 feat: start splitting document review contracts`
- 本轮收口提交目标：`feat: split document skill review flow`

# Task 2 实现报告

## 结果

已将 `research / prd / dr / spec / plan` 五个文档 Skill 的 review 合同收敛为与实际命令模型一致的 create / update 双态：

- `research / prd / spec / plan`：写入前显式判断 create / update；create 必须显式触发 `/sdd:review <doc-path>` 或等价共享 runner 流程，update 不自动 review。
- `dr`：create mode 只创建新 DR，因此该分支明确只走 create；`accept / dismiss` 属于对既有 DR 的 update，统一改为“不自动执行 review，如需复审请手工执行 `/sdd:review <doc-path>`”。

同时，五个 Skill 的用户可见正文继续做了最小中文化收口，保留 `PostToolUse Hook`、`共享 review runner`、`/sdd:review`、`doc-reviewer` 等关键字符串，但不再把 Hook 写成主触发职责。

## 变更

- 继续最小改写 `skills/research/SKILL.md`、`skills/prd/SKILL.md`、`skills/spec/SKILL.md`、`skills/plan/SKILL.md`、`skills/dr/SKILL.md`：
  - 将残留的英文标题与关键步骤说明改为中文。
  - 保留必要英文术语与正则、路径、命令名。
- 纠正 `skills/dr/SKILL.md` 的 review 合同：
  - 删除 create mode 中不可达的“目标文件不存在：视为 create；存在：视为 update”表述。
  - 明确 create mode 恒为 create。
  - 明确 `accept / dismiss` 是 update，且 update 不自动 review。
- 更新 `tests/test-skill-contracts.sh`：
  - 对 `dr` 单独断言 create-only 与 update-on-accept-dismiss 语义。
  - 将 `plan` 与 `dr` 的部分断言同步改为中文文本，避免继续要求旧英文文案。
- 更新 `tests/test-dr-filename-contract.sh`：
  - 将 `plan` 模式识别相关断言改为中文文本，和 Skill 当前合同保持一致。

## 验证

通过：

```text
bash tests/test-template-governance-matrix.sh
bash tests/test-skill-contracts.sh
bash tests/test-dr-filename-contract.sh
bash tests/test-mvp-acceptance.sh
git diff --check
```

以上检查均通过。

## 自检

- 未新增命令名。
- 未修改 plugin metadata。
- 未修改模板资产。
- 保留了 `PostToolUse Hook`、`共享 review runner`、`/sdd:review`、`doc-reviewer` 关键字符串。
- `dr` 的 create/update 语义现在与 `create / accept / dismiss` 命令模型一致。
- 五个文档 Skill 的用户可见正文已进一步中文化，满足项目语言约束。
- 变更范围保持在 Task 2 允许的 Skill 与测试文件内。

# SDD Plugin 设计规格：DR Template and Review Governance

- 日期：2026-07-20
- 状态：draft
- 类型：Design Spec
- 目标：将 `/sdd:dr` 纳入统一模板治理体系，在保持 DR 现有编号、状态流转与引用合同不变的前提下，为 DR 引入项目运行时模板、`/sdd:init` 模板物化、`/sdd:review` 的 `quality` 审查接入，以及与 `doctor`、README、测试、打包一致的资产与合同校验。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 文档生成模板统一治理基线 | [2026-07-20-document-generation-skills-template-governance-design.md](./2026-07-20-document-generation-skills-template-governance-design.md) | - | 复用“运行时只读取项目 `.sdd/templates/`”和“plugin 模板包只由 `/sdd:init` 物化”的基础原则，并扩展到 DR |
| references | reviewer 架构与输出合同 | [2026-07-19-document-quality-reviewer-design.md](./2026-07-19-document-quality-reviewer-design.md) | - | 复用统一 reviewer agent、结构化 JSON 输入输出、schema 校验与单回执聚合约束 |
| references | Plugin 资源访问与路径边界 | [2026-07-17-plugin-resource-access-contract-design.md](./2026-07-17-plugin-resource-access-contract-design.md) | - | 保持 `${CLAUDE_PLUGIN_ROOT}` 与 `${CLAUDE_PROJECT_DIR}` 的显式边界 |
| references | 项目级 Skill 方案约束 | [CLAUDE.md](../../../CLAUDE.md) | - | 本规格后续若进入实现计划，所有 `skills/*/SKILL.md` 的创建或改写都必须显式纳入 `/skill-creator` 工作流 |

## 1. Context

当前 `/sdd:dr` 已具备完整的 DR 编号、slug 规则、状态流转和 `## 文档引用` 合同，但它仍是模板治理上的例外点：

- `/sdd:dr` 在创建模式下仍直接使用 `skills/dr/references/dr.md.tmpl` 作为生成模板。
- `DR` 尚未拥有 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/backend/dr/` 默认模板资产。
- `/sdd:init` 不会将 DR 模板物化到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/`。
- `/sdd:doctor` 不检查 DR 的 plugin 模板资产与项目运行时模板资产。
- `/sdd:review`、`agents/doc-reviewer.md` 和 `reviewer-result.schema.json` 尚未正式支持 `document_type: dr`。

这会造成两个明显问题：

1. `DR` 与 `research / prd / spec / plan` 的模板事实来源不一致，继续保留 skill 内置模板这一例外。
2. `DR` 虽然本质上是结构化文档，但没有进入统一的 reviewer 闭环，初稿质量和结构约束只能依赖 skill 本身与人工修订。

因此，本规格的目标不是重写 DR 生命周期，而是将 `DR` 收敛到与其他文档类 skill 一致的模板与 review 治理模型中。

## 2. Goals

1. 为 `DR` 引入 plugin 默认模板资产：`${CLAUDE_PLUGIN_ROOT}/assets/template-packs/backend/dr/template.md`。
2. 统一规定：`/sdd:dr` 在运行时只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md`。
3. 扩展 `/sdd:init`，使其在初始化或补齐时将 DR 模板物化到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/`。
4. 删除 `skills/dr/references/dr.md.tmpl` 作为运行时模板事实来源，避免双事实来源。
5. 让 `DR` 接入统一 `/sdd:review` 体系，但只支持 `quality`，不接入 `feasibility`。
6. 继续复用现有 `doc-reviewer` agent 与 reviewer schema/聚合回执模式，不新建独立 `dr-reviewer`。
7. 同步更新 `doctor`、README、TESTING、打包与自动化测试，使 DR 在模板治理与 review 治理上成为正式覆盖对象。
8. 后续涉及 `skills/dr/SKILL.md`、`skills/review/SKILL.md` 或 reviewer agent 合同改写时，必须显式纳入 `/skill-creator` 工作流，确保 Skill 合同符合 Claude Code 规范。

## 3. Non-Goals

本规格不要求实现：

- 修改 DR 的编号规则、slug 规则或 `DR ID` 语义。
- 修改 DR 的状态机：`drafting -> accepted -> closed`。
- 将 `DR` 接入 `feasibility` reviewer。
- 为 DR 引入独立的 `quality.standard.md`；本次只要求 `template.md`，review 标准暂由 reviewer 合同与 DR 模板结构共同约束；若未来需要更细粒度标准，再作为增量规格引入。
- 重写 code-class 与 document-class DR 的 tag 默认矩阵。
- 修改 `/sdd:dr accept`、`/sdd:dr dismiss` 的输出下一步决策逻辑。
- 在本规格中同时处理“所有 Plugin Skills 用 `/skill-creator` 全量再生成”的大范围议题；该议题独立于 DR，已由项目级 `CLAUDE.md` 约束。

## 4. Core Design Principles

### 4.1 DR 也必须服从单一运行时模板事实来源

`/sdd:dr` 创建模式在运行时只读取项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md`。Skill 内置 references 模板、README 示例或 plugin 静态模板包都不构成运行时事实来源。

### 4.2 `/sdd:init` 是 DR 模板的唯一物化入口

`${CLAUDE_PLUGIN_ROOT}/assets/template-packs/backend/dr/template.md` 只由 `/sdd:init` 用于初始化或补齐项目模板资产。运行时不允许回退到 plugin 资产。

### 4.3 DR review 复用现有 reviewer 架构，不另起一套 agent

`DR` 接入 `/sdd:review` 时，继续使用：

- `skills/review/SKILL.md` 作为编排合同
- `agents/doc-reviewer.md` 作为实际执行 agent
- `skills/review/references/reviewer-result.schema.json` 作为机器输出合同

但必须扩展现有合同枚举与 admission 规则，使其正式支持 `document_type: dr`。

### 4.4 DR 只接入 quality review

`DR` 是决策记录，不是技术实现方案，因此只执行 `quality` review，不执行 `feasibility` review。

### 4.5 Skill 合同升级必须遵守 `/skill-creator` 约束

本规格若进入实现阶段，凡涉及：

- `skills/dr/SKILL.md`
- `skills/review/SKILL.md`
- 任何其他 `skills/*/SKILL.md`

的创建、重写或结构升级，都必须显式使用 `/skill-creator` 生成或规范化目标 Skill 合同，再结合本项目脚本、模板、agent、测试合同做收敛。

## 5. Asset Model and Directory Layout

### 5.1 Plugin 内置模板资产

本规格新增的 plugin 模板资产为：

```text
${CLAUDE_PLUGIN_ROOT}/assets/template-packs/backend/dr/
└── template.md
```

规则：

- `dr/template.md` 为中文正文模板。
- 模板应体现当前 DR 既有结构，而不是发明另一套 DR 文档骨架。
- 该资产必须被纳入 package 产物、doctor 检查和自动化测试。

### 5.2 项目运行时模板目录

初始化或补齐后，项目运行时目录新增：

```text
${CLAUDE_PROJECT_DIR}/.sdd/templates/
└── dr/
    └── template.md
```

规则：

- 这是 `/sdd:dr` 创建模式唯一有效模板目录。
- 用户可以直接编辑该模板；编辑后的内容立即成为新的运行时行为依据。
- 不要求系统记录该模板最初由哪个模板包物化而来。

### 5.3 Skill 目录职责收敛

`skills/dr/` 应只保留行为合同，不再保留运行时模板来源。

目标结构：

```text
skills/
└── dr/
    └── SKILL.md
```

因此本规格要求移除或停止依赖：

```text
skills/dr/references/dr.md.tmpl
```

理由：

- 它会继续制造 skill 合同与运行时模板之间的双事实来源。
- DR 与其他文档类 skill 的模板治理模型将继续不一致。

## 6. Runtime Reading Rules

统一规则如下：

1. `/sdd:dr` 创建模式只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md`。
2. 若 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md` 缺失，命令直接失败，并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
3. `/sdd:review` 在处理 `document_type: dr` 且 `mode: quality` 时，只读取与 DR 对应的运行时模板路径。
4. 运行时不允许回退到 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/backend/dr/template.md`。

## 7. `/sdd:init` Contract Extension

### 7.1 职责扩展

`/sdd:init` 需要将 DR 纳入模板包物化范围。初始化时，所选模板包除 `research / prd / spec / plan` 外，还必须补齐 `dr/template.md`。

### 7.2 资产展开规则

展开后的目标目录为：

```text
${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md
```

规则：

- 只补齐缺失文件，不覆盖用户已有模板定制。
- 支持重复执行以恢复缺失资产。
- 与现有模板治理模型一致，不因 DR 而引入新的覆盖策略。

## 8. `/sdd:dr` Contract Changes

### 8.1 Preconditions

`/sdd:dr` 的前置条件除现有 `docs/CONSTITUTION.md`、active version 和状态一致性检查外，还应增加：

1. 要求 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/` 存在。
2. 要求 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md` 存在且可读。
3. 任一缺失时直接失败，并提示重新执行 `/sdd:init`。

### 8.2 Create mode

当前 create mode 中这条行为：

```text
Write `docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md` from `skills/dr/references/dr.md.tmpl`.
```

应调整为：

```text
Write `docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md` from `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md`.
```

同时保留以下既有语义不变：

- 版本内递增 DR 编号
- `DR ID` 规则
- 标题标识格式 `DR-NNN-<tag>`
- `class / spec_change / plan_required / code_required` 推导
- `## 文档引用` 作为正式关系来源
- `code-class` 与 `document-class` 的下一步输出规则

### 8.3 Review Flow

`/sdd:dr` 在写入完成并通过最小结构校验后，应自动触发 `quality` reviewer。

规则：

- 自动触发仅适用于 create mode 产出的新 DR。
- 用户手工修改后，可通过 `/sdd:review` 对该 DR 重新执行 `quality` 复审。
- `DR` 不接入 `feasibility`。
- review 结果为阻断时，不应自动推进 accept/dismiss，只返回聚合回执并保留当前 DR 状态。

## 9. Review Contract Changes

### 9.1 `skills/review/SKILL.md`

需要扩展：

- `document_type` 枚举从 `research|prd|spec|plan` 扩展为 `research|prd|spec|plan|dr`
- mode 矩阵新增：

```text
dr -> quality
```

- admission contract 需要允许 `dr` 使用其自身模板定义的核心章节，而不是硬编码复用 `PRD / spec / plan` 假设。

### 9.2 `agents/doc-reviewer.md`

需要扩展：

- `document_type` 输入合同从 `prd|spec|plan` 扩展为 `research|prd|spec|plan|dr`
- admission check 不能要求所有类型都必须套用同一固定章节假设
- 对 `dr` 来说，核心要求是：
  - 存在必要元信息
  - 存在模板定义的必需章节
  - 保留 `## 文档引用` 表合同
  - 不是未经替换的模板占位稿

### 9.3 `reviewer-result.schema.json`

需要扩展：

- `document_type` 的 `enum` 正式支持 `dr`
- `user_receipt.document_type` 的可选值与主 `document_type` 保持一致

### 9.4 现有 research 合同断裂需要一并修复

当前 `skills/review/SKILL.md` 已声明支持 `research`，但 `agents/doc-reviewer.md` 和 `reviewer-result.schema.json` 尚未同步支持 `research`。本规格要求在引入 `dr` 的同时，一并修复这条已存在的合同断裂，避免再次出现“Skill 声称支持，但 agent/schema 不支持”的状态。

## 10. DR Template Structure

默认 `dr/template.md` 必须反映当前 DR 的正式结构，而不是引入一套与现有命令合同脱节的新模板。

建议最小模板骨架至少包含：

```md
# DR-NNN-<tag>：<title>

- 状态：drafting
- 日期：YYYY-MM-DD
- 标签：<tag>
- 类别：<code|document>
- spec_change：<yes|no|maybe>
- plan_required：<yes|no>
- code_required：<yes|no>

## 背景
## 决策
## 影响
## 文档引用
| 引用 | locator | 关系 | 说明 | 状态 |
| ---- | ------- | ---- | ---- | ---- |
| 未声明。 | - | - | - | - |

## 影响资产
```

规则：

- 模板中的章节名与字段名必须与当前 DR contract 保持兼容。
- 允许模板正文使用中文，但命令名、路径、字段标识和必要技术标识可保留英文。
- `## 文档引用` 仍是 DR 的正式关系来源，不能被简化掉。

## 11. Doctor, README, Packaging, and Testing Alignment

### 11.1 `/sdd:doctor`

`/sdd:doctor` 需要新增两层检查：

1. plugin 模板包中的 `assets/template-packs/backend/dr/template.md` 是否存在。
2. 项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md` 是否存在。

缺失时应明确提示重新执行 `/sdd:init`。

### 11.2 README / TESTING

README 与 TESTING 需要同步体现：

- 文档生成与审查治理现在覆盖 `dr`
- `.sdd/templates/dr/` 是 `/sdd:dr` 的运行时模板来源
- `DR` 写入完成后自动接入 `quality` reviewer
- `DR` 不接入 `feasibility` reviewer

### 11.3 Packaging

package 产物必须包含：

- `assets/template-packs/backend/dr/template.md`
- 更新后的 `skills/dr/SKILL.md`
- 更新后的 reviewer 合同与 `agents/doc-reviewer.md`

## 12. Testing Strategy

### 12.1 必改测试

1. `tests/test-skill-contracts.sh`
   - 验证 `skills/dr/SKILL.md` 显式读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md`
   - 验证 `skills/dr/SKILL.md` 不再把 `skills/dr/references/dr.md.tmpl` 作为运行时模板来源
   - 验证 `skills/review/SKILL.md` 的 `document_type` 支持 `dr`
   - 验证 mode 矩阵包含 `dr -> quality`

2. `tests/test-template-assets.sh`
   - 验证 `backend/dr/template.md` 会被复制到 `.sdd/templates/dr/template.md`

3. `tests/test-template-runtime-contract.sh`
   - 验证 DR 模板缺失时 `/sdd:dr` 必须失败

4. `tests/test-doctor-contract.sh`
   - 增加 DR 的 plugin 与项目运行时模板检查

5. `tests/test-review-output-contract.sh`
   - 扩展 reviewer schema 与 README/TESTING 中对 DR review 的约束断言

6. `tests/test-package-local.sh`
   - 验证 package 产物包含 `assets/template-packs/backend/dr/template.md`

### 12.2 建议新增测试

建议新增一个专门的 DR 治理矩阵测试，例如：

- 校验 `dr/template.md` 已纳入 plugin 资产与项目运行时复制矩阵
- 校验 `skills/dr/references/dr.md.tmpl` 不再作为运行时依赖
- 校验 reviewer 合同、agent 合同和 schema 对 `dr` 的支持是一致的

## 13. Migration Rules

为避免 DR 落入半新半旧状态，本次迁移应遵守：

1. 先统一 spec，明确 DR 只接 `quality`。
2. 再统一 reviewer 的 Skill / agent / schema 三层合同，不允许只改一层。
3. 再引入 DR 模板资产与 `/sdd:init` 物化。
4. 最后收敛 `skills/dr/SKILL.md`、doctor、README、TESTING、打包与测试。
5. 任何涉及 `skills/*/SKILL.md` 的改写都必须显式纳入 `/skill-creator` 工作流。

## 14. Acceptance Criteria

以下条件全部满足时，本规格视为被正确实现：

1. plugin 内置模板中新增 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/backend/dr/template.md`。
2. `/sdd:init` 会将该模板物化到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md`。
3. `/sdd:dr` 在运行时只读取项目 `.sdd/templates/dr/template.md`。
4. `skills/dr/references/dr.md.tmpl` 不再作为运行时模板事实来源。
5. DR 模板缺失时，`/sdd:dr` 会明确失败，并提示重新执行 `/sdd:init`。
6. `DR` 写入完成并通过最小结构校验后，会自动触发 `quality` reviewer。
7. `DR` 不接入 `feasibility` reviewer。
8. `/sdd:review`、`agents/doc-reviewer.md` 和 `reviewer-result.schema.json` 对 `document_type: dr` 的支持保持一致。
9. 现有 `research` 的 review 合同断裂在同一轮一并修复，不允许 `skills/review/SKILL.md` 与 agent/schema 继续不一致。
10. `/sdd:doctor`、README、TESTING、打包与自动化测试均与 DR 的新模板与 review 治理模型保持一致。
11. 后续若进入实现计划，计划中会明确写入 `/skill-creator` 作为 Skill 改写的标准工具。

## 15. Decision Summary

本规格采用以下设计立场：

- `DR` 虽然具有独立生命周期，但在模板治理上不再是例外点。
- `DR` 的运行时模板事实来源属于项目 `.sdd/templates/dr/`，不属于 `skills/dr/references/`。
- `DR` 接入统一 reviewer 架构，但只执行 `quality`。
- reviewer 架构继续复用 `skills/review/SKILL.md`、`agents/doc-reviewer.md` 与 schema，不新建独立 agent。
- 若为支持 `dr` 需要扩展 Skill/agent/schema，则必须三层同时对齐；不能只改 Skill 文案。
- 本规格与“全量 Skill 规范化重构”解耦，但要求任何后续 Skill 改写都遵循项目级 `CLAUDE.md` 中的 `/skill-creator` 约束。

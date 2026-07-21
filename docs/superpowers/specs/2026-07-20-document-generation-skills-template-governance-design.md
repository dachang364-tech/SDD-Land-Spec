# SDD Plugin 设计规格：Document Generation Skills Template Governance

- 日期：2026-07-20
- 状态：draft
- 类型：Design Spec
- 目标：统一 `research`、`prd`、`spec`、`plan` 四类文档生成 skills 的模板治理模型、运行时模板优先级、中文技能合同风格和 `/sdd:init` 模板风格选择行为，使文档生成从第一轮产出开始就遵循项目运行时模板，降低后续 reviewer 与人工修订成本。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 模板资产与 reviewer 运行时优先级 | [2026-07-19-document-quality-reviewer-design.md](./2026-07-19-document-quality-reviewer-design.md) | - | 复用项目 `.sdd/templates/` 是运行时唯一事实来源这一原则，并扩展到 research 与文档生成 skills 的统一治理 |
| references | Plugin 资源访问与路径边界 | [2026-07-17-plugin-resource-access-contract-design.md](./2026-07-17-plugin-resource-access-contract-design.md) | - | 保持 `${CLAUDE_PLUGIN_ROOT}` 与 `${CLAUDE_PROJECT_DIR}` 的显式边界，不混淆 plugin 资产与项目运行时资产 |
| references | SDD 主流程与技能边界 | [2026-07-11-sdd-plugin-mvp-workflow-spec-design.md](./2026-07-11-sdd-plugin-mvp-workflow-spec-design.md) | - | 本规格只调整文档生成 skills 的模板治理与合同风格，不重写整体 SDD 生命周期 |
| references | 现有 init 行为与依赖安装边界 | [2026-07-15-init-manual-dependency-install-design.md](./2026-07-15-init-manual-dependency-install-design.md) | - | 延续 `/sdd:init` 不自动安装依赖插件的边界，只扩展模板包选择与模板资产物化职责 |

## 1. Context

当前设计已经把 `prd / spec / plan` 的运行时模板收敛到项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`，并通过 `/sdd:init` 从 plugin 内置 `assets/template-packs/` 下发模板资产。reviewer 也已经明确以项目运行时模板为唯一审核依据，不再在运行时回退到 plugin 内置模板。

但文档生成相关 skills 仍存在不一致：

- `research` 仍依赖 `skills/research/references/research.md.tmpl`，没有进入统一模板治理模型。
- `plan` 目录仍保留 `references/plan.md.tmpl` 这一历史残留，容易让 skill 合同与真实运行时模板来源脱节。
- 各文档生成 skill 的章节组织、路径写法、中英文风格和模板来源表达仍不完全一致。
- 当前 template pack 命名与 `/sdd:init` 交互还偏内部实现视角，未把“前端 / 后端模板风格选择”正式定义为技能合同的一部分。

这些问题会导致三类成本继续存在：

1. 新生成文档的第一版质量依赖 skill 自由发挥，不能保证从第一轮就严格贴合项目模板与标准。
2. 模板事实来源分散在 skill 目录、plugin 资产和项目运行时目录之间，后续维护容易继续漂移。
3. reviewer 虽然已经稳定，但前置文档生成如果不统一，会把不必要的收敛成本推给 reviewer 和人工修订阶段。

因此本次规格的目标不是增加新能力点，而是把文档生成 skills 的模板治理模型彻底收口。

## 2. Goals

1. 把 `research`、`prd`、`spec`、`plan` 全部纳入统一模板治理模型。
2. 统一规定：文档生成 skills 在运行时只读取项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/`。
3. 统一规定：plugin 内置模板只存在于 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/<pack>/`，只由 `/sdd:init` 使用。
4. 让 `/sdd:init` 支持模板风格选择合同；本次规格先落地 `backend` 模板，并为未来扩展 `frontend` 预留结构。
5. 统一四个文档生成 skills 的中文风格、章节结构、路径变量写法和失败语义。
6. 统一本次落地模板包与项目运行时模板的正文语言为中文，确保 skills 合同与模板内容语言一致。
7. 删除 skill 目录中会形成双事实来源的历史模板残留。
8. 让 `research` 接入 `quality` reviewer，并把 `research/quality.standard.md` 定义为 reviewer 正式消费的标准文件。
9. 同步更新 `doctor`、README、测试与模板资产检查逻辑，使系统围绕同一套事实来源工作。

## 3. Non-Goals

本规格不要求实现：

- 为运行时模板引入 plugin fallback、自动损坏检测或内容自动修复机制。
- 在项目中记录“首次选择了 frontend 还是 backend 模板包”的元数据文件。
- 在本次版本中不实现 `frontend` 模板内容，只保留未来扩展所需的模板风格选择合同与目录结构预留。
- 重写 reviewer JSON schema、review mode 定义或 reviewer admission contract。
- 引入多语言文档生成 skills；本次统一风格为中文。
- 为 skill 目录保留第二套 references 模板作为兼容兜底。

## 4. Core Design Principles

### 4.1 单一运行时事实来源

文档生成与 reviewer 在运行时都只使用项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 下的模板与标准。任何 skill 目录内模板、plugin 内置模板包或 README 示例都不构成运行时事实来源。

### 4.2 plugin 资产与项目资产显式分层

- `${CLAUDE_PLUGIN_ROOT}` 用于表示 plugin 自带静态资产。
- `${CLAUDE_PROJECT_DIR}` 用于表示用户项目中的运行时资产。

两者都允许被 skill 文本引用，但必须显式区分职责，不得在合同层面模糊。

### 4.3 `/sdd:init` 是唯一模板物化入口

Plugin 模板包不是运行时回退来源，而是由 `/sdd:init` 物化到项目 `.sdd/templates/` 的静态来源。初始化后，运行时一律以项目目录中的模板为准。

### 4.4 文档生成必须从第一轮就遵循项目模板

reviewer 的职责是收敛质量，不是弥补模板治理混乱。`research / prd / spec / plan` 的初次生成必须显式读取项目运行时模板和标准，以降低后续 review 成本。

其中 `research` 也应接入 `quality` reviewer，使上游研究资料在被 `PRD / spec` 正式引用前先完成基础质量收敛。

### 4.5 技能合同风格统一且中文优先

四个文档生成 skills 的行为合同、失败提示、路径说明和章节组织都应尽量使用中文，且采用同一骨架，只有命令、路径、变量名和必要技术标识保留英文。

### 4.6 Skills 与模板内容均采用中文

本次规格要求两层内容同时中文化：

1. `skills/*/SKILL.md` 的行为合同内容采用中文。
2. `assets/template-packs/backend/.../*.md` 中的模板与标准正文采用中文。

这意味着：

- skills 的章节标题、行为说明、失败提示、交互语义、边界说明采用中文。
- 模板正文中的章节标题、提示语、示例说明、标准描述采用中文。
- 项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/...` 由 `/sdd:init` 物化后，自然也应保持中文。

允许保留英文的范围仅包括：

- slash command 名称
- 文件路径
- 环境变量
- mode 名称、标准文件名与必要技术标识

这样可以保证用户直接阅读 skill 合同与模板内容时，不会出现“skill 是中文、模板是英文”或“模板是中文、标准是英文”的混杂情况。

## 5. Asset Model and Directory Layout

### 5.1 Plugin 内置模板包

建议将 plugin 内置模板包按“已实现模板包”和“预留扩展结构”区分组织。

本次规格落地的实际资产应至少包含：

```text
${CLAUDE_PLUGIN_ROOT}/assets/template-packs/
└── backend/
    ├── research/
    │   ├── template.md
    │   └── quality.standard.md
    ├── prd/
    │   ├── template.md
    │   └── quality.standard.md
    ├── spec/
    │   ├── template.md
    │   ├── quality.standard.md
    │   └── feasibility.standard.md
    └── plan/
        ├── template.md
        ├── quality.standard.md
        └── feasibility.standard.md
```

同时，技能合同与目录设计应允许未来扩展到：

```text
${CLAUDE_PLUGIN_ROOT}/assets/template-packs/
├── backend/
└── frontend/   # 未来版本扩展，当前 spec 不要求提供实际模板内容
```

规则：

- 模板风格的选择发生在 template pack 层，而不是运行时文档生成层。
- 本次版本只要求提供并验证 `backend` 模板包。
- `frontend` 只作为未来扩展方向写入合同与目录预留，不要求在本次实现中提供实际模板文件。
- 每个已实现模板包都必须同时覆盖 `research / prd / spec / plan` 四类文档。
- `research` 也必须拥有 `template.md` 与 `quality.standard.md`，并接入 `quality reviewer` 自动闭环，但不接入 `feasibility reviewer`。
- 已实现模板包资产必须被纳入 package 产物、doctor 检查和自动化测试覆盖。

### 5.2 项目运行时模板目录

初始化后，项目运行时目录统一为：

```text
${CLAUDE_PROJECT_DIR}/.sdd/templates/
├── research/
│   ├── template.md
│   └── quality.standard.md
├── prd/
│   ├── template.md
│   └── quality.standard.md
├── spec/
│   ├── template.md
│   ├── quality.standard.md
│   └── feasibility.standard.md
└── plan/
    ├── template.md
    ├── quality.standard.md
    └── feasibility.standard.md
```

规则：

- 这是运行时唯一有效模板根目录。
- 用户可以直接编辑其中任何模板或标准文件；编辑后的内容立即成为新的运行时行为依据。
- 不要求系统记录当前 `.sdd/templates/` 最初来自哪个模板包。

### 5.3 Skill 目录职责收敛

文档生成 skill 目录应只保留行为合同，不保留运行时模板事实来源。

目标结构：

```text
skills/
├── research/
│   └── SKILL.md
├── prd/
│   └── SKILL.md
├── spec/
│   └── SKILL.md
└── plan/
    └── SKILL.md
```

因此本次设计建议删除：

- `skills/research/references/research.md.tmpl`
- `skills/plan/references/plan.md.tmpl`

理由：

- 它们会继续制造 skill 文本合同与运行时模板之间的双事实来源。
- 模板内容应统一归属于 template pack 与项目运行时模板，而不是归属于 skill 目录。

## 6. Runtime Reading Rules

统一规则如下：

1. `/sdd:research` 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/`。
2. `/sdd:prd` 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/`。
3. `/sdd:spec` 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/`。
4. `/sdd:plan` 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/`。
5. `/sdd:review` 只读取与目标文档类型匹配的 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/`。
6. `research` 在 review 时只接入 `quality`，不接入 `feasibility`。
7. 任何必要模板或标准文件缺失时，相关命令直接失败，并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
8. 第一阶段不允许在运行时回退到 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/`。

这条规则的目标是让生成与 review 从第一轮起就消费同一套运行时资产，避免“按 skill 内置模板生成，再按项目模板审核”的错位。

## 7. `/sdd:init` Template Pack Selection Contract

### 7.1 职责定义

`/sdd:init` 不只是目录初始化命令，还必须承担模板风格选择与模板资产物化职责。

### 7.2 模板风格选择

初始化时，`/sdd:init` 必须：

1. 列出 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/` 下可用的模板包。
2. 允许用户选择模板风格；本次版本实际可选项为：
   - `backend`
3. `frontend` 作为未来扩展方向保留在技能合同中，但本次不要求提供实际模板内容。
4. 如果用户未显式选择，则使用默认模板包。
5. 若当前只有一个可用模板包，可以直接使用，但仍应在用户回执中说明。

### 7.3 资产展开规则

`/sdd:init` 在选择模板包后，必须将所选模板包中的四类文档模板完整展开到项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`。

展开规则：

- 只补齐缺失文件，不覆盖项目已有模板定制。
- 支持重复执行以恢复缺失资产。
- 不自动替换用户已经存在的另一种风格模板。

### 7.4 重复执行时的行为

如果项目已经存在 `.sdd/templates/`：

- `/sdd:init` 默认只恢复缺失文件。
- 即使用户再次选择了另一种风格，也不自动整体覆盖现有模板。
- 如果未来要支持“从 backend 切换到 frontend”，应作为独立能力设计，不纳入本次版本。

### 7.5 不记录模板包选择元数据

本次版本不要求把“用户最初选择了 frontend 还是 backend”写入项目元数据文件。运行时以 `.sdd/templates/` 的实际内容为准，而不是以一个额外配置值为准。

## 8. Unified Skill Contract Style

### 8.1 推荐统一章节骨架

四个文档生成 skill 的 `SKILL.md` 应统一采用以下章节骨架：

```md
## Preconditions
## Dialogue
## Template Assets
## Output
## Review Flow
## Boundaries
```

`research` 可以把 `## Review Flow` 替换为更贴切的：

- `## Relationship with PRD / spec`
- `## Boundaries`

但整体风格、路径表达和语言应保持一致。

### 8.2 `Template Assets` 章节合同

每个文档生成 skill 都必须在 `Template Assets` 章节中明确写出：

1. 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/` 下的模板与标准。
2. 运行前必须要求必要文件存在且可读。
3. 缺失时直接失败，并提示重新执行 `/sdd:init`。
4. 不降级到 plugin 内置资产。
5. plugin 模板包只由 `/sdd:init` 使用，不由运行时直接读取。

### 8.3 中文风格约束

统一要求：

- 技能说明、失败行为、边界说明、章节标题和交互语义以中文为主。
- 仅保留英文的部分包括：命令名、路径、变量名、固定技术标识。
- 相同概念在不同 skill 中使用一致术语，例如“项目模板资产”“运行时模板”“模板包”“缺失时直接失败”。

## 9. Per-Skill Behavioral Rules

### 9.1 `/sdd:research`

正式定位：

- 属于文档生成类 skill。
- 使用 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/`。
- 输出到 `docs/requirements/`。
- 不要求 active version。
- 不进入 version lifecycle。
- 不自动修改 `prd/spec/plan`。
- 写入完成并通过最小结构校验后，自动触发 `quality` reviewer。
- 手工修改后可通过 `/sdd:review` 重新执行 `quality` 复审。
- 不接入 `feasibility`。

### 9.2 `/sdd:prd`

规则：

- 必须要求 active version。
- 生成时只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/`。
- 缺失时直接失败，不降级到 plugin 资产。
- 写入完成并通过最小结构校验后，按既有设计触发 `quality` review。

### 9.3 `/sdd:spec`

规则：

- 必须要求 active version。
- 生成时只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/`。
- 缺失时直接失败，不降级到 plugin 资产。
- 写入完成并通过最小结构校验后，按既有设计触发 `quality -> feasibility`。

### 9.4 `/sdd:plan`

规则：

- 必须要求 active version。
- 生成时只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/`。
- 缺失时直接失败，不降级到 plugin 资产。
- 写入完成并通过最小结构校验后，按既有设计触发 `quality -> feasibility`。

## 10. Research Template and Quality Design

### 10.1 `research` 的正式定位

`research` 的职责是产出可被后续 `PRD / spec / DR` 引用的上游研究资料，而不是需求文档、功能规格、实施计划或决策记录。

因此它应被定义为：

- 项目级文档
- 非版本级文档
- 非状态流转文档
- 上游参考资料文档

它回答的问题是：

- 为什么这个主题值得研究
- 研究过程中看了哪些来源
- 提炼出了哪些关键发现
- 存在哪些可选方案与取舍
- 对后续文档产生什么影响

### 10.2 `research/template.md` 默认结构

建议 `research` 默认模板采用“问题导向 + 证据归纳 + 建议输出”的结构：

```md
# Research: <topic>

- 日期：YYYY-MM-DD
- 主题：<topic>
- 目的：<why this matters>
- 适用范围：<which PRD/spec/DR this may inform>

## 1. 背景
## 2. 研究问题
## 3. 信息来源
## 4. 关键发现
## 5. 方案比较 / 取舍分析
## 6. 结论与建议
## 7. 对后续文档的影响
```

各章节语义：

- `## 1. 背景`：说明为什么要研究该主题、当前不确定性在哪里、要为谁服务。
- `## 2. 研究问题`：把主题拆成若干明确、可回答、可比较的问题。
- `## 3. 信息来源`：列出本次研究使用的文档、规范、代码、实验观察或外部资料，并说明其价值。
- `## 4. 关键发现`：逐条沉淀事实、观察或结论，并尽量可回溯到来源或分析过程。
- `## 5. 方案比较 / 取舍分析`：在存在多个可选方向时，显式写出比较与取舍。
- `## 6. 结论与建议`：给出明确建议，而不是只罗列观察结果。
- `## 7. 对后续文档的影响`：明确这份 research 将影响哪些 PRD、spec 或 DR，以及影响点是什么。

### 10.3 `research` 与其他文档类型的边界

必须明确：

- `research` vs `PRD`：`research` 回答“查到了什么、发现了什么、建议什么”；`PRD` 回答“产品要做什么、为什么做、目标是什么”。
- `research` vs `spec`：`research` 不定义正式功能行为、输入输出、异常规则；`spec` 才定义正式功能契约。
- `research` vs `plan`：`research` 不拆实施任务，不写测试执行步骤；`plan` 才定义技术方案、任务拆分与验证路径。
- `research` vs `DR`：`research` 提供决策输入；`DR` 记录正式决策及其状态。

### 10.4 `research/quality.standard.md` 作为 reviewer 正式标准

`research/quality.standard.md` 不只是静态写作说明，而是 `doc-reviewer` 在 `research -> quality` 路径下正式消费的标准文件。

因此它需要同时承载：

- 最小结构要求
- 检查项定义
- 评分维度与阈值
- 允许的自动修复范围
- 输出重点

对 `research` 而言，`quality.standard.md` 应重点约束：

- 研究问题是否明确
- 信息来源是否真实且有价值
- 关键发现是否可回溯到来源或分析过程
- 结论与建议是否清晰可复用
- 是否越界写成 `PRD / spec / plan / DR`

### 10.5 `research` 的引用关系规则

`research` 的引用关系采用“消费方正式落表”模型：

- `research` 文档自身不强制要求 `## 文档引用` 表。
- 当 `PRD` 或 `spec` 正式使用某份 `research` 时，必须在目标文档的 `## 文档引用` 表中记录：
  - 相对 Markdown link
  - `project:requirements/<file>.md`
  - 关系建议为 `derives_from` 或 `references`

这样可以保持统一引用模型，同时避免给 research 文档本身附加过重的流程契约负担。

### 10.6 `research` 的 reviewer 接入规则

`research` 接入 reviewer 后，规则如下：

- `research` 写入完成并通过最小结构校验后，自动触发 `quality` reviewer。
- `research` 支持用户在手工修改后通过 `/sdd:review` 重新执行 `quality` 复审。
- `research` 不接入 `feasibility`。
- reviewer 在处理 `research` 时，不得假设文档必须具备 `PRD / spec / plan` 的核心章节或统一 `## 文档引用` 表。
- `research` 的最小结构校验与 admission check 必须依据 `research/template.md` 与 `research/quality.standard.md` 执行，而不是复用其他文档类型的硬编码结构要求。

## 11. Doctor, README, and Packaging Alignment

### 11.1 `/sdd:doctor`

`/sdd:doctor` 需要把 `research` 一并纳入检查：

- plugin 内置模板包中的 `research` 资产是否完整。
- 项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/` 是否完整。
- 缺失时报告明确错误，并建议重新执行 `/sdd:init`。

### 11.2 README / TESTING

README 与 TESTING 需要同步体现：

- 文档生成类 skills 现在覆盖 `research / prd / spec / plan`。
- 运行时模板唯一来源是项目 `.sdd/templates/`。
- `/sdd:init` 支持 `backend` 模板风格，并为未来 `frontend` 扩展保留合同与结构。
- 重复执行 `/sdd:init` 只补齐缺失文件，不覆盖项目已有模板定制。

### 11.3 Packaging

package 产物必须包含：

- `assets/template-packs/backend/*`
- 与其配套的脚本、skill 合同和 doctor 检查逻辑

若目录结构中预留 `frontend/`，本次版本不要求 package 中提供完整 `frontend` 模板内容。

## 12. Testing Strategy

### 12.1 必改测试

1. `tests/test-skill-contracts.sh`
   - 验证 `research` 显式读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/`
   - 验证 `research` 不再引用 `skills/research/references/research.md.tmpl`
   - 验证 `plan` 不再引用 `skills/plan/references/plan.md.tmpl`
   - 验证四个文档生成 skill 的章节骨架、路径风格和中文合同表述一致

2. `tests/test-template-assets.sh`
   - 增加 `research` 目录复制与缺失恢复验证
   - 增加 `backend` 模板包选择后的资产展开验证

3. `tests/test-template-runtime-contract.sh`
   - 增加 `research/template.md`
   - 增加 `research/quality.standard.md`
   - 验证运行时缺失时失败

4. `tests/test-doctor-contract.sh`
   - 增加 plugin 与项目两层的 `research` 资产完整性检查
   - 增加 `backend` 模板包矩阵检查

### 12.2 可考虑新增测试

建议增加一个专门的模板治理一致性测试，例如：

- 校验每个 template pack 都拥有四类文档的完整必需文件矩阵
- 校验不存在旧的 `skills/*/references/*.tmpl` 运行时依赖
- 校验 `/sdd:init` 的模板包选择语义与 README/skill 合同一致

## 13. Migration Rules

为避免再次出现半旧半新的状态，本次迁移应遵守：

1. 先统一 skill 合同，再调整模板资产与脚本。
2. 删除旧 references 时不保留并行兜底。
3. 先让 `research` 进入统一模板治理，并在本次迁移中接入 `quality reviewer`；`research` 不接入 `feasibility reviewer`。
4. 所有新增或修改文案保持中文统一风格。

## 14. Acceptance Criteria

以下条件全部满足时，本规格视为被正确实现：

1. `research / prd / spec / plan` 全部纳入统一模板治理模型。
2. plugin 内置模板统一位于 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/<pack>/`。
3. 运行时模板统一位于 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/`。
4. `/sdd:init` 支持模板风格选择；本次版本实际落地 `backend`，并为未来 `frontend` 扩展保留合同与结构。
5. 如果用户未显式选择，`/sdd:init` 会使用默认模板包。
6. `/sdd:init` 选择结果会决定 `.sdd/templates/` 的初始内容。
7. 重复执行 `/sdd:init` 时只补齐缺失文件，不自动将项目从一种模板风格切换到另一种。
8. 文档生成 skills 在运行时只读取项目 `.sdd/templates/`，不回退到 plugin 资产。
9. `research` 不再依赖 `skills/research/references/research.md.tmpl`。
10. `plan` 不再保留 `skills/plan/references/plan.md.tmpl` 作为运行时模板来源。
11. 四个文档生成 skills 的 `SKILL.md` 采用一致的章节风格、路径变量风格与中文合同风格。
12. `/sdd:doctor`、README、TESTING 和自动化测试都与新的模板治理模型保持一致。
13. `research/template.md` 具备背景、研究问题、信息来源、关键发现、方案比较 / 取舍分析、结论与建议、对后续文档的影响等明确章节结构。
14. `research/quality.standard.md` 至少包含完整性、证据性、清晰性、可复用性、非越界性五类质量维度。
15. `research` 文档自身不强制要求 `## 文档引用` 表，但消费方在正式引用时必须在目标文档中落入统一 `## 文档引用` 表。
16. 本次版本引入 `research` 的 `quality reviewer` 自动执行链路，但不引入 `research` 的 `feasibility reviewer` 执行链路。
17. 本次版本不引入运行时 fallback、`frontend` 实际模板内容或模板风格切换迁移能力。

## 15. Decision Summary

本规格采用以下设计立场：

- 文档模板的内容事实来源属于 template pack 与项目运行时模板，不属于 skill 目录。
- `/sdd:init` 是唯一模板物化入口，并承担模板风格选择职责。
- 本次版本实际只落地 `backend` 模板内容；`frontend` 仅保留为未来扩展方向。
- 模板风格选择发生在初始化阶段，而不是在文档生成阶段发生。
- `.sdd/templates/` 一旦生成，即成为 `research / prd / spec / plan / review` 的运行时唯一事实来源。
- `research` 被纳入统一模板治理，并接入 `quality reviewer` 自动执行链路；本次不接入 `feasibility reviewer`。
- 统一中文 skill 合同与显式路径边界，是本次版本的重要目标，而不是附带清理。
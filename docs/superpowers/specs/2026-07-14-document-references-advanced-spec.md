# SDD Plugin 设计规格：Document References Advanced

- 日期：2026-07-14
- 状态：approved
- 类型：Design Spec
- 目标：规范 SDD 文档之间的同版本引用、跨版本引用、证据链关系和归档汇总方式，让 spec、plan、DR 与 archive 能形成可追溯、低 Token、可维护的文档网络。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| modifies | DR 文档引用规则 | [2026-07-13-dr-advanced-spec.md](./2026-07-13-dr-advanced-spec.md) | - | 本规格把 DR Advanced 中的轻量 Markdown 链接规则升级为统一引用表和 locator 模型 |
| references | 实现影响范围 | [2026-07-13-dr-advanced-implementation.md](../plans/2026-07-13-dr-advanced-implementation.md) | - | 用于确认现有 DR Advanced 实现计划涉及的 skills、templates、README 和 contract tests |

## 1. Problem

SDD Plugin 已经逐步形成 PRD、spec、plan、DR、requirements、archive 等文档类型。DR Advanced 已经要求 spec、plan、DR 之间使用 Markdown 链接，Archive Advanced 曾要求归档版本提供 `INDEX.md` 和 `ARCHIVE.md` 作为入口。随着版本增多，现有规则还不能稳定回答以下问题：

- 新版本如何说明自己基于哪个历史版本、历史 spec 或历史 DR？
- 新 spec 如何证明某个变更来自旧 spec、旧 DR、当前 PRD 或当前 DR，而不是凭空生成？
- 同版本内 PRD、spec、plan、DR 如何互相引用，既方便人类点击，也方便 Agent 机械检查？
- 跨版本引用如何避免归档后路径失效？
- 引用关系如何支持追溯，但不让旧文档变成新事实来源？
- `/sdd:archive` 如何汇总这些引用关系，帮助后续任务低成本查证？

## 2. Goals

1. 定义 SDD 文档引用的基本单元：Markdown link、Document locator、Reference relation。
2. 统一同版本引用和跨版本引用规则。
3. 定义 `## 文档引用` 表，作为结构化引用关系的权威位置。
4. 定义引用关系枚举和引用方向策略，避免 plan、archive、index 越权改变契约。
5. 定义引用检查规则，区分 blocking 和 warning。
6. 定义状态文件归档模型，让归档不再移动版本目录。
7. 定义 `/sdd:archive` 如何生成版本 `ARCHIVE.md`、更新 `state.json`、更新全局 `docs/archive/INDEX.md`。
8. 保持 file-driven 模型，不引入集中式 `.sdd/state.json` 或外部状态数据库。
9. 控制 archive 入口和引用摘要的 Token 成本，让包含 20-50 个 Markdown 文件的版本仍可快速定位和查证。

## 3. Non-goals

本规格不要求实现：

- 自动理解代码 diff 并生成完整 release notes。
- 自动修复失效链接。
- 自动迁移所有历史版本和历史 DR。
- 自动把正文 Markdown 链接推断成正式引用关系。
- 强制所有 project-level requirements 使用 `## 文档引用` 表。
- 建立全局关系图、全局决策索引或跨版本引用数据库。
- 引入 wiki link、transclusion、`!INCLUDE` 等非标准 Markdown 语法。
- 引入集中式 `.sdd/state.json`。
- 在 `/sdd:archive` 中移动版本目录。
- 在归档阶段修改 spec、plan、DR 的正文或状态字段。

## 4. Current Document Model

Document References Advanced 采用状态文件模型作为后续设计基础。新系统的版本目录统一放在 `docs/versions/vX.Y.Z/` 下。

```text
docs/
├── CONSTITUTION.md
├── requirements/
├── versions/
│   └── vX.Y.Z/
│       ├── state.json
│       ├── prd.md
│       ├── ARCHIVE.md            # archived 后生成
│       ├── specs/*.md
│       ├── plans/*.md
│       └── decisions/*.md
└── archive/
    └── INDEX.md
```

规则：

- `docs/requirements/` 是项目级输入资料库，保存用户反馈、业务规则、调研记录、外部约束等原始需求来源。
- `docs/versions/vX.Y.Z/prd.md` 是版本级产品入口，用于表达该版本的产品目标、范围、非目标和成功标准。
- 一个版本级 `prd.md` 可以派生多个 `specs/*.md`。
- `specs/*.md` 是当前版本的功能契约来源。
- `plans/*.md` 是实现计划，不单独改变功能契约。
- `decisions/*.md` 是决策记录，可解释来源、替代关系、争议点和变更原因。
- `ARCHIVE.md` 是单版本归档入口，在归档时生成。
- `docs/archive/INDEX.md` 是全局归档入口。
- 本规格中 `docs/archive/` 只定义一个必选文件：`INDEX.md`。

### 4.1 Migration Boundary

本规格采用一次切换边界：新系统只支持 `docs/versions/vX.Y.Z/` 版本目录模型，不再把 `docs/vX.Y.Z/` 作为当前结构、兼容结构或 fallback 结构。

规则：

- `/sdd:init` 创建 `docs/versions/`，但不创建任何版本目录或版本级 `state.json`。
- `/sdd:new` 只创建 `docs/versions/vX.Y.Z/`。
- 主流程 skill 只通过 `docs/versions/v*/state.json` 发现 active version。
- `/sdd:archive` 只处理 `docs/versions/vX.Y.Z/` 下的版本目录。
- `/sdd:doctor` 可以把 `docs/vX.Y.Z/` 识别为旧草案结构并提示，但不需要自动迁移。
- 旧草案结构不参与 active version 发现，也不阻止 `/sdd:new`；只有 `docs/versions/v*/state.json` 的一致性错误才阻止主流程创建或执行。
- 本规格不要求提供旧目录自动迁移命令。
- README、templates、contract tests、fixtures、hooks、发布包文档都应使用 `docs/versions/vX.Y.Z/`。
- 文档中出现 `docs/vX.Y.Z/` 时，只能作为旧设计说明或反例出现，不能作为当前推荐路径。

## 5. Design Principles

### 5.1 最新 spec 是当前事实来源

新版本 spec 永远代表当前版本的最新功能契约。引用旧文档的目的不是让旧文档继续成为当前事实来源，而是形成证据链：说明当前 spec、plan 或 DR 的前因后果。

规则：

- 引用关系是证据链和上下文入口。
- 引用关系不是事实正文。
- `modifies`、`replaces`、`deprecates` 等关系不能替代当前文档正文。
- 当前 spec / DR 必须在正文中写清楚当前版本最终采用的事实、约束或决策。

### 5.2 不强制双向引用

文档引用不强制双向维护。

原因：双向引用会带来更新同步问题，容易出现 A 更新但 B 未更新的漂移。

规则：

- 关系由后续节点或产生关系的一侧声明。
- 旧归档文档不因新版本引用而被修改。
- 如果两边都声明了关系，不能互相矛盾。

### 5.3 引用方向必须符合文档职责

引用允许查证和追溯，但不能越权改变契约。

规则：

- spec 通常引用导致 spec 变更或做出决定的文档，例如 PRD、requirements、DR、旧版本 spec、同版本其他 spec。
- spec 通常不引用 plan，因为 plan 是 spec 的实现，不是 spec 的依据。
- plan 可以引用同版本 spec、同版本 DR、同版本其他 plan、旧版本 plan 或旧版本 DR，作为实现依据。
- DR 可以引用 requirements、同版本 PRD、旧版本 PRD、同版本 spec、旧版本 spec、同版本 plan、同版本 DR 或旧版本 DR，作为决策依据或替代对象。
- plan 如果发现需要改变契约，必须通过 spec 或 DR 表达，而不是只在 plan 的引用表中表达。

## 6. Version State Model

版本目录不因归档而移动，归档状态由每个版本目录内的 `state.json` 表达。

最小 `state.json` 结构：

```json
{
  "version": "vX.Y.Z",
  "state": "active",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "archived_at": null
}
```

字段规则：

- `version` 必须与版本目录名一致。
- `state` 初始只允许 `active` 或 `archived`。
- 项目在可执行主流程状态下必须恰好存在一个 `state: active` 的版本。
- `/sdd:archive` 成功后允许项目处于 0 active version 状态，直到用户运行 `/sdd:new` 创建下一版本。
- 0 active version 状态下，依赖 active version 的 skill 必须阻止执行，并提示用户运行 `/sdd:new`。
- 可以存在多个 `state: archived` 的版本。
- `created_at` 记录版本目录创建时间。
- `archived_at` 在 `state: active` 时为 `null`，在 `state: archived` 时记录归档时间。
- `state.json` 只表达版本生命周期状态：`active` / `archived`。
- spec、plan、DR 的工作流状态仍以各 Markdown 文档头部状态字段为准。
- 不得把 spec / plan / DR 状态迁移到 `state.json`，也不得用 `state.json` 替代文档头部状态检查。

归档后的 `state.json` 示例：

```json
{
  "version": "v0.3.0",
  "state": "archived",
  "created_at": "2026-07-14T00:00:00Z",
  "archived_at": "2026-07-14T12:00:00Z"
}
```

状态文件模型仍然属于 file-driven 模型：状态与版本文档放在同一版本目录内，不引入集中式 `.sdd/state.json` 或外部状态数据库。

Active version 发现规则：

1. 扫描 `docs/versions/v*/state.json`。
2. 解析每个 `state.json` 的 `version` 和 `state`。
3. 要求目录名与 `state.json.version` 一致。
4. 可执行主流程状态下要求恰好一个版本为 `state: active`。
5. `/sdd:archive` 成功后允许 0 个 active version；此时依赖 active version 的 skill 必须阻止执行，并提示用户运行 `/sdd:new`。
6. 允许多个版本为 `state: archived`。
7. 如果存在多个 active version，应阻止依赖 active version 的 skill，并提示用户运行诊断或修复流程。
8. 如果某个版本目录缺失 `state.json`、JSON 无法解析、`version` 不匹配或 `state` 非法，应视为项目一致性问题。

## 7. Reference Model

每条文档引用由三层信息组成：

```text
Markdown link        负责人类可点击跳转
Document locator     负责机器稳定识别目标文档
Reference relation   负责表达引用语义
```

规则：

- Markdown link 是必选基本单元，用于人类阅读、编辑器跳转和文件级链接检查。
- Reference relation 是必选语义字段，用于说明引用关系。
- Document locator 是可选增强字段，用于同版本引用中需要被机器长期追踪的场景。
- 跨版本引用和 project-level requirements 引用必须填写 locator。
- locator 不替代 Markdown link。
- 如果 Markdown link 和 locator 同时存在，二者必须指向同一个目标文档。
- 同版本引用默认只需要 Markdown link 和 relation。
- 跨版本引用必须同时写 Markdown link 和 locator。
- project-level requirements 引用必须同时写 Markdown link 和 `project:` locator。
- 章节引用不作为 locator 的必选部分；章节号、章节标题或说明文字可以放在 `当前范围` 或 `说明` 字段中。

基本单元可以表达为：

```text
relation + target Markdown link + locator when required + scope + note
```

示例：

```markdown
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| derives_from | archive workflow | [prd.md](../prd.md) | - | 本 spec 覆盖 PRD 中的归档增强目标 |
```

Locator 示例：

```text
v0.2.0:specs/archive.md
v0.3.0:prd.md
v0.3.0:decisions/feat-0001-archive-index.md
project:requirements/business-rules.md
```

Locator 的作用是稳定识别，不负责点击跳转；Markdown link 的作用是点击跳转，不单独表达引用语义。

## 8. Same-version References

同版本引用统一使用 Markdown 相对链接。

规则：

- 同版本引用必须使用相对 Markdown link。
- 不使用 repo-root path，例如不写 `docs/versions/vX.Y.Z/specs/archive.md`。
- 默认不要求 Document locator。
- 如果某条同版本引用需要被机器长期追踪，可以额外写 locator，但不是默认要求。
- 链接目标以文件级为主，不强制 Markdown anchor。
- 章节号、章节标题或说明文字放在链接后，或放在引用表的 `当前范围` / `说明` 字段中。

解析规则：

- 所有同版本 Markdown 相对链接都以来源文档所在目录作为 base path 解析。
- Agent 检查链接时，必须用 `source_file.parent / link_target` 解析目标。
- 禁止把相对链接按 repo root 解析。
- 禁止把相对链接按当前命令执行目录解析。
- 链接文本应使用稳定文档名、plan 文件名或 DR ID，不依赖标题文本。
- 文件移动或重命名时，产生该变更的一侧必须同步更新已知引用。

示例：

| 来源文件 | 目标 | 写法 |
| -------- | ---- | ---- |
| `specs/archive.md` | `prd.md` | `[prd.md](../prd.md)` |
| `specs/archive.md` | `decisions/feat-0001-archive.md` | `[feat-0001-archive](../decisions/feat-0001-archive.md)` |
| `plans/001-archive.md` | `specs/archive.md` | `[archive.md](../specs/archive.md)` |
| `decisions/feat-0001-archive.md` | `plans/001-archive.md` | `[001-archive.md](../plans/001-archive.md)` |
| `prd.md` | `specs/archive.md` | `[archive.md](./specs/archive.md)` |
| `specs/archive.md` | `specs/document-references.md` | `[document-references.md](./document-references.md)` |

解析示例：

```text
来源文件：docs/versions/v0.3.0/specs/archive.md
链接：[prd.md](../prd.md)
解析目标：docs/versions/v0.3.0/prd.md
```

```text
来源文件：docs/versions/v0.3.0/prd.md
链接：[archive.md](./specs/archive.md)
解析目标：docs/versions/v0.3.0/specs/archive.md
```

## 9. Cross-version References

跨版本引用使用 Markdown 相对链接，并必须同时填写 Document locator。

规则：

- 跨版本引用必须在 `目标文档` 中使用 Markdown 相对链接。
- 跨版本引用必须在 `目标标识` 中填写 locator。
- 不使用 repo-root path 作为 Markdown 链接写法。
- locator 格式为 `vX.Y.Z:<version-relative-path>`。
- locator 的路径以目标版本目录为根，不包含 `docs/versions/vX.Y.Z/` 前缀。
- project-level requirements 使用 `project:requirements/<file>.md`。
- Markdown link 和 locator 同时存在时，必须指向同一个目标文档。
- Agent 检查跨版本引用时，应先按 Markdown link 检查文件存在，再用 locator 验证版本和版本内路径一致。
- 章节号、章节标题或说明文字不进入 locator，继续放在 `当前范围` 或 `说明` 字段中。

当前文件：

```text
docs/versions/v0.4.0/specs/document-references.md
```

引用旧版本 spec：

```markdown
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| modifies | 文档引用模型 | [archive.md](../../v0.3.0/specs/archive.md) | v0.3.0:specs/archive.md | 本版本调整归档引用路径模型 |
```

引用旧版本 DR：

```markdown
| references | 状态文件归档 | [arch-0002-state-file-archive](../../v0.3.0/decisions/arch-0002-state-file-archive.md) | v0.3.0:decisions/arch-0002-state-file-archive.md | 作为状态文件模型的历史决策依据 |
```

引用 project-level requirement：

```markdown
| derives_from | 产品约束 | [business-rules.md](../../../requirements/business-rules.md) | project:requirements/business-rules.md | 该需求影响多个版本 |
```

Markdown link 负责点击跳转，locator 负责稳定表达版本和目标文档身份。二者互相补充，不能互相替代。

## 10. Document Template Principles

SDD 文档模板按职责分层设计。模板应让后续 plan 能直接识别用户行为、功能契约、决策来源、实现边界和验收规则，但不应让上游文档承担下游职责。

| 文档 | 核心职责 | 不该承担 |
| ---- | -------- | -------- |
| PRD | 说明版本为什么要做、面向谁、解决什么问题、产品目标和范围 | 不写实现方案，不拆任务，不描述代码细节 |
| Spec | 说明功能应该如何表现，包括行为、逻辑规则、输入输出、边界和验收 | 不写具体实现步骤，不分配文件任务，不写代码方案 |
| Plan | 把 approved spec 或 accepted code-class DR 转成可执行技术方案和任务 | 不改变功能契约，不新增需求，不替代 spec |
| DR | 记录一个决策、变更、争议或修复的原因、选择和后续路径 | 不直接替代 spec 正文，不直接执行 code |
| Research | 保存项目级调研、外部资料、用户反馈、业务规则等原始或半结构化输入 | 不作为正式 contract，不绑定单个 version |
| ARCHIVE.md | 汇总一个版本最终状态、入口、plan/DR、verification 和引用摘要 | 不创建新关系，不修改历史事实，不替代原文档 |
| INDEX.md | 提供全局 archived version 路由 | 不展开版本细节，不链接具体 spec、plan、DR |

模板规则：

- PRD、spec、plan、DR 必须使用统一 `## 文档引用` 表表达正式文档关系。
- Research 默认不强制使用 `## 文档引用` 表；当它主动声明 SDD 文档关系时，才使用该表。
- ARCHIVE.md 使用派生摘要表，不逐条复制统一引用表模板。
- INDEX.md 只作为 archived version 路由，不声明文档引用关系。
- 文档模板只定义文档应记录的信息，不嵌入 plugin command 编排。
- PRD、spec、DR、research、ARCHIVE.md、INDEX.md 模板不得要求写“下一步运行 `/sdd:*`”。
- Plan 模板可以包含任务结构和 agentic worker 执行提示，因为 plan 本身是执行文档；该提示不得出现在 PRD、spec、DR 或 research 模板中。
- 后续流程由 skill 行为根据文档状态和流程字段决定，不由模板正文驱动。
- 模板章节应保持简洁；复杂实现拆分、具体文件修改和验证命令属于 Implementation Plan。

### 10.1 Reference Table Template

spec、plan、DR、PRD 使用统一 5 列模板。

```markdown
## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
```

字段规则：

- `关系` 必填，取值由关系类型枚举定义。
- `当前范围` 必填，说明当前文档中受该引用影响的范围。
- `目标文档` 必填；除固定空集合行外，所有数据行的 `目标文档` 必须是 Markdown link。
- `目标标识` 可选；同版本引用可以写 `-`，跨版本引用和 project-level requirements 引用必须写 locator。
- `说明` 必填，简短说明引用原因，不复制目标文档正文。
- 不单独设置 `目标版本` 字段，版本信息由 locator 表达。
- 不单独设置 `目标章节` 字段，章节号和标题放入 `当前范围` 或 `说明`。
- `ARCHIVE.md` 可以使用派生摘要表，不要求逐条复制该模板。
- 无引用时使用固定行：`| 未声明。 | - | - | - | - |`。

位置规则：

- `## 文档引用` 放在文档元信息之后、主体正文之前。
- 该表是结构化引用关系的权威位置。
- 正文中可以保留 Markdown 链接，作为局部来源声明或阅读辅助。
- 正文链接不能替代 `## 文档引用` 表中的正式关系。
- 如果正文链接表达了证据链、契约来源、实现依据或决策依据，应同步写入 `## 文档引用` 表。
- `ARCHIVE.md` 可以把引用摘要放在自己的结构中，不要求同样位置。
- `CONSTITUTION.md` 和 project-level requirements 不强制使用该表，除非它们主动声明 SDD 文档关系。

推荐文档结构：

```markdown
# 文档标题

- 状态：draft
- 日期：YYYY-MM-DD

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 背景

## 目标
```

## 11. Relation Types

关系类型收敛为 6 个：

```text
references
derives_from
implements
modifies
replaces
deprecates
```

关系含义：

| 关系 | 含义 | 契约影响 |
| ---- | ---- | -------- |
| `references` | 普通参考、背景、上下文入口 | 无直接契约影响 |
| `derives_from` | 当前文档从目标文档派生、承接或细化 | 可能有契约影响 |
| `implements` | 当前文档是目标文档的实现计划或落地说明 | 不改变契约 |
| `modifies` | 当前文档修改目标文档中曾经定义的部分行为、约束或决策 | 有契约或决策影响 |
| `replaces` | 当前文档整体替代目标文档或目标决策 | 有强契约或决策影响 |
| `deprecates` | 当前文档声明目标内容仍可追溯，但不再推荐或不再作为后续依据 | 有弱到中等契约或决策影响 |

删除的候选关系：

- 不保留 `supports`，因为它容易混淆普通参考、证据支撑和实现依据；应按语义改用 `references`、`derives_from` 或 `implements`。
- 不保留 `updates`，统一用 `modifies` 表达部分修改，避免“更新”和“修改”重叠。
- 不保留 `inherits`，避免误导为旧 spec 内容会自动继承到新 spec；如果新文档基于旧文档，应使用 `derives_from`，并在当前文档正文中写清最终事实。

关系强度可以按以下方式理解：

```text
references -> derives_from -> modifies -> replaces
```

其中 `implements` 是实现关系，不在契约强度轴上；`deprecates` 表示目标内容不再推荐或不再作为后续依据。

规则：

- `references` 是默认弱关系。
- `derives_from` 表示来源、派生或细化，但不表示旧文档自动成为当前事实。
- `implements` 只能表示实现依据，不能改变功能契约。
- `modifies`、`replaces`、`deprecates` 不能替代当前文档正文。
- 当前 spec / DR 必须在正文中写清最终采用的事实、约束或决策。
- plan 不得使用 `modifies`、`replaces`、`deprecates` 来改变契约；如果 plan 发现契约需要变化，必须通过 spec 或 DR 表达。

## 12. Reference Direction Policy

| 来源文档 | 正常允许引用 | 限制 |
| -------- | ------------ | ---- |
| requirements | requirements | 不反向引用版本文档 |
| PRD | requirements、旧版本 PRD、旧版本 spec、同版本 DR、旧版本 DR | 不引用 plan |
| spec | PRD、requirements、同版本 DR、旧版本 DR、旧版本 spec、同版本其他 spec | 通常不引用 plan |
| plan | 同版本 spec、同版本 DR、同版本 plan、旧版本 plan、旧版本 DR | 默认不引用 requirements / PRD；如引用只能是背景 `references` |
| DR | requirements、同版本 PRD、旧版本 PRD、同版本 spec、旧版本 spec、同版本 plan、同版本 DR、旧版本 DR | 允许范围最宽，但必须说明原因 |
| ARCHIVE.md | 当前版本 PRD、spec、plan、DR、跨版本关系摘要 | 只汇总，不声明新关系 |
| INDEX.md | 各版本 ARCHIVE.md | 只做版本级路由 |

规则：

- requirements 是原始输入资料库，通常不反向引用版本文档。
- PRD 表达产品目标来源，可以引用 requirements、旧版本 PRD、旧版本 spec、同版本 DR 或旧版本 DR，但不引用实现计划。
- spec 引用产品来源、决策来源和历史契约；spec 不应通过引用 plan 来决定功能契约。
- plan 主要引用同版本 spec、同版本 DR、同版本 plan、旧版本 plan 和旧版本 DR 作为实现依据；plan 不应通过引用 requirements 或 PRD 绕过 spec。
- 如果 plan 确实需要引用 PRD 或 requirements，只能使用 `references` 作为背景，不得作为实现契约依据。
- DR 可记录决策背景、争议点、被替代对象或历史依据，因此允许范围最宽，但必须在 `说明` 中写清引用原因。
- ARCHIVE.md 是派生摘要，只汇总已有引用关系，不创建新的 `modifies`、`replaces`、`deprecates` 等语义关系。
- `ARCHIVE.md` 中“关键入口 / Plans / DRs”的 Markdown links 是导航链接，不属于正式 Reference relation。
- 只有 `ARCHIVE.md` 的 `文档引用摘要` 中从原始引用表复制出的行才是引用关系摘要；该摘要仍不成为新的权威关系。
- INDEX.md 只链接各版本 `ARCHIVE.md`，不链接具体 spec、plan、DR 或 requirements。
- 旧文档不因新文档引用而被修改。
- 矩阵内引用正常允许。
- 矩阵外弱引用只允许使用 `references`，且 `说明` 必须非空；归档时产生 warning，不阻止。
- 矩阵外强引用使用 `modifies`、`replaces`、`deprecates` 时属于 blocking。

## 13. Archive Reference Summary

`ARCHIVE.md` 新增 `文档引用摘要` 节，用于低 Token 汇总当前版本已经声明的重要引用关系。

章节位置：

```markdown
## 1. 版本摘要
## 2. 关键入口
## 3. Specs
## 4. Plans
## 5. DRs
## 6. 文档引用摘要
## 7. 验证摘要
## 8. 遗留事项
## 9. 已知限制 / 风险
```

职责规则：

- `INDEX.md` 不汇总文档引用关系，只做版本级路由。
- `ARCHIVE.md` 汇总引用关系，但不是新的事实来源。
- 完整引用关系仍以原始文档的 `## 文档引用` 表为准。
- `ARCHIVE.md` 不创造新的引用关系。
- `ARCHIVE.md` 不重新解释关系语义。
- `ARCHIVE.md` 不从正文 Markdown 链接推断新关系。

汇总范围：

- 必须汇总跨版本关系。
- 必须汇总 project-level requirements 关系。
- 必须汇总本版本强关系：`modifies`、`replaces`、`deprecates`。
- 同版本普通关系默认不逐条汇总。
- 同版本普通关系如对后续任务非常关键，可以由原始文档在 `说明` 中明确，并由归档摘要保守列出。

推荐模板：

```markdown
## 6. 文档引用摘要

### 6.1 跨版本与项目级关系

| 来源文档 | 关系 | 目标文档 | 目标标识 | 说明 |
| -------- | ---- | -------- | -------- | ---- |
| 未发现。 | - | - | - | - |

### 6.2 本版本强关系

| 来源文档 | 关系 | 目标文档 | 说明 |
| -------- | ---- | -------- | ---- |
| 未发现。 | - | - | - |
```

机械提取规则：

1. `/sdd:archive` 读取当前版本中已存在的 PRD、spec、plan、DR 的 `## 文档引用` 表。
2. 只读取引用表，不阅读全文解释。
3. 提取 `目标标识` 非 `-` 且匹配具体版本 locator（例如 `v0.3.0:`）或以 `project:` 开头的行，写入 `跨版本与项目级关系`。
4. 提取关系为 `modifies`、`replaces`、`deprecates` 的同版本行，写入 `本版本强关系`。
5. 不根据正文链接补推关系。
6. 不修正文档引用表中的语义。
7. 如果表格格式无法解析，保守写入：`未能机械提取；请查看原始文档。`
8. 如果没有匹配关系，使用固定空集合行：`未发现。`

Token 控制规则：

- 引用摘要只保留来源文档、关系、目标文档、目标标识和简短说明。
- 不复制目标文档正文。
- 不复制同版本所有普通引用。
- 对包含 20-50 个 Markdown 文件的版本，`文档引用摘要` 应保持可快速阅读。

## 14. Reference Validation

引用检查分为 blocking 和 warning 两级。

检查范围：

- 当前 active version 的 `prd.md`（如果存在）。
- 当前 active version 的 `specs/*.md`。
- 当前 active version 的 `plans/*.md`。
- 当前 active version 的 `decisions/*.md`。
- `/sdd:archive` 生成后的 `ARCHIVE.md`。
- `docs/archive/INDEX.md` 更新后的本次新增或修改链接。

检查对象：

- 本地相对 Markdown `.md` 链接。
- `## 文档引用` 表中的 `关系`、`目标文档`、`目标标识` 字段。
- `state.json` 中的版本状态一致性。

Blocking 检查失败时必须阻止归档：

- 本地相对 Markdown `.md` 链接目标不存在。
- 跨版本引用缺少版本 locator。
- project-level requirements 引用缺少 `project:` locator。
- `目标文档` 字段不是 Markdown link，固定空集合行 `| 未声明。 | - | - | - | - |` 除外。
- `目标标识` 非 `-` 但 locator 格式非法。
- Markdown link 与 locator 同时存在但指向不同目标文档。
- `关系` 不在关系类型枚举内。
- `## 文档引用` 表缺少关键列或无法解析。
- 矩阵外强引用使用 `modifies`、`replaces`、`deprecates`。
- plan 使用 `modifies`、`replaces`、`deprecates`。
- `ARCHIVE.md` 声明新引用关系，而不是汇总已有关系。
- `INDEX.md` 声明文档引用关系，或链接具体 spec、plan、DR 作为正式引用。
- active version 多于一个。
- 版本目录名和 `state.json.version` 不一致。
- `state.json.state` 不是允许值。
- `ARCHIVE.md` 生成后的链接检查失败。

Warning 检查不阻止归档，但应在输出中提示：

- 矩阵外弱引用使用 `references` 且有说明。
- plan 引用 PRD 或 requirements 作为背景。
- spec 引用 plan。
- 同版本引用额外写 locator。
- 正文链接疑似表达证据链、契约来源、实现依据或决策依据，但未同步到 `## 文档引用` 表。
- `说明` 过短或不清楚。

正文链接 warning 只做启发式检查，不要求语义理解全文。启发式规则：当正文 Markdown link 所在行包含 `依据`、`来源`、`派生`、`修改`、`替代`、`决策`、`实现`、`implements`、`modifies`、`replaces`、`derives_from` 等关键词，且目标文档未出现在 `## 文档引用` 表时，提示 warning。

`说明` 过短规则：去除空白后少于 6 个中文字符或少于 3 个英文单词时 warning；仅包含 `参考`、`相关`、`见上`、`N/A`、`-` 等占位词时 warning。

Locator 检查规则：

对于版本 locator：

```text
v0.3.0:specs/archive.md
```

必须检查：

1. `docs/versions/v0.3.0/` 存在。
2. `docs/versions/v0.3.0/state.json` 存在且可解析。
3. `state.json.version` 是 `v0.3.0`。
4. `docs/versions/v0.3.0/specs/archive.md` 存在。
5. Markdown link 解析出的目标路径与 locator 指向同一文件。

对于 project locator：

```text
project:requirements/business-rules.md
```

必须检查：

1. `docs/requirements/business-rules.md` 存在。
2. Markdown link 解析出的目标路径与 locator 指向同一文件。

不检查：

- 外部 URL。
- 代码文件链接。
- Markdown anchor。
- 非 `.md` 文件链接。

所有相对 Markdown link 都必须以来源文档所在目录作为 base path 解析。检查失败时应尽量输出来源文件、原始链接、解析目标和失败原因。

## 15. Archive Workflow

本规格吸收 Archive Advanced 的归档入口、摘要和检查目标，但将归档模型从目录移动改为状态文件模型。

继续保留的 Archive Advanced 规则：

- `docs/archive/INDEX.md` 是必选全局归档入口。
- 每个归档版本必须生成 `ARCHIVE.md`。
- `ARCHIVE.md` 是低 Token 路由层，不是新的事实来源。
- 归档时不修改 spec、plan、DR 的状态字段或正文。
- `prd.md` 是可选入口和可选摘要来源，缺失不阻止归档。
- 空集合和未知信息使用固定保守文案。
- verification 不作为归档阻塞条件，只汇总现有文档中明确记录的信息。

状态文件模型下，`/sdd:archive` 的目标结构为：

```text
docs/
├── versions/
│   └── vX.Y.Z/
│       ├── state.json
│       ├── prd.md
│       ├── ARCHIVE.md            # archived 后生成
│       ├── specs/*.md
│       ├── plans/*.md
│       └── decisions/*.md
└── archive/
    └── INDEX.md
```

前置条件：

1. `docs/CONSTITUTION.md` 存在。
2. `docs/versions/` 存在。
3. 运行 `/sdd:archive` 前必须恰好存在一个 `state: active` 的版本。
4. active version 的目录名与 `state.json.version` 一致。
5. active version 的 `specs/*.md` 至少存在一份，且所有 `specs/*.md` 状态均为 `approved`。
6. 所有 `plans/*.md` 都处于终态。当前 plan 终态为 `done`；没有 plan 时视为通过该条件。
7. 所有 DR 都处于终态。当前 DR 终态为 Markdown 头部状态 `closed`；`dismissed` 通过 `closed_reason: dismissed` 表达，`superseded` 只能通过 `superseded_by: <DR link or ID>` 表达。发现 `drafting`、`accepted`、`dismissed`、`superseded` 或其他非法状态值时应阻止归档并提示未知或未完成状态。
8. active version 内不存在 `ARCHIVE.md`，或用户明确允许覆盖。
9. Blocking 引用检查通过。
10. 在允许条件下能成功生成 `ARCHIVE.md`。

执行流程：

1. 扫描 `docs/versions/v*/state.json`，解析唯一 active version。
2. 执行归档前置条件检查。
3. 从 PRD、spec、plans、DR 中提取归档摘要信息。
4. 从 PRD、spec、plans、DR 的 `## 文档引用` 表机械提取 `文档引用摘要`。
5. 在 active version 目录内生成或覆盖 `ARCHIVE.md`。
6. 检查生成后的 `ARCHIVE.md` 中本地相对 Markdown `.md` 链接。
7. 将该版本 `state.json.state` 从 `active` 改为 `archived`，并写入 `archived_at`。
8. 创建或更新 `docs/archive/INDEX.md`。
9. 检查 `docs/archive/INDEX.md` 本次新增或修改的本地相对 Markdown `.md` 链接。
10. 输出归档结果、版本 `ARCHIVE.md` 路径和全局 `INDEX.md` 路径。

`ARCHIVE.md` 模板：

```markdown
# Archive：vX.Y.Z

- 状态：archived
- archived_at：YYYY-MM-DDTHH:MM:SSZ
- source_version：docs/versions/vX.Y.Z
- archive_entry：docs/archive/INDEX.md

## 1. 版本摘要

<用 3-7 行说明该版本最终完成了什么。>

## 2. 关键入口

| 类型 | 链接 | 说明 |
| ---- | ---- | ---- |
| PRD | <存在时 [prd.md](./prd.md)，否则 未发现。> | 产品目标与范围 |
| Spec | <至少一份 spec 链接> | 功能契约 |
| Plans | [plans/](./plans/) | 实施记录 |
| DRs | [decisions/](./decisions/) | 决策记录 |

## 3. Specs

| Spec | 状态 | 摘要 |
| ---- | ---- | ---- |

## 4. Plans

| Plan | 状态 | 关联来源 | 验证摘要 |
| ---- | ---- | -------- | -------- |

## 5. DRs

| DR | class | tag | 状态 | 摘要 |
| -- | ----- | --- | ---- | ---- |

## 6. 文档引用摘要

<按 Archive Reference Summary 规则，从 PRD、spec、plan、DR 的 `## 文档引用` 表派生生成。>

## 7. 验证摘要

<只汇总现有 plan / DR 中明确记录的 verification 信息；无法确认时使用固定保守文案。>

## 8. 遗留事项

<基于现有文档生成，不改变已批准语义，不创建新任务。>

## 9. 已知限制 / 风险

<基于现有文档生成；无法确认时使用固定保守文案。>
```

ARCHIVE.md 模板职责：

- `ARCHIVE.md` 是 version-level summary，来源是当前 version 内已经存在的 PRD、spec、plan、DR 和 `state.json`。
- `版本摘要` 只总结已经完成或明确记录的版本结果。
- `关键入口` 提供人类导航入口，不表达正式引用关系。
- `Specs` 汇总该版本的 approved/draft spec 状态和摘要。
- `Plans` 汇总 plan 状态、关联来源和验证摘要，不替代 plan 正文。
- `DRs` 汇总 DR 类型、状态和摘要，不替代 DR 正文。
- `文档引用摘要` 只能从原始文档的 `## 文档引用` 表派生，不得新增、删除或修正关系。
- `验证摘要` 只能引用已有 verification 记录；缺失时必须保守表达为“未发现明确验证记录”。
- `遗留事项` 只能来自现有文档中的开放问题、未完成项或风险，不创建新的需求或任务。
- `ARCHIVE.md` 不使用统一 `## 文档引用` 表作为正式关系来源；它使用派生摘要表。

`docs/archive/INDEX.md` 规则：

- `INDEX.md` 是全局归档入口。
- `INDEX.md` 每个 archived version 最多一行。
- `INDEX.md` 链接到 `../versions/vX.Y.Z/ARCHIVE.md`。
- `INDEX.md` 不重复 plan、DR、verification 或引用关系细节。
- `INDEX.md` 不链接具体 spec、plan、DR 或 requirements。
- 如果 `INDEX.md` 不存在，`/sdd:archive` 必须创建它。
- 如果 `INDEX.md` 已存在，`/sdd:archive` 必须插入或更新当前版本对应行，并保持每个版本最多一行。

`INDEX.md` 模板：

```markdown
# SDD Archive Index

本文件是 archived versions 的全局入口。每个 archived version 最多一行，详情见对应版本的 `ARCHIVE.md`。

| 版本 | 归档时间 | 摘要 | 入口 |
| ---- | -------- | ---- | ---- |
| vX.Y.Z | YYYY-MM-DDTHH:MM:SSZ | <一句话摘要> | [ARCHIVE.md](../versions/vX.Y.Z/ARCHIVE.md) |
```

INDEX.md 模板职责：

- `INDEX.md` 是 project-level archive routing document。
- 每个 archived version 最多一行。
- `入口` 只链接到 `../versions/vX.Y.Z/ARCHIVE.md`。
- `摘要` 只能是一句话版本摘要，不展开 plan、DR、spec、verification 或引用关系。
- `INDEX.md` 不使用统一 `## 文档引用` 表。
- `INDEX.md` 不链接具体 PRD、spec、plan、DR 或 requirements。
- 如果某个版本的 `ARCHIVE.md` 缺失，`INDEX.md` 不应伪造入口；应由 `/sdd:doctor` 或 archive 流程报告一致性问题。

错误处理：

- 前置条件失败时，停止归档，不生成 `ARCHIVE.md`，不修改 `state.json`，不更新 `INDEX.md`。
- `ARCHIVE.md` 生成失败时，停止归档，不修改 `state.json`，不更新 `INDEX.md`。
- `ARCHIVE.md` 链接检查失败时，停止归档，不修改 `state.json`，不更新 `INDEX.md`。
- `state.json` 更新失败时，归档失败，不更新 `INDEX.md`。
- `INDEX.md` 创建或更新失败时，整体归档结果不能算成功；此时版本可能已经进入 `archived` 状态，应提示用户修复全局入口。
- 本规格不要求自动回滚 partial state，也不要求实现 `/sdd:archive --repair-index`。

## 16. Skill Behavior Changes

### 16.1 `/sdd:init`

`/sdd:init` 负责创建项目级 SDD 骨架，不负责创建版本。

前置条件：

1. 检查 `docs/CONSTITUTION.md` 是否存在。
2. 如果 `docs/CONSTITUTION.md` 已存在，停止并提示项目已经初始化。

执行规则：

1. 运行 `scripts/install-deps.sh`；如果依赖安装失败，停止并提示用户手动运行该脚本。
2. 创建项目级目录：
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
3. 复制 `CONSTITUTION.default.md` 到 `docs/CONSTITUTION.md`。
4. 不创建 `.sdd/state.json`。
5. 不创建任何 `docs/versions/vX.Y.Z/`。
6. 不创建任何版本级 `state.json`。
7. 不创建 `prd.md`、`specs/*.md`、`plans/*.md` 或 `decisions/*.md`。
8. 不修改 `CLAUDE.md` 或 `AGENTS.md`。

输出中应报告已创建或确认存在的项目级路径：

```text
docs/CONSTITUTION.md
docs/requirements/
docs/versions/
docs/archive/
```

状态语义：

- `/sdd:init` 完成后，项目允许处于 0 active version 状态。
- 需要 active version 的 skill 在该状态下必须阻止执行，并提示用户运行 `/sdd:new vX.Y.Z`。
- `/sdd:init` 不接受版本号参数；第一个版本必须由用户通过 `/sdd:new vX.Y.Z` 显式创建。

### 16.2 `/sdd:new`

`/sdd:new` 负责创建新的唯一 active version。

参数规则：

- 必须接收一个版本号参数。
- 版本号必须匹配 `^v[0-9]+\.[0-9]+\.[0-9]+$`。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户先运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示项目结构不完整，先运行 `/sdd:init` 或 `/sdd:doctor`。
3. 目标目录 `docs/versions/vX.Y.Z/` 不得已存在。
4. 扫描 `docs/versions/v*/state.json`。
5. 如果存在一个 `state: active`，停止，并提示用户先运行 `/sdd:archive`。
6. 如果存在多个 `state: active`，停止，并提示用户运行 `/sdd:doctor`。
7. 如果存在 0 个 active version，且没有其他版本一致性错误，允许创建新版本。
8. 如果任一版本目录缺失 `state.json`、JSON 无法解析、`version` 与目录名不一致或 `state` 非法，停止，并提示用户运行 `/sdd:doctor`。

执行规则：

创建：

```text
docs/versions/vX.Y.Z/
docs/versions/vX.Y.Z/state.json
docs/versions/vX.Y.Z/specs/
docs/versions/vX.Y.Z/plans/
docs/versions/vX.Y.Z/decisions/
```

初始 `state.json` 内容：

```json
{
  "version": "vX.Y.Z",
  "state": "active",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "archived_at": null
}
```

不创建：

```text
docs/versions/vX.Y.Z/prd.md
docs/versions/vX.Y.Z/specs/*.md
docs/versions/vX.Y.Z/plans/*.md
docs/versions/vX.Y.Z/decisions/*.md
.sdd/state.json
```

输出中应报告已创建的版本级路径：

```text
docs/versions/vX.Y.Z/
docs/versions/vX.Y.Z/state.json
docs/versions/vX.Y.Z/specs/
docs/versions/vX.Y.Z/plans/
docs/versions/vX.Y.Z/decisions/
```

状态语义：

- `/sdd:new` 不通过目录数量判断 active version，只通过 `docs/versions/v*/state.json` 判断。
- `/sdd:new` 是从 0 active version 状态进入 1 active version 状态的唯一主流程入口。
- `/sdd:new` 不修改任何已存在版本的 `state.json`。

### 16.3 `/sdd:status`

`/sdd:status` 负责展示 SDD 项目的当前生命周期状态、active version 内容概览和下一步建议。它是轻量状态查看入口，不是完整诊断或修复工具。

执行流程：

1. 读取 `docs/CONSTITUTION.md`。
2. 如果 `docs/CONSTITUTION.md` 缺失，输出项目未初始化，建议 `/sdd:init`，然后停止。
3. 检查 `docs/versions/` 是否存在。
4. 如果 `docs/versions/` 缺失，输出项目结构不完整，建议 `/sdd:init` 或 `/sdd:doctor`，然后停止。
5. 扫描 `docs/versions/v*/state.json`。
6. 如果发现任一版本目录缺失 `state.json`、JSON 无法解析、`version` 与目录名不一致或 `state` 非法，输出一致性错误，建议 `/sdd:doctor`，然后停止。
7. 如果发现 0 active version：
   - 输出项目已初始化。
   - 输出 `Active version：未发现`。
   - 如果存在 archived versions，列出 archived version 的版本号和 `archived_at`。
   - 输出下一步建议：`/sdd:new vX.Y.Z`。
   - 不扫描 `prd.md`、`specs/`、`plans/` 或 `decisions/`。
8. 如果发现 1 active version：
   - 输出 active version 路径，例如 `docs/versions/v0.3.0/`。
   - 输出 version state：`active`。
   - 检查 `prd.md` 是否存在。
   - 扫描 `specs/*.md`，列出每个 spec 文件及其 Markdown 头部状态。
   - 扫描 `plans/*.md`，列出每个 plan 文件及其 Markdown 头部状态。
   - 扫描 `decisions/*.md`，按 DR Markdown 头部状态分组列出 `drafting`、`accepted`、`closed`。
   - 对 `closed` DR，如果存在 `closed_reason` 或 `superseded_by`，在输出中展示。
   - 输出下一步建议。
9. 如果发现多个 active version：
   - 输出一致性错误。
   - 列出所有 active version。
   - 输出下一步建议：`/sdd:doctor`。
   - 不输出业务下一步建议。

输出示例，1 active version：

```text
SDD 状态

项目：已初始化
Active version：docs/versions/v0.3.0
Version state：active

PRD：存在

Specs：
- archive.md：approved
- document-references.md：draft

Plans：
- 001-archive.md：done

DRs：
- drafting：arch-0002-state-file
- accepted：fix-0003-link-check
- closed：doc-0004-update-readme（closed_reason: dismissed）

下一步建议：
- 完成 draft spec 后运行 /sdd:plan
```

输出示例，0 active version：

```text
SDD 状态

项目：已初始化
Active version：未发现

Archived versions：
- v0.2.0：2026-07-14T12:00:00Z

下一步建议：
- /sdd:new vX.Y.Z
```

输出示例，一致性错误：

```text
SDD 状态

项目：已初始化
一致性错误：
- 发现多个 active version：v0.3.0, v0.4.0

下一步建议：
- /sdd:doctor
```

边界规则：

- `/sdd:status` 不修复 `state.json`。
- `/sdd:status` 不创建版本。
- `/sdd:status` 不归档版本。
- `/sdd:status` 不检查 Markdown links。
- `/sdd:status` 不检查引用表语义。
- `/sdd:status` 不诊断源码一致性。
- `/sdd:status` 不读取 git log。

### 16.4 `/sdd:doctor`

`/sdd:doctor` 负责诊断插件安装完整性、项目结构一致性、版本生命周期状态、基础文档状态关系和引用结构问题。它是只读诊断入口，不自动修复。

检查范围：

1. Plugin installation
2. Project structure
3. Version state
4. Active version documents
5. Plan / DR consistency
6. Archive index
7. Reference tables

Plugin installation 检查规则：

- 检查核心插件文件是否存在：
  - `.claude-plugin/plugin.json`
  - `skills/init/SKILL.md`
  - `skills/new/SKILL.md`
  - `skills/research/SKILL.md`
  - `skills/prd/SKILL.md`
  - `skills/spec/SKILL.md`
  - `skills/plan/SKILL.md`
  - `skills/code/SKILL.md`
  - `skills/dr/SKILL.md`
  - `skills/triage/SKILL.md`
  - `skills/status/SKILL.md`
  - `skills/doctor/SKILL.md`
  - `skills/archive/SKILL.md`
  - `hooks/hooks.json`
  - `scripts/install-deps.sh`
  - `scripts/hooks/pre-tool-use.sh`
  - `scripts/lib/sdd-common.sh`
  - `CONSTITUTION.default.md`
- 检查依赖是否可达：
  - `superpowers`
  - `spec-kit`

Project structure 检查规则：

- 检查 `docs/CONSTITUTION.md` 是否存在。
- 检查 `docs/requirements/` 是否存在。
- 检查 `docs/versions/` 是否存在。
- 检查 `docs/archive/` 是否存在。
- 如果 `docs/CONSTITUTION.md` 缺失，报告项目未初始化并建议 `/sdd:init`，但仍可列出其他缺失项。

旧结构检查规则：

- 扫描 `docs/vX.Y.Z/`。
- 如果发现，报告为旧草案结构。
- 不自动迁移旧结构。
- 旧草案结构只作为 warning 输出，不参与 active version 发现。
- 旧草案结构不阻止 `/sdd:new`；是否人工整理旧目录由用户决定。
- 建议用户按当前模型整理到 `docs/versions/vX.Y.Z/`，或等待后续人工迁移指引。

Version state 检查规则：

- 扫描 `docs/versions/v*/`。
- 每个版本目录必须有 `state.json`。
- `state.json` 必须可解析为 JSON。
- `state.json.version` 必须等于版本目录名。
- `state.json.state` 只能是 `active` 或 `archived`。
- `created_at` 必须存在。
- `archived_at` 在 `state: active` 时必须是 `null`。
- `archived_at` 在 `state: archived` 时必须是非空字符串。
- 0 active version 合法，但应报告“当前无 active version”，并建议 `/sdd:new vX.Y.Z`。
- 1 active version 合法。
- 多 active version 是一致性错误。

Active version documents 检查规则：

- 仅当存在 1 active version 时执行。
- 检查 `specs/*.md` 状态行是否存在、可解析、值是否合法。
- 检查 `plans/*.md` 状态行是否存在、可解析、值是否合法。
- 检查 `decisions/*.md` 状态行是否存在、可解析、值是否合法。
- DR 状态只允许 `drafting`、`accepted`、`closed`。
- Markdown 头部状态为 `closed` 的 DR 应有 `closed_reason`。
- 如果 `superseded_by` 存在，值必须非空。
- `dismissed` 或 `superseded` 不是合法 DR 状态值，只能通过 `closed_reason`、`supersedes` 或 `superseded_by` 表达。

Plan / DR consistency 检查规则：

- 基于 active version 的 `plans/*.md` 和 `decisions/*.md` 执行。
- accepted code-class DR 中，`plan_required: yes` 的 DR 应有对应 plan。
- accepted lightweight fix DR（`tag: fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`）不要求对应 plan，应提示下一步 `/sdd:code <dr-id>`。
- done code-class DR plan 对应 DR 如果仍是 `accepted`，应报告该关系，作为后续关闭提示。
- 文件匹配规则沿用既有 DR Advanced 约定：plan 文件去掉 `NNN-` 前缀后与 DR slug 对应。

Archive index 检查规则：

- 检查 `docs/archive/INDEX.md` 是否存在。
- 对每个 `state: archived` 的版本，版本目录内应该有 `ARCHIVE.md`。
- `docs/archive/INDEX.md` 中每个 archived version 最多一行。
- 每个 archived version 的 INDEX 行应链接到 `../versions/vX.Y.Z/ARCHIVE.md`。
- `INDEX.md` 不应链接具体 spec、plan、DR 或 requirements。

Reference tables 检查规则：

- 对 active version 中已存在的 PRD、spec、plan、DR 做轻量引用结构检查。
- 检查 `## 文档引用` 表是否存在。
- 检查表头是否包含 5 列：`关系`、`当前范围`、`目标文档`、`目标标识`、`说明`。
- 检查关系值是否属于枚举：`references`、`derives_from`、`implements`、`modifies`、`replaces`、`deprecates`。
- 检查跨版本引用是否有版本 locator。
- 检查 project-level requirements 引用是否有 `project:` locator。
- `/sdd:doctor` 不生成 archive summary。
- `/sdd:doctor` 不修复链接。
- `/sdd:doctor` 不做正文链接启发式 warning；该检查属于 `/sdd:archive` 的前置引用检查。

输出规则：

- 按检查范围分组输出。
- 每组输出 `OK`、`WARNING` 或 `ERROR`。
- 最后输出下一步建议：
  - 未初始化：建议 `/sdd:init`。
  - 0 active version：建议 `/sdd:new vX.Y.Z`。
  - 多 active version 或 state 损坏：建议人工修复 `state.json`。
  - archive index 问题：建议修复 `docs/archive/INDEX.md`。
  - 引用表问题：建议修正文档引用表。

边界规则：

- `/sdd:doctor` 不自动创建或修改文件。
- `/sdd:doctor` 不修复 `state.json`。
- `/sdd:doctor` 不创建 active version。
- `/sdd:doctor` 不归档版本。
- `/sdd:doctor` 不生成 `ARCHIVE.md`。
- `/sdd:doctor` 不更新 `docs/archive/INDEX.md`。
- `/sdd:doctor` 不读取 git log。
- `/sdd:doctor` 不审计源码变更。
- `/sdd:doctor` 不机器解析 `docs/CONSTITUTION.md` 的 must/should 规则。
- `/sdd:doctor` 不做正文链接语义启发式扫描。

### 16.5 `/sdd:archive`

`/sdd:archive` 负责把唯一 active version 转为 archived 状态，生成版本归档入口，更新全局 archive index，并执行归档前引用检查。归档不移动版本目录。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示用户运行 `/sdd:init` 或 `/sdd:doctor`。
3. 运行 `/sdd:archive` 前必须恰好存在一个 `state: active` 的版本。
4. active version 的目录名必须与 `state.json.version` 一致。
5. active version 的 `state.json.state` 必须是 `active`。
6. active version 的 `state.json.archived_at` 必须是 `null`。
7. active version 的 `specs/*.md` 至少存在一份。
8. 所有 `specs/*.md` 的 Markdown 头部状态必须为 `approved`。
9. 所有 `plans/*.md` 的 Markdown 头部状态必须为 `done`；没有 plan 时通过。
10. 所有 `decisions/*.md` 的 Markdown 头部状态必须为 `closed`；没有 DR 时通过。
11. DR 不得使用 `dismissed` 或 `superseded` 作为状态值。
12. `prd.md` 缺失不阻止归档。
13. active version 内不存在 `ARCHIVE.md`，或用户明确允许覆盖。
14. Blocking 引用检查必须通过。
15. 在允许条件下能成功生成 `ARCHIVE.md`。

执行流程：

1. 扫描 `docs/versions/v*/state.json`，解析唯一 active version。
2. 执行归档前置条件检查。
3. 从 active version 的 PRD、spec、plans、DR 中提取归档摘要信息。
4. 从 PRD、spec、plans、DR 的 `## 文档引用` 表机械提取 `文档引用摘要`。
5. 在 active version 目录内生成或覆盖 `ARCHIVE.md`：

```text
docs/versions/vX.Y.Z/ARCHIVE.md
```

6. 检查生成后的 `ARCHIVE.md` 中本地相对 Markdown `.md` 链接。
7. 将该版本 `state.json.state` 从 `active` 改为 `archived`，保留 `created_at` 原值，并写入 `archived_at`。
8. 创建或更新 `docs/archive/INDEX.md`。
9. 检查 `docs/archive/INDEX.md` 本次新增或修改的本地相对 Markdown `.md` 链接。
10. 输出归档结果：归档版本、版本 `ARCHIVE.md` 路径、全局 `INDEX.md` 路径、当前项目处于 0 active version，以及下一步建议 `/sdd:new vX.Y.Z`。

归档后的 `state.json` 形态：

```json
{
  "version": "vX.Y.Z",
  "state": "archived",
  "created_at": "<原值>",
  "archived_at": "YYYY-MM-DDTHH:MM:SSZ"
}
```

Blocking 引用检查：

- 本地相对 Markdown `.md` 链接目标必须存在。
- 跨版本引用必须有版本 locator。
- project-level requirements 引用必须有 `project:` locator。
- locator 格式必须合法。
- Markdown link 和 locator 必须指向同一目标。
- 关系值必须属于枚举：`references`、`derives_from`、`implements`、`modifies`、`replaces`、`deprecates`。
- `## 文档引用` 表必须可解析。
- 矩阵外强引用属于 blocking。
- plan 使用 `modifies`、`replaces`、`deprecates` 属于 blocking。
- `ARCHIVE.md` 不得声明新引用关系。
- `INDEX.md` 不得声明文档引用关系，或链接具体 spec、plan、DR、requirements 作为正式引用。

Warning 引用检查：

- 矩阵外弱引用。
- plan 引用 PRD 或 requirements 作为背景。
- spec 引用 plan。
- 同版本引用额外写 locator。
- 正文链接启发式疑似证据链、契约来源、实现依据或决策依据，但未同步到 `## 文档引用` 表。
- `说明` 过短或不清楚。

错误处理：

- 前置条件失败时，停止归档，不生成 `ARCHIVE.md`，不修改 `state.json`，不更新 `INDEX.md`。
- `ARCHIVE.md` 生成失败时，停止归档，不修改 `state.json`，不更新 `INDEX.md`。
- `ARCHIVE.md` 链接检查失败时，停止归档，不修改 `state.json`，不更新 `INDEX.md`。
- `state.json` 更新失败时，归档失败，不更新 `INDEX.md`。
- `INDEX.md` 创建或更新失败时，整体归档结果不能算成功；此时版本可能已经进入 `archived` 状态，应提示用户运行 `/sdd:doctor` 或手动修复全局入口。
- 本规格不要求自动回滚 partial state。
- 本规格不要求实现 `/sdd:archive --repair-index`。

边界规则：

- `/sdd:archive` 不移动版本目录。
- `/sdd:archive` 不创建下一版本。
- `/sdd:archive` 不修改 spec、plan、DR 的 Markdown 头部状态或正文。
- `/sdd:archive` 不修复引用表。
- `/sdd:archive` 不修复 Markdown links。
- `/sdd:archive` 不根据正文链接生成正式引用关系。
- `/sdd:archive` 不读取 git log。
- `/sdd:archive` 不审计源码变更。
- `/sdd:archive` 不把 verification 作为归档阻塞条件，只汇总已有 verification 信息。

### 16.6 `/sdd:prd`

`/sdd:prd` 负责在唯一 active version 内创建或更新版本级 PRD，作为产品目标、范围和成功标准入口，并把 requirement 来源写入正式 `## 文档引用` 表。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示用户运行 `/sdd:init` 或 `/sdd:doctor`。
3. 必须恰好存在一个 `state: active` 的版本。
4. active version 的目录名必须与 `state.json.version` 一致。
5. active version 的 `state.json.state` 必须是 `active`。
6. 如果 0 active version，停止，并提示用户运行 `/sdd:new vX.Y.Z`。
7. 如果多个 active version 或 state 不一致，停止，并提示用户运行 `/sdd:doctor`。
8. 目标文件为 `docs/versions/vX.Y.Z/prd.md`。
9. 如果目标文件已存在，应先询问用户是覆盖、更新还是取消。

对话流程：

1. 扫描 `docs/requirements/*.md`。
2. 询问用户要引用哪些 requirement documents。
3. 对每个被选中的 requirement，在 `## 文档引用` 表中写一行正式引用：
   - `关系` 通常使用 `derives_from`。
   - `当前范围` 写产品目标、范围、成功标准或其他受影响范围。
   - `目标文档` 使用从 `prd.md` 到 requirement 的相对 Markdown link，例如 `[business-rules.md](../../requirements/business-rules.md)`。
   - `目标标识` 使用 `project:requirements/<file>.md`。
   - `说明` 用一句话说明该 requirement 如何影响 PRD。
4. 澄清产品背景、目标用户、痛点、业务目标、范围、成功标准、风险和假设。
5. 如果用户没有选择任何 requirement，`## 文档引用` 使用固定空集合行：`| 未声明。 | - | - | - | - |`。

输出路径：

```text
docs/versions/vX.Y.Z/prd.md
```

推荐模板结构：

```markdown
# PRD：<产品/版本名>

- 版本：vX.Y.Z
- 日期：YYYY-MM-DD

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 背景

## 2. 目标用户

## 3. 问题与目标

### 3.1 问题与痛点

### 3.2 产品目标

## 4. 范围

### 4.1 In Scope

### 4.2 Out of Scope

## 5. 成功标准

## 6. 风险与假设

## 7. 上游需求资料

| 路径 | 摘要 |
| ---- | ---- |
```

`## 文档引用` 与 `## 上游需求资料` 的职责边界：

- `## 文档引用` 是正式机器可检查引用关系。
- `## 上游需求资料` 是人类阅读摘要，可以列出 requirement 摘要。
- 如果某个 requirement 影响 PRD 的产品目标、范围、成功标准或其他契约内容，必须同时出现在 `## 文档引用`。
- 如果某个 requirement 只是阅读背景，允许只出现在 `## 上游需求资料`，但不得作为关键来源只写在那里。

边界规则：

- `/sdd:prd` 不创建 active version。
- `/sdd:prd` 不修改 `state.json`。
- `/sdd:prd` 不创建 spec、plan 或 DR。
- `/sdd:prd` 不归档版本。
- `/sdd:prd` 不自动扫描代码或 git log。
- `/sdd:prd` 不写 `- 状态：...` 行，除非未来 PRD 被纳入独立状态工作流。

### 16.7 `/sdd:spec`

`/sdd:spec` 负责在唯一 active version 内创建或修订 functional spec，把当前版本 PRD、相关 requirements、accepted DR 或历史文档作为正式来源写入 `## 文档引用` 表。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示用户运行 `/sdd:init` 或 `/sdd:doctor`。
3. 必须恰好存在一个 `state: active` 的版本。
4. active version 的目录名必须与 `state.json.version` 一致。
5. active version 的 `state.json.state` 必须是 `active`。
6. 如果 0 active version，停止，并提示用户运行 `/sdd:new vX.Y.Z`。
7. 如果多个 active version 或 state 不一致，停止，并提示用户运行 `/sdd:doctor`。
8. `docs/versions/vX.Y.Z/prd.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:prd`。
9. 目标文件位于 `docs/versions/vX.Y.Z/specs/`。
10. 默认目标文件可以是 `spec.md`；当一个版本需要多个功能规格时，应允许用户指定 `specs/<spec-name>.md`。
11. 如果目标 spec 已存在，应先询问用户是覆盖、更新还是取消。

对话流程：

1. 读取 active version 的 `prd.md`。
2. 询问或确认目标 spec 文件名。
3. 澄清功能边界、约束、用户故事、业务规则、输入输出、异常 / 边界场景、验收标准和非目标。
4. 列出可关联的 accepted document-class DR：`spec`、`doc`、`typo`。
5. 列出可关联的 accepted code-class DR：`spec_change: yes`，或 `spec_change: maybe` 且本次修订需要修改 spec。
6. 询问用户是否关联一个或多个 DR。
7. 如果需要引用 project-level requirements，写入 `project:requirements/<file>.md` locator。
8. 如果需要引用旧版本文档，写入版本 locator，例如 `v0.2.0:specs/archive.md`。
9. 写入或更新 spec，并将状态设为 `draft`。
10. 请求用户审阅；用户确认后，将状态切换为 `approved`。

输出路径：

```text
docs/versions/vX.Y.Z/specs/<spec-name>.md
```

推荐模板结构：

```markdown
# Functional Specification：<名称>

- 版本：vX.Y.Z
- 状态：draft
- 日期：YYYY-MM-DD

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 功能概述

## 2. 功能范围

### 2.1 In Scope

### 2.2 Out of Scope

## 3. 约束

### 3.1 产品约束

### 3.2 技术约束

### 3.3 克制原则

## 4. 用户故事 / 使用场景

## 5. 功能行为

### 5.1 <行为或命令>

- 前置条件：
- 执行规则：
- 输出结果：
- 失败行为：

## 6. 业务规则 / 逻辑规则

## 7. 输入输出

### 7.1 输入

### 7.2 输出

## 8. 边界与异常场景

## 9. 验收标准

### Scenario 1: <场景名>

Given <前置条件>
When <用户动作或系统事件>
Then <可验证结果>
```

Spec 模板职责：

- `功能行为` 是 spec 的核心，用于描述用户或 Agent 可观察到的系统表现。
- `约束` 用于防止后续 plan 扩大设计范围；它表达必须遵守的产品边界、技术限制和克制原则，但不写具体实现方案。
- `Out of Scope` 说明不做哪些能力；`约束` 说明即使做当前功能，也必须如何保持克制。
- `业务规则 / 逻辑规则` 用于收敛跨场景共享的判断逻辑、状态转换规则、关系约束或编号规则。
- `验收标准` 必须使用 Scenario 结构表达可验证行为，并能映射到后续 plan task 或 test。

引用规则：

- 引用当前版本 PRD 时，使用 `[prd.md](../prd.md)`，关系通常为 `derives_from`。
- 引用当前版本 DR 时，使用 `[<dr-id>](../decisions/<dr-id>.md)`。
- 引用同版本其他 spec 时，使用 `[<spec-name>.md](./<spec-name>.md)`。
- 引用旧版本 spec、PRD、plan 或 DR 时，必须同时写相对 Markdown link 和版本 locator。
- 引用 project-level requirements 时，必须同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
- `## 文档引用` 是 spec 的正式引用关系来源。
- 不再使用独立 `## 关联 DRs` 作为权威关系表；如需保留 DR 汇总，只能作为辅助阅读信息，且不得与 `## 文档引用` 冲突。

DR 状态处理：

- 如果关联的是 document-class DR，且本次 spec 修订完成该 DR，用户确认 spec 后可以关闭对应 DR。
- 关闭 document-class DR 时，设置 `closed_reason: document-updated`，并写入 `closed_at`。
- document-class DR 完成后，不输出 `/sdd:plan` 或 `/sdd:code` 作为下一步。
- 如果关联的是 code-class DR，spec approved 后该 DR 必须保持 `accepted`。
- code-class DR 不得因为 spec 修订完成而关闭。
- code-class DR 的下一步根据 `plan_required` 输出：
  - `plan_required: yes`：`/sdd:plan <dr-id>`。
  - `plan_required: no`：`/sdd:code <dr-id>`。

边界规则：

- `/sdd:spec` 不创建 active version。
- `/sdd:spec` 不修改 `state.json`。
- `/sdd:spec` 不创建 plan。
- `/sdd:spec` 不修改 code。
- `/sdd:spec` 不归档版本。
- `/sdd:spec` 不读取 git log。
- `/sdd:spec` 不把 plan 作为 spec 的默认依据；如果 spec 引用 plan，应按引用检查规则作为 warning 级例外，并在 `说明` 中解释原因。

### 16.8 `/sdd:plan`

`/sdd:plan <work-item>` 负责在唯一 active version 内，为 approved spec 或 accepted code-class DR 生成新的增量 Implementation Plan，并把实现依据写入统一 `## 文档引用` 表。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示用户运行 `/sdd:init` 或 `/sdd:doctor`。
3. 必须恰好存在一个 `state: active` 的版本。
4. active version 的目录名必须与 `state.json.version` 一致。
5. active version 的 `state.json.state` 必须是 `active`。
6. 如果 0 active version，停止，并提示用户运行 `/sdd:new vX.Y.Z`。
7. 如果多个 active version 或 state 不一致，停止，并提示用户运行 `/sdd:doctor`。
8. `<work-item>` 必须按语法解析，不得靠语义猜测。

模式识别：

1. 如果 `<work-item>` 匹配 `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`，使用 code-class DR mode。
2. 如果 `<work-item>` 匹配 `^(spec|doc|typo)-[0-9]{4}-[a-z0-9-]+$`，拒绝执行，并输出：`文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
3. 否则使用 spec mode。

Spec mode：

- `<work-item>` 可以是 spec 文件名、`specs/<spec-name>.md` 或功能名。
- 如果 `<work-item>` 指向 `specs/<spec-name>.md`，要求该 spec 存在且状态为 `approved`。
- 如果 `<work-item>` 是功能名，必须能唯一解析到一个 approved spec；否则要求用户指定 spec 文件。
- 如果没有任何 approved spec，停止，并提示用户先运行 `/sdd:spec` 并完成审批。
- 输出路径为 `docs/versions/vX.Y.Z/plans/NNN-<slug>.md`。

Code-class DR mode：

- 读取 `docs/versions/vX.Y.Z/decisions/<dr-id>.md`。
- 要求 DR 状态为 `accepted`。
- 要求 `class: code`。
- 要求 `plan_required: yes`。
- 要求 `code_required: yes`。
- 如果 `plan_required: no`，拒绝生成 plan，并提示用户运行 `/sdd:code <dr-id>`。
- 输出路径为 `docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md`。

Plan number allocation：

1. 扫描 `docs/versions/vX.Y.Z/plans/[0-9][0-9][0-9]-*.md`。
2. 提取已有数字前缀。
3. 使用当前最大值加一，并补齐为 3 位数字。
4. 如果没有 plan，使用 `001`。
5. 不要求用户选择 `NNN`。
6. 不复用已有编号。

技术规划对话：

1. 读取相关 approved spec。
2. 如果是 code-class DR mode，读取对应 DR。
3. 探索当前代码结构。
4. 识别受影响模块和文件区域。
5. 提出 2-3 种实现方案。
6. 推荐一种方案并说明 tradeoffs。
7. 与用户确认架构边界、数据 / 控制流、文件影响、测试策略、风险和约束。
8. 如果无法写出具体文件、测试命令、实现步骤或验收映射，继续规划对话，不得生成带占位的 plan。
9. 用户确认后，生成 plan。

Plan 生成质量规则：

- `/sdd:plan` 生成的是 SDD Implementation Plan，不直接套用外部 plan 模板，但必须吸收 agentic execution plan 的执行密度。
- `实施目标` 必须覆盖 plan 的 goal：说明本 plan 要落地哪个 approved spec 或 accepted code-class DR，以及本次交付完成后的可观察结果。
- `技术方案` 必须覆盖 architecture 和 tech stack：说明方案概述、架构边界、受影响模块、关键依赖、数据 / 控制流。
- `契约边界` 和 `风险与约束` 必须覆盖 global constraints：列出来自 spec / DR / CONSTITUTION 的约束、禁止扩张范围和发现契约变化时的停止条件。
- `Implementation Tasks` 不是概要 TODO list，而是可由 agentic worker 直接执行的 TDD 手册。
- 每个 task 必须是独立可测试、可独立 review 的交付单元；setup、配置、脚手架和文档步骤应并入产出它们的 task，只有当 reviewer 可以独立拒绝某个交付时才拆成单独 task。
- 每个 task 必须包含精确 `Files`、`Interfaces`、`Acceptance Mapping` 和 checkbox steps。
- 每个 task 的 `Files` 必须列出精确 create / modify / test 路径；不得只写目录或模糊模块名。
- 每个 task 的 `Interfaces` 必须列出 consumed inputs 和 produced outputs，包括函数名、helper 名、fixture 名、contract assertion、状态形态或文件路径。
- 每个 task 的 `Acceptance Mapping` 必须映射到 spec section、scenario、DR requirement 或 contract test assertion。
- 测试步骤必须包含实际测试代码或 contract assertion、实际运行命令和 expected failure / pass 输出。
- 实现步骤必须包含足够具体的代码、替换片段、文件内容或修改说明，让执行者无需重新设计方案。
- commit 步骤必须包含具体 `git add` 路径和 `git commit -m` 信息。
- 最终 plan 不得保留模板占位，例如 `TBD`、`TODO`、`待定`、`待补充`、`<task name>`、`path/to/file`、`<exact signatures>`、`fill in details`、`implement later`。
- 如果必要信息不足以替换占位，`/sdd:plan` 必须回到技术规划对话继续澄清，而不是写出不完整 plan。
- `/sdd:plan` 写出 plan 前必须执行自检：spec coverage、placeholder scan、type / naming consistency。

推荐模板结构：

```markdown
# NNN-<work-item> Implementation Plan

- 序号：NNN
- 状态：draft
- 类型：feature | fix | feat | chg | arch
- 日期：YYYY-MM-DD

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 实施目标

## 2. 契约边界

## 3. 技术方案

### 3.1 方案概述

### 3.2 架构边界

### 3.3 模块影响

### 3.4 数据流 / 控制流

## 4. 测试策略

## 5. 风险与约束

## 6. Implementation Tasks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

### Task 1: <task name>

**Files:**
- Create:
  - `path/to/new-file`
- Modify:
  - `path/to/existing-file`
- Test:
  - `path/to/test-file`

**Interfaces:**
- Inputs:
  - `<command / function / file / state>`
- Outputs:
  - `<return value / file change / stdout / state transition>`
- Produces for later tasks:
  - `<exact function, helper, fixture, contract, or state shape>`

**Acceptance Mapping:**
- Covers: `<spec section or scenario id>`

- [ ] **Step 1: Write the failing test or contract assertion**

```<language>
<actual failing test, shell assertion, or contract assertion generated for this task>
```

- [ ] **Step 2: Run test to verify it fails**

Run: `<exact test command>`
Expected: `<specific failure output or assertion message>`

- [ ] **Step 3: Write minimal implementation**

```<language>
<actual implementation snippet, replacement block, or file content generated for this task>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `<exact test command>`
Expected: `<specific pass output>`

- [ ] **Step 5: Commit**

```bash
git add <exact changed files>
git commit -m "<type>: <specific message>"
```

## 7. Self-Review

### 7.1 Spec Coverage

- `<requirement or section>` -> `<task number and step>`

### 7.2 Placeholder Scan

- Result: `<no unresolved template placeholders remain / list exact placeholders to fix before approval>`

### 7.3 Type / Naming Consistency

- Result: `<interfaces, helper names, file paths, states, and relation names are consistent / list exact mismatch to fix before approval>`
```

Plan 模板职责：

- `实施目标` 说明本 plan 要落地哪个 approved spec 或 accepted code-class DR。
- `契约边界` 明确本 plan 只实现已批准行为；如果发现需要改变 spec 或 DR，必须停止当前 plan，并记录需要回到上游决策或契约修订。
- `技术方案` 只描述实现策略、架构边界、模块影响和数据 / 控制流，不新增功能契约。
- `测试策略` 必须说明如何证明实现满足 spec / DR，并覆盖关键边界和失败行为。
- `Implementation Tasks` 保留执行框架；每个 task 必须列出精确的 create / modify / test 文件、输入输出、对后续任务产生的接口，以及对应的 spec section、scenario、DR requirement 或 contract assertion。具体测试代码、实现步骤和验证命令由 `/sdd:plan` 根据实际 work item 生成。
- `Implementation Tasks` 必须达到可执行密度：测试步骤包含实际测试代码或 contract assertion、运行命令和 expected 输出；实现步骤包含足够具体的代码、替换片段、文件内容或修改说明；commit 步骤包含具体 `git add` 路径和 commit message。
- `Self-Review` 是 plan 的必填末尾章节，用于记录 spec coverage、placeholder scan 和 type / naming consistency。该章节不替代用户 review，也不推进 plan 状态。

引用规则：

- plan 引用 spec 时，关系应为 `implements`。
- plan 引用 code-class DR 时，关系应为 `implements`。
- plan 引用其他 plan、历史 plan 或历史 DR 作为背景时，关系可以是 `references`。
- plan 引用旧版本 plan 或旧版本 DR 时，必须同时写相对 Markdown link 和版本 locator。
- plan 不得使用 `modifies`、`replaces`、`deprecates`。
- plan 如果发现需要改变功能契约，必须停止当前 plan 生成流程，建议先创建或修订 DR / spec，不得只在 plan 中表达行为变更。

状态流程：

- 初始写入 `- 状态：draft`。
- 用户确认后切换为 `planned`。
- `/sdd:plan` 不把任何 DR 改为 `closed`。
- `/sdd:plan` 不改变 code-class DR 状态；DR 保持 `accepted`，等待 `/sdd:code` 成功后关闭。

边界规则：

- `/sdd:plan` 不创建 active version。
- `/sdd:plan` 不修改 `state.json`。
- `/sdd:plan` 不修改 spec。
- `/sdd:plan` 不修改 DR 状态。
- `/sdd:plan` 不修改 code。
- `/sdd:plan` 不归档版本。
- `/sdd:plan` 不重开 closed DR。
- `/sdd:plan` 不改写 done plan；后续问题应生成新的增量 plan。

### 16.9 `/sdd:dr`

`/sdd:dr` 负责在唯一 active version 内创建、接受或关闭 Decision Record。DR 记录决策来源、流程字段、受影响资产和后续落地路径。

支持命令：

```text
/sdd:dr <tag> <title>
/sdd:dr accept <id>
/sdd:dr dismiss <id> <reason>
```

允许 tag：

```text
fix | feat | chg | arch | spec | doc | typo
```

Tag 默认字段：

| tag | class | spec_change | plan_required | code_required |
| --- | --- | --- | --- | --- |
| fix | code | no | yes | yes |
| feat | code | yes | yes | yes |
| chg | code | yes | yes | yes |
| arch | code | maybe | yes | yes |
| spec | document | yes | no | no |
| doc | document | maybe | no | no |
| typo | document | no | no | no |

轻量 fix 规则：

- 简单实现 bug 可以由用户选择轻量 fix 流程。
- 轻量 fix 必须保持 `tag: fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`。
- 如果修复涉及 API contract、schema、状态机、hook 或跨模块流程变化，不使用轻量 fix，应保持 `plan_required: yes` 并生成新的增量 Implementation Plan。
- `spec_change` 和 `plan_required` 只能在不违反 `class` 与 `code_required` 强约束的前提下调整。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示用户运行 `/sdd:init` 或 `/sdd:doctor`。
3. 必须恰好存在一个 `state: active` 的版本。
4. active version 的目录名必须与 `state.json.version` 一致。
5. active version 的 `state.json.state` 必须是 `active`。
6. 如果 0 active version，停止，并提示用户运行 `/sdd:new vX.Y.Z`。
7. 如果多个 active version 或 state 不一致，停止，并提示用户运行 `/sdd:doctor`。

Create mode：

1. 接收 `/sdd:dr <tag> <title>`。
2. tag 必须在允许列表内。
3. 扫描 active version 的 `docs/versions/vX.Y.Z/decisions/*.md`。
4. 生成版本内递增 DR 编号 `NNNN`；如果没有 DR，使用 `0001`。
5. slugify title。
6. 写入 `docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md`。
7. 根据 tag 默认字段填充 `class`、`spec_change`、`plan_required`、`code_required`。
8. 初始状态为 `drafting`。
9. 如果用户选择轻量 fix，将 `plan_required` 设为 `no`，但仍保持 `class: code` 与 `code_required: yes`。
10. 写入 `## 文档引用` 表。
11. 如果没有正式引用，使用固定空集合行：`| 未声明。 | - | - | - | - |`。
12. 输出下一步。

Create mode 输出路径：

```text
docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md
```

推荐模板结构：

```markdown
# DR-<tag>-NNNN：<标题>

- 状态：drafting
- class：code | document
- tag：fix | feat | chg | arch | spec | doc | typo
- 日期：YYYY-MM-DD
- spec_change：yes | no | maybe
- plan_required：yes | no
- code_required：yes | no
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 背景

## 2. 决策

## 3. 决策边界

## 4. 影响分析

### 4.1 契约影响

### 4.2 实现影响

### 4.3 文档影响

## 5. 落地要求

## 6. 验证方式

## 7. 影响资产

| 资产 | 章节 / ID |
| ---- | --------- |
```

DR 模板职责：

- `背景` 说明为什么需要这个决策、问题来自哪里。
- `决策` 说明选择了什么结论。
- `决策边界` 说明这个 DR 不改变什么、不覆盖什么、不扩张到哪里。
- `影响分析` 按契约、实现和文档三个层面描述影响，但不替代 spec、plan 或 code。
- `落地要求` 说明该决策需要被落实到哪些层面，例如功能契约、实现行为、文档内容或验证记录；不得写具体 plugin command。
- `影响资产` 只记录受影响资产摘要，不替代 `## 文档引用`。

DR 引用规则：

- DR 引用当前版本 spec 时，关系通常为 `modifies`、`derives_from` 或 `references`，取决于该 DR 是否改变、派生或仅参考该 spec。
- DR 引用 plan 时，关系通常为 `references`。
- DR 引用旧 DR 时，普通后续问题通常使用 `references`。
- 只有新 DR 真正替代旧决策时，才使用 `replaces` 或 `supersedes` 字段表达替代关系。
- DR 引用 project-level requirements 时，必须同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
- DR 引用跨版本文档时，必须同时写相对 Markdown link 和版本 locator。
- `## 文档引用` 是 DR 的正式关系来源。
- `## 影响资产` 只记录受影响资产摘要，不替代 `## 文档引用`。

Accept mode：

- 输入为 `/sdd:dr accept <id>`。
- 只允许 `drafting -> accepted`。
- 不写 `closed_reason`。
- 不写 `closed_at`。
- 不更新 supersede chain。
- 接受后读取 `class`、`spec_change`、`plan_required`、`code_required` 并输出下一步。

Accept mode 下一步规则：

- `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 运行 `/sdd:plan <id>` 或 `/sdd:code <id>`。
- `class: code` 且 `spec_change: no`、`plan_required: yes`：运行 `/sdd:plan <id>`。
- `class: code` 且 `spec_change: no`、`plan_required: no`：运行 `/sdd:code <id>`。
- `class: code` 且 `spec_change: maybe`：要求 Agent 说明是否需要修订 spec；如果需要，先 `/sdd:spec`，再按 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`；如果不需要，则直接按 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`。
- `class: document`：运行 `/sdd:spec` 或对应文档 skill，不进入 `/sdd:plan` 或 `/sdd:code`。

Dismiss mode：

- 输入为 `/sdd:dr dismiss <id> <reason>`。
- 只允许 dismiss `drafting` DR。
- 将状态从 `drafting` 改为 `closed`。
- 设置 `closed_reason: dismissed`。
- 设置 `dismissed_reason` 为用户提供的 reason。
- 设置 `closed_at` 为当前 UTC timestamp。
- accepted 或 closed DR 不允许 dismiss。

Supersede 规则：

- accepted 或 closed DR 需要替代时，应新建 DR 表达新的决策或修复。
- 新 DR 可以通过 `supersedes` 和 `## 文档引用` 引用被替代 DR。
- 跨版本替代不回写旧版本文档。
- closed DR 不重新打开。
- superseded 不作为 DR `status`，只能通过 `superseded_by` 或新 DR 的 `supersedes` 表达。

边界规则：

- `/sdd:dr` 不创建 active version。
- `/sdd:dr` 不修改 `state.json`。
- `/sdd:dr` 不创建 spec。
- `/sdd:dr` 不创建 plan。
- `/sdd:dr` 不修改 code。
- `/sdd:dr` 不归档版本。
- `/sdd:dr accept` 不关闭 DR。
- `/sdd:dr dismiss` 不允许作用于 accepted 或 closed DR。
- DR 的正式关系以 `## 文档引用` 为准，`## 影响资产` 只做摘要。

### 16.10 `/sdd:triage`

`/sdd:triage` 负责在用户提出实现后、评审中或测试中的问题时，进行引用感知的只读分诊。它判断问题应进入 DR、spec revision、plan revision、code fix 或解释路径，但不执行被推荐路径。

支持命令：

```text
/sdd:triage
/sdd:triage --deep
```

功能定位：

- `/sdd:triage` 是 read-only diagnostic skill。
- 它只推荐路径和可选路径。
- 它必须等待用户确认后，才能建议进入其他 skill。
- 它不直接创建或修改任何文档、状态或代码。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示用户运行 `/sdd:init` 或 `/sdd:doctor`。
3. 通过扫描 `docs/versions/v*/state.json` 发现 active version。
4. 如果 0 active version，停止，并提示用户运行 `/sdd:new vX.Y.Z`。
5. 如果多个 active version、`state.json` 缺失、JSON 无法解析、`version` 与目录名不一致或 `state` 非法，停止，并提示用户运行 `/sdd:doctor`。
6. 只有恰好存在一个合法 `state: active` 的版本时，才读取版本内文档。

定位输入：

`/sdd:triage` 应优先使用用户问题中的最小 locator 缩小读取范围：

- feature name
- spec name
- section number
- DR ID
- plan filename
- requirement file
- observed symptom
- code path

Token control：

- 不得一次性读取整个 active version 目录。
- 不得默认读取所有 `specs/*.md`。
- 不得默认读取所有 `plans/*.md`。
- 不得默认读取所有 `decisions/*.md`。
- 不得默认读取所有 archived versions。
- 不得默认读取代码。
- 必须先建立候选范围，再按候选文件读取。
- `/sdd:triage --deep` 可以读取更多相关 plan、DR 或 code 上下文，但仍必须先缩小候选范围。

引用感知读取顺序：

1. 理解用户问题；必要时要求用户提供 locator。
2. 读取 active version 的最小结构信息，例如 `prd.md` 是否存在、`specs/*.md`、`plans/*.md`、`decisions/*.md` 文件名。
3. 如果用户指向 spec，读取相关 spec 小节和该文件的 `## 文档引用` 表。
4. 如果用户指向 plan，读取该 plan 的状态、相关任务和 `## 文档引用` 表。
5. 如果用户指向 DR，读取该 DR 的流程字段、状态、`## 文档引用` 表和必要正文小节。
6. 如果 `## 文档引用` 指向 PRD、requirements、同版本 spec、plan 或 DR，只读取与问题直接相关的目标文档。
7. 如果涉及 project-level requirements，使用 `project:requirements/<file>.md` locator 定位。
8. 如果涉及跨版本引用，只读取被引用的具体版本文档；不得扫描所有 archived versions。
9. 只有需要比较实现与 spec/plan/DR 是否一致时，才读取 code。
10. 如果证据不足，输出 low-confidence triage，并说明缺失的 locator 或上下文。

分类：

| 分类 | 含义 |
| ---- | ---- |
| `code implementation issue` | spec 和 plan 基本正确，但当前代码实现偏离预期。 |
| `plan issue` | spec 或 accepted code-class DR 基本明确，但 plan 拆解、实现策略、任务边界或验收安排有问题。 |
| `spec issue` | spec 缺失、歧义、契约不完整或验收标准不足。 |
| `reference issue` | `## 文档引用` 缺失、错误、关系不当、locator 不完整，或仍依赖旧的 `关联 DRs` / `影响资产` 表达正式关系。 |
| `new requirement / change request` | 用户提出的是新的能力、行为变化或超出现有 spec 的需求。 |
| `explanation only` | 当前行为符合已批准设计，用户需要解释而不是变更。 |
| `unclear, needs user choice` | 证据不足，或同一问题可合理归入多条路径，需要用户选择。 |

分析顺序：

1. approved spec 是否清楚描述预期行为？
2. `## 文档引用` 是否能说明相关 PRD、requirements、DR、spec 或 plan 的正式关系？
3. plan 是否正确覆盖相关 spec 或 accepted code-class DR？
4. 当前 implementation 是否匹配 plan 和 spec？
5. 问题是否暴露 spec 缺失、歧义或验收不足？
6. 问题是否暴露引用表缺失或关系错误？
7. 用户是否提出新需求或行为变更？
8. 用户是否只是要求解释现有行为？

输出格式：

```text
我的判断：这是 <分类>。
置信度：low | medium | high
已读取依据：
- <spec 小节或文件，如有>
- <plan 文件，如有>
- <DR 文件，如有>
- <文档引用表或 locator，如有>
- <代码文件，如有>
原因：<简短依据>。
推荐路径：<路径名称>。
可选路径：
1. <路径 A>：<适用条件 / 结果>
2. <路径 B>：<适用条件 / 结果>
3. <路径 C>：<适用条件 / 结果>
请确认你要走哪条路径。
```

推荐路径：

| 路径 | 判断 | 推荐流程 |
| --- | --- | --- |
| A | 代码实现问题，且满足轻量 fix 条件 | `/sdd:dr fix <title>`，选择 lightweight fix，accept 后 `/sdd:code <id>` |
| B | 代码实现问题，但需要 plan | `/sdd:dr fix <title>` -> `/sdd:dr accept <id>` -> `/sdd:plan <id>` -> `/sdd:code <plan>` |
| C | plan 问题 | `/sdd:dr fix <title>` -> `/sdd:dr accept <id>` -> 新增 incremental plan -> `/sdd:code <plan>` |
| D | spec 缺失或歧义 | `/sdd:dr spec <title>` 或 spec-changing code DR -> `/sdd:spec` -> 后续按 DR class 输出 |
| E | 新需求或行为变更 | `/sdd:dr feat|chg <title>` -> `/sdd:spec` -> `/sdd:plan <id>` -> `/sdd:code <plan>` |
| F | 当前行为符合设计 | explain only，不创建 DR |
| G | 引用关系缺失或错误 | document-class `doc` 或 `spec` DR -> `/sdd:spec` 或对应文档修订，不进入 `/sdd:plan` 或 `/sdd:code` |

路径约束：

- 轻量 fix 只能用于 `tag: fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`。
- 如果修复涉及 API contract、schema、状态机、hook 或跨模块流程变化，不推荐轻量 fix。
- document-class DR 不进入 `/sdd:plan` 或 `/sdd:code`。
- spec-changing code-class DR 必须先完成 `/sdd:spec`，再按 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`。
- plan 问题不改写已完成 plan；应通过 accepted code-class DR 生成新的增量 plan。
- ordinary bug-fix relationship 不使用 `supersedes`，除非新 DR 真正替代旧决策。

边界规则：

- `/sdd:triage` 不创建 active version。
- `/sdd:triage` 不修改 `state.json`。
- `/sdd:triage` 不创建、接受或关闭 DR。
- `/sdd:triage` 不修改 spec、plan、DR、PRD、requirements 或 code。
- `/sdd:triage` 不生成 plan。
- `/sdd:triage` 不执行 code。
- `/sdd:triage` 不修复引用表。
- `/sdd:triage` 不运行 archive。
- `/sdd:triage` 不把 `## 影响资产` 当成正式关系来源。
- `/sdd:triage` 不在 0 active、多 active 或 state 损坏时继续分析版本内流程。

### 16.11 `/sdd:code`

`/sdd:code` 负责在唯一 active version 内执行已经 planned/coding 的 Implementation Plan，或执行 accepted lightweight fix DR。它是实现执行入口，不负责创建或修订 PRD、spec、plan、DR 或引用关系。

支持命令：

```text
/sdd:code <work-item>
```

执行模式：

1. Plan execution mode：输入匹配 active version 内的 Implementation Plan。
2. Lightweight fix DR mode：输入匹配 eligible accepted fix DR，且该 DR 不需要 plan。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，并提示用户运行 `/sdd:init` 或 `/sdd:doctor`。
3. 通过扫描 `docs/versions/v*/state.json` 发现 active version。
4. 如果 0 active version，停止，并提示用户运行 `/sdd:new vX.Y.Z`。
5. 如果多个 active version、`state.json` 缺失、JSON 无法解析、`version` 与目录名不一致或 `state` 非法，停止，并提示用户运行 `/sdd:doctor`。
6. 只有恰好存在一个合法 `state: active` 的版本时，才解析 work item。

Work item lookup：

1. 如果输入是 `NNN`，匹配 `docs/versions/vX.Y.Z/plans/NNN-*.md`。
2. 如果输入是完整 plan basename，匹配 active version 内同名 `.md` plan。
3. 如果输入是 feature name，按 active version 内 plan suffix 匹配。
4. 如果输入匹配 code-class DR id `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`，先查找 `docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md`。
5. 如果 DR id 没有 matching plan，读取 `docs/versions/vX.Y.Z/decisions/<dr-id>.md`，仅当它满足 lightweight fix DR 条件时进入 Lightweight fix DR mode。
6. 如果没有匹配 plan 且没有 eligible lightweight fix DR，停止，并提示用户运行 `/sdd:plan <work-item>` 或确认轻量 fix DR。
7. 如果匹配多个 plan，停止，并要求用户使用 plan number，例如 `/sdd:code 002`。

Plan execution mode：

- plan 状态必须是 `planned` 或 `coding`。
- plan 必须通过 `## 文档引用` 表表达它 `implements` 的 approved spec 或 accepted code-class DR。
- spec mode plan 必须 `implements` 一个 approved spec。
- code-class DR mode plan 必须 `implements` 一个 accepted code-class DR。
- 如果 code-class DR 的 `spec_change: yes` 或 `spec_change: maybe` 且已经通过 `/sdd:spec` 修订契约，plan 也应 `implements` 对应 approved spec。
- 如果 code-class DR 不需要 spec 修订，plan 可以只 `implements` 该 DR，但必须在 `说明` 中说明实现依据来自 accepted DR。
- 如果 plan implements spec，目标 spec 必须是 `approved`。
- 如果 plan implements code-class DR，目标 DR 必须满足:
  - `状态：accepted`
  - `class: code`
  - `plan_required: yes`
  - `code_required: yes`
- document-class DR 不允许进入 `/sdd:code`。
- `plan_required: no` 的 DR 不通过 plan execution mode 执行。

Plan execution 状态流转：

1. 执行前将 plan 状态从 `planned` 切换为 `coding`；如果已经是 `coding`，保持不变。
2. 用户选择执行模式：
   - 高质量模式：`superpowers:subagent-driven-development`
   - 快速模式：`superpowers:executing-plans`
3. 执行 plan。
4. 运行 verification。
5. execution 和 verification 成功后，将 plan 状态切换为 `done`。
6. 如果 plan implements accepted code-class DR，将该 DR 从 `accepted` 切换为 `closed`。
7. 设置 DR `closed_reason: committed`。
8. 设置 DR `closed_at` 为当前 UTC timestamp。

Plan execution 失败行为：

```text
plan remains coding
associated DR remains accepted
```

Lightweight fix DR mode：

该模式只用于符合既有 approved spec、无需 Implementation Plan 的简单实现 bug。

前置条件：

```text
DR 状态为 accepted
DR `class` is `code`
DR `tag` is `fix`
DR `spec_change: no`
DR `plan_required: no`
DR `code_required: yes`
```

状态流转：

1. 执行本地 code fix。
2. 运行 verification。
3. execution 和 verification 成功后，将 DR 从 `accepted` 切换为 `closed`。
4. 设置 DR `closed_reason: committed`。
5. 设置 DR `closed_at` 为当前 UTC timestamp。
6. 不查找、不要求、不修改 plan 状态。

Lightweight fix DR mode 失败行为：

```text
DR remains accepted
no plan status is changed
```

Supersede 规则：

- 如果 completed code-class DR 声明 `supersedes`，同 active version 内的被替代 DR 可以写入 `superseded_by`。
- `superseded_by` 属于 DR 流程元字段；`/sdd:code` 只允许按 supersede 规则更新该字段，不修改被替代 DR 的决策正文。
- 跨版本被替代 DR 不回写。
- `superseded` 不作为 DR `status`。
- closed DR 不重新打开。
- ordinary bug-fix relationship 不使用 `supersedes`，除非新 DR 真正替代旧决策。

边界规则：

- `/sdd:code` 不创建 active version。
- `/sdd:code` 不修改 `state.json`。
- `/sdd:code` 不创建 PRD、spec、plan 或 DR。
- `/sdd:code` 不修订 PRD、spec、plan 或 DR 的设计正文。
- `/sdd:code` 不修复 `## 文档引用` 表。
- `/sdd:code` 不执行 `/sdd:spec` 或 `/sdd:plan`。
- `/sdd:code` 不接受或 dismiss DR。
- `/sdd:code` 不处理 document-class DR。
- `/sdd:code` 不归档版本。

### 16.12 `/sdd:research`

`/sdd:research` 负责创建或更新 project-level research / requirements 资料。它不属于任何 version，不参与 version lifecycle，但可以作为 PRD 或 spec 的上游资料来源。

支持命令：

```text
/sdd:research <topic>
```

功能定位：

- `/sdd:research` 写入 `docs/requirements/`。
- `/sdd:research` 不要求 active version。
- `/sdd:research` 在 0 active version 时仍可运行。
- research 文档不是正式 contract；正式 contract 由 PRD 或 spec 承载。

前置条件：

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，并提示用户运行 `/sdd:init`。
2. `docs/requirements/` 必须存在；缺失时可以创建该目录。
3. 如果 `docs/CONSTITUTION.md` 存在但 `docs/requirements/` 缺失，视为可自愈的项目结构缺口；`/sdd:research` 只创建 `docs/requirements/`，不创建其他项目骨架。
4. 不扫描 `docs/versions/v*/state.json`。
5. 不要求存在 active version。

对话输入：

1. Research topic。
2. 为什么该 topic 重要。
3. Sources 或 local files。
4. 后续 PRD 或 spec 需要使用的 decision output。
5. 如果用户已有目标 PRD 或 spec，可以记录为建议后续引用，但不自动修改目标文档。

输出路径：

```text
docs/requirements/<topic-slug>-<yyyy-mm>.md
```

文档规则：

- research 文档不写 `- 状态：...` 行。
- research 文档不写 version lifecycle 字段。
- research 文档不要求 `## 文档引用` 表。
- research 文档可以包含来源、调研结论、决策建议、开放问题和普通 Markdown links。
- 如果同名 research 文件已存在，应更新同一 research 文档或要求用户确认新的 slug；不得创建 version-local 副本。

推荐模板结构：

```markdown
# Research：<topic>

- 日期：YYYY-MM-DD
- 范围：project

## 1. 背景

## 2. 调研问题

## 3. 信息来源

| 来源 | 类型 | 摘要 |
| ---- | ---- | ---- |

## 4. 关键事实

## 5. 分析与推论

## 6. 建议

## 7. 可引用结论

| 结论 | 建议引用位置 | 说明 |
| ---- | ------------ | ---- |

## 8. 限制与不确定性
```

Research 模板职责：

- `背景` 说明为什么需要这份 research。
- `调研问题` 明确本次调研试图回答什么，防止资料无限扩张。
- `信息来源` 记录来源、类型和摘要；来源可以是文件、访谈、网页、用户反馈或业务资料。
- `关键事实` 只记录相对客观的信息。
- `分析与推论` 记录基于事实得到的判断，必须和事实区分。
- `建议` 可以提出产品、文档或实现方向，但不形成正式 contract。
- `可引用结论` 是供 PRD、spec 或 DR 引用的候选内容；只有被正式文档引用后，才进入对应 contract。
- `限制与不确定性` 记录资料不足、假设、冲突来源或仍需确认的问题。

与 PRD / spec 的关系：

- `/sdd:research` 不自动修改 PRD 或 spec。
- 当 `/sdd:prd` 或 `/sdd:spec` 使用 research 文档作为正式来源时，目标文档必须在 `## 文档引用` 表中记录该 research 文档。
- relation 通常为 `derives_from` 或 `references`。
- Markdown link 必须按来源文件位置使用相对路径。
- locator 必须使用 `project:requirements/<file>.md`。

边界规则：

- `/sdd:research` 不创建 active version。
- `/sdd:research` 不读取或修改 `state.json`。
- `/sdd:research` 不创建 PRD、spec、plan 或 DR。
- `/sdd:research` 不修改 PRD、spec、plan 或 DR。
- `/sdd:research` 不关闭 DR。
- `/sdd:research` 不生成 plan。
- `/sdd:research` 不执行 code。
- `/sdd:research` 不归档版本。

## 17. Impacted Skills and Specs

后续实现本规格时，需要同步修订用户直接调用的 SDD skills，并确保 supporting assets 与这些用户流程保持一致。

用户直接调用的 skill 影响范围：

- Archive Advanced：应从目录移动模型改为状态文件模型，或由本规格替代其 `/sdd:archive` 设计部分。
- DR Advanced：应调整 DR 模板中的 `影响资产` 和跨文档链接规则，使其兼容 `## 文档引用` 表。
- `/sdd:init`：创建 `docs/versions/`，但不创建版本目录或版本级 `state.json`。
- `/sdd:new`：创建 `docs/versions/vX.Y.Z/`、版本级 `state.json`、`specs/`、`plans/` 和 `decisions/`，并通过 `docs/versions/v*/state.json` 判断 active version。
- `/sdd:status`：读取 `docs/versions/v*/state.json`，支持 0 active version、1 active version 和一致性错误输出，不再依赖固定 `specs/spec.md` 文件。
- `/sdd:doctor`：检查插件安装、项目结构、`state.json`、active version 数量、目录名与版本字段一致性、archive index 一致性、基础文档状态和轻量引用表结构，并提示旧草案结构 `docs/vX.Y.Z/` 不属于当前模型。
- `/sdd:archive`：执行状态文件归档，不移动版本目录，生成版本 `ARCHIVE.md`，更新 `docs/archive/INDEX.md`，执行 blocking/warning 引用检查，并在成功后允许 0 active version。
- `/sdd:prd`：通过 `docs/versions/v*/state.json` 发现 active version，在 `docs/versions/vX.Y.Z/prd.md` 创建或更新 PRD，写入 `## 文档引用` 表，并用 `project:requirements/<file>.md` locator 记录正式 requirement 来源。
- `/sdd:spec`：通过 `docs/versions/v*/state.json` 发现 active version，在 `docs/versions/vX.Y.Z/specs/<spec-name>.md` 创建或修订 spec，写入 `## 文档引用` 表，支持 PRD、requirements、DR、同版本 spec 和跨版本文档引用，并按 DR class 决定是否关闭 document-class DR 或继续 code-class DR 流程。
- `/sdd:plan`：通过 `docs/versions/v*/state.json` 发现 active version，为 approved spec 或 accepted code-class DR 生成新的增量 Implementation Plan，写入 `## 文档引用` 表，拒绝 document-class DR 和 `plan_required: no` 的 DR，并禁止 plan 使用 `modifies`、`replaces`、`deprecates` 改变契约。
- `/sdd:dr`：通过 `docs/versions/v*/state.json` 发现 active version，在 `docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md` 创建版本内递增编号 DR，写入 `## 文档引用` 表，保留 `drafting`、`accepted`、`closed` 状态模型，支持 accept / dismiss，并将 `## 影响资产` 限定为摘要而非正式关系来源。
- `/sdd:triage`：通过 `docs/versions/v*/state.json` 发现 active version，基于用户 locator、`## 文档引用` 表和最小必要 spec/plan/DR/code 证据做只读分诊，输出分类、置信度、依据、推荐路径和可选路径，但不创建或修改任何文档、状态或代码。
- `/sdd:code`：通过 `docs/versions/v*/state.json` 发现 active version，执行 planned/coding plan 或 eligible accepted lightweight fix DR，基于 `## 文档引用` 验证 plan 对 approved spec 或 accepted code-class DR 的 `implements` 关系，并在 verification 成功后推进 plan/DR 状态。
- `/sdd:research`：作为 project-level research / requirements 资料入口，写入 `docs/requirements/<topic-slug>-<yyyy-mm>.md`，不要求 active version，不参与 version lifecycle；PRD 或 spec 使用 research 时通过 `## 文档引用` 表和 `project:requirements/<file>.md` locator 建立正式来源关系。

Supporting assets 影响范围：

- helper scripts、hooks、templates、README、发布包内容和 contract tests 必须与本规格定义的路径模型、状态模型、引用表规则和 skill 行为保持一致。
- supporting assets 的具体文件清单、修改步骤和验证命令由后续 Implementation Plan 定义，不在本规格中逐项展开。

## 18. Acceptance Criteria

本规格实现后应满足：

1. `/sdd:init` 创建 `docs/versions/`，但不创建任何 `docs/versions/vX.Y.Z/` 或版本级 `state.json`。
2. `/sdd:init` 完成后允许 0 active version；需要 active version 的 skill 必须提示用户运行 `/sdd:new vX.Y.Z`。
3. `/sdd:new` 创建版本目录时生成 `docs/versions/vX.Y.Z/`、`state.json`、`specs/`、`plans/` 和 `decisions/`。
4. `/sdd:new` 只通过 `docs/versions/v*/state.json` 判断 active version；已有一个 active version 时阻止创建，0 active version 时允许创建。
5. `/sdd:new` 发现多个 active version、缺失 `state.json`、JSON 无法解析、`version` 与目录名不一致或 `state` 非法时阻止创建，并提示运行 `/sdd:doctor`。
6. `/sdd:status` 支持 0 active version、1 active version 和一致性错误输出；0 active version 时提示 `/sdd:new vX.Y.Z`，一致性错误时提示 `/sdd:doctor`。
7. `/sdd:status` 在 1 active version 状态下扫描 `specs/*.md`、`plans/*.md` 和 `decisions/*.md`，不再依赖固定 `specs/spec.md`。
8. `/sdd:doctor` 检查插件安装、项目结构、旧草案结构、version state、active version 文档状态、Plan / DR consistency、archive index 和轻量引用表结构。
9. `/sdd:doctor` 是只读诊断入口，不创建、不修改、不修复文件。
10. `/sdd:prd` 在 `docs/versions/vX.Y.Z/prd.md` 创建或更新 PRD，支持统一 `## 文档引用` 表，并用 `project:requirements/<file>.md` locator 记录正式 requirement 来源。
11. `/sdd:prd` 不创建 active version、不修改 `state.json`、不创建 spec/plan/DR，并且不写 `- 状态：...` 行。
12. `/sdd:spec` 在 `docs/versions/vX.Y.Z/specs/<spec-name>.md` 创建或修订 spec，默认可使用 `spec.md`，并允许一个版本包含多个 `specs/*.md`。
13. `/sdd:spec` 支持统一 `## 文档引用` 表，用相对 Markdown link 和必要 locator 记录 PRD、requirements、DR、同版本 spec 和跨版本文档来源。
14. `/sdd:spec` 用户确认后将 spec 状态从 `draft` 切换为 `approved`。
15. `/sdd:spec` 可以在 document-class DR 完成后关闭对应 DR，设置 `closed_reason: document-updated` 和 `closed_at`，但不得输出 `/sdd:plan` 或 `/sdd:code`。
16. `/sdd:spec` 关联 code-class DR 时，spec approved 后 DR 必须保持 `accepted`，并根据 `plan_required` 输出 `/sdd:plan <dr-id>` 或 `/sdd:code <dr-id>`。
17. `/sdd:plan` 在 `docs/versions/vX.Y.Z/plans/NNN-<slug>.md` 或 `docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md` 创建新的增量 Implementation Plan，并自动分配版本内递增的 `NNN`。
18. `/sdd:plan` 支持 approved spec mode 和 accepted code-class DR mode；spec mode 必须能唯一解析到 approved spec，code-class DR mode 必须要求 `class: code`、`plan_required: yes`、`code_required: yes`。
19. `/sdd:plan` 拒绝 document-class DR，并拒绝 `plan_required: no` 的 DR，后者应提示 `/sdd:code <dr-id>`。
20. `/sdd:plan` 支持统一 `## 文档引用` 表，使用 `implements` 记录 plan 对 spec 或 code-class DR 的落地关系。
21. `/sdd:plan` 用户确认后将 plan 状态从 `draft` 切换为 `planned`，不关闭 DR、不修改 spec、不修改 code、不修改 `state.json`。
22. `/sdd:dr` 在 `docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md` 创建版本内递增编号 DR，初始状态为 `drafting`。
23. `/sdd:dr` 根据 tag 填充 `class`、`spec_change`、`plan_required`、`code_required`，并支持用户选择符合约束的轻量 fix。
24. `/sdd:dr` 支持统一 `## 文档引用` 表；`## 影响资产` 只作为受影响资产摘要，不作为正式关系来源。
25. `/sdd:dr accept <id>` 只允许 `drafting -> accepted`，不写 `closed_reason`、不写 `closed_at`、不更新 supersede chain，并按 DR 流程字段输出下一步。
26. `/sdd:dr dismiss <id> <reason>` 只允许作用于 `drafting` DR，关闭时设置 `closed_reason: dismissed`、`dismissed_reason` 和 `closed_at`。
27. `/sdd:dr` 不允许 dismiss accepted 或 closed DR；需要替代时应新建 DR，并通过 `supersedes`、`superseded_by` 或 `## 文档引用` 表达关系。
28. `/sdd:triage` 是只读引用感知分诊入口，通过扫描 `docs/versions/v*/state.json` 发现唯一 active version，并在 0 active、多 active 或 state 损坏时停止且提示下一步。
29. `/sdd:triage` 基于用户 locator、最小 active version 结构信息、相关 `## 文档引用` 表和必要 spec/plan/DR/code 证据输出分类、置信度、依据、推荐路径和可选路径。
30. `/sdd:triage` 支持 `reference issue` 分类，用于识别引用表缺失、关系错误、locator 不完整或错误依赖旧 `关联 DRs` / `影响资产` 的情况。
31. `/sdd:triage` 不创建、不接受、不关闭 DR，不修改 `state.json`、PRD、spec、plan、DR、requirements 或 code，并且不把 `## 影响资产` 当成正式关系来源。
32. `/sdd:code` 通过扫描 `docs/versions/v*/state.json` 发现唯一 active version，并在 0 active、多 active 或 state 损坏时停止且提示下一步。
33. `/sdd:code` 支持 plan execution mode 和 lightweight fix DR mode；plan mode 只执行 active version 内 `planned` 或 `coding` plan，lightweight fix mode 只执行 accepted 且符合轻量 fix 条件的 code-class `fix` DR。
34. `/sdd:code` 在 plan execution mode 中必须基于 `## 文档引用` 验证 plan `implements` 的 approved spec 或 accepted code-class DR；document-class DR 不允许进入 `/sdd:code`。
35. `/sdd:code` execution 和 verification 成功后将 plan 状态切换为 `done`，并在 plan implements accepted code-class DR 时关闭该 DR，设置 `closed_reason: committed` 和 `closed_at`。
36. `/sdd:code` 在 lightweight fix DR mode 成功后关闭该 DR，设置 `closed_reason: committed` 和 `closed_at`，且不查找、不要求、不修改 plan 状态。
37. `/sdd:code` 不创建或修订 PRD、spec、plan、DR 的设计正文，不修复 `## 文档引用` 表，不接受或 dismiss DR，不处理 document-class DR，不修改 `state.json`，不归档版本。
38. `/sdd:research` 写入 `docs/requirements/<topic-slug>-<yyyy-mm>.md`，不要求 active version，0 active version 时仍可运行，且不参与 version lifecycle。
39. `/sdd:research` 输出文档不写 `- 状态：...` 行，不写 version lifecycle 字段，不要求 `## 文档引用` 表，也不得创建 version-local 副本。
40. 当 PRD 或 spec 使用 research 文档作为正式来源时，必须在目标文档 `## 文档引用` 表中用相对 Markdown link、`project:requirements/<file>.md` locator 和 `derives_from` 或 `references` 关系记录该来源。
41. `/sdd:research` 不读取或修改 `state.json`，不创建或修改 PRD、spec、plan、DR，不关闭 DR，不生成 plan，不执行 code，不归档版本。
42. 主流程 skill 通过扫描 `docs/versions/v*/state.json` 发现唯一 active version。
43. 同版本引用使用来源文件目录相对 Markdown link。
44. 跨版本引用使用来源文件目录相对 Markdown link，并必须填写 locator。
45. Project-level requirements 引用使用 `project:requirements/<file>.md` locator。
46. spec、plan、DR、PRD 支持统一 `## 文档引用` 表。
47. 无引用时使用固定行 `| 未声明。 | - | - | - | - |`。
48. 关系类型只允许 `references`、`derives_from`、`implements`、`modifies`、`replaces`、`deprecates`。
49. plan 不得使用 `modifies`、`replaces`、`deprecates` 改变契约。
50. `INDEX.md` 只链接版本 `ARCHIVE.md`，不链接具体 spec、plan、DR 或 requirements。
51. `/sdd:archive` 不移动版本目录。
52. `/sdd:archive` 归档成功时生成或覆盖版本目录内的 `ARCHIVE.md`。
53. `/sdd:archive` 归档成功时将 `state.json.state` 从 `active` 改为 `archived`，并写入 `archived_at`。
54. `/sdd:archive` 归档成功时创建或更新 `docs/archive/INDEX.md`。
55. `/sdd:archive` 只从 `## 文档引用` 表机械提取 `文档引用摘要`，不从正文链接推断新关系。
56. `/sdd:archive` 在 blocking 引用检查失败时停止归档。
57. `/sdd:archive` 不修改 spec、plan、DR 的状态字段或正文。
58. `prd.md` 缺失不阻止归档。
59. 所有 `specs/*.md` 必须为 `approved`，所有 `plans/*.md` 必须为 `done`，所有 DR 的 Markdown 头部状态必须为 `closed`，才允许归档。
60. `dismissed` 和 `superseded` 不作为 DR `status`；`dismissed` 通过 `closed_reason: dismissed` 表达，`superseded` 通过 `superseded_by: <DR link or ID>` 表达。
61. 用户文档、模板、hooks、helper scripts、发布包和 contract tests 必须与本规格定义的 `docs/versions/vX.Y.Z/` 路径模型、version-local `state.json` 状态模型和 `## 文档引用` 表规则保持一致，不得把 `docs/vX.Y.Z/` 描述为当前结构。
62. 主流程 active version discovery 必须通过 `docs/versions/v*/state.json` 发现唯一 active version，不得通过扫描 `docs/v*` 推断。
63. `/sdd:archive` 成功后版本目录仍保留在 `docs/versions/vX.Y.Z/`，不得移动到 `docs/archive/vX.Y.Z/`。
64. `/sdd:doctor` 发现 `docs/vX.Y.Z/` 时，可以提示旧草案结构不属于当前模型，但不要求自动迁移。
65. 后续 Implementation Plan 必须覆盖 supporting assets 的具体文件清单、修改步骤和验证方式。

## 19. Open Follow-ups

本规格定稿后，需要另行完成 Implementation Plan。该计划应覆盖以下类别，而不是改变本规格的用户流程语义：

- 用户直接调用的 skills：`/sdd:init`、`/sdd:new`、`/sdd:status`、`/sdd:doctor`、`/sdd:archive`、`/sdd:prd`、`/sdd:spec`、`/sdd:plan`、`/sdd:dr`、`/sdd:triage`、`/sdd:code`、`/sdd:research`。
- Supporting assets：helper scripts、hooks、skill templates、README、发布包内容和 contract tests。
- Verification：覆盖路径模型、状态模型、引用表模板、引用关系枚举、引用检查、archive index 规则、0 active version 行为和 lightweight fix DR 行为。

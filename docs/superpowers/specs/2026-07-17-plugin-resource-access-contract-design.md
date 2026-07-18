# SDD Plugin 设计规格：Plugin Resource Access Contract

- 日期：2026-07-17
- 状态：draft
- 类型：Design Spec
- 目标：定义插件内本地资源访问的统一语义与契约，解决 `SKILL.md` 可被平台加载但脚本、模板、references、hooks 相关资源在执行期不能天然继承相同解析语义的问题。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 现有规格风格 | [2026-07-14-document-references-advanced-spec.md](./2026-07-14-document-references-advanced-spec.md) | - | 参考现有设计规格的结构、术语严谨度与验收表达方式 |
| references | 现有插件职责边界 | [2026-07-15-init-manual-dependency-install-design.md](./2026-07-15-init-manual-dependency-install-design.md) | - | 参考 skill、hook、script 职责边界与规范型设计文档写法 |
| references | 现有插件工作流设计 | [2026-07-11-sdd-plugin-mvp-workflow-spec-design.md](./2026-07-11-sdd-plugin-mvp-workflow-spec-design.md) | - | 参考插件主流程与文档型规范的表达方式 |

## 1. Problem

当前插件系统中，`SKILL.md` 的发现与加载由 Claude Code 插件机制负责，但插件内本地资源（如脚本、模板、references、hooks 相关文件）不会天然继承同样的解析语义。

这会导致同属一个 plugin 的资源在使用体验上表现不一致：

- `SKILL.md` 看起来“能访问”，因为平台知道如何发现并加载 skill。
- 一旦进入执行期，后续本地资源却常被按 `PWD` 或项目目录解释。
- 结果是行为依赖运行位置，可能在某些项目中偶发成功，在另一些项目中失败。
- 失败时往往只能看到模糊的 “file not found”，难以判断是 plugin root 缺失、路径语义错误，还是资源本身不存在。

这个问题的本质不是“脚本不能像 skill 一样被注册加载”，而是插件内本地资源缺少统一的访问契约。

## 2. Goals

本规格要实现以下目标：

1. 定义什么是 `Plugin Resource` 与 `Project Resource`。
2. 定义 `Plugin Root` 与 `Project Root` 的职责边界。
3. 定义执行期 consumer 访问插件内本地资源时必须满足的统一契约。
4. 定义严格失败语义：缺少上下文、路径语义错误、越界访问或资源不存在时立即失败。
5. 禁止对插件资源访问使用 `PWD`、project root 或其他隐式 fallback。
6. 让 skill、hook、script 以及其他执行期资源消费者对插件资源采用一致解释。
7. 让规范满足三个外部结果：语义一致性、可移植性、可诊断性。

## 3. Non-goals

本规格不处理以下事项：

- 不定义 Claude Code 如何发现、注册或加载 `SKILL.md`。
- 不要求把脚本改造成与 skill 相同的插件注册单元。
- 不规定本仓库某一次实现必须修改哪些文件。
- 不设计新的 marketplace 协议、插件发布协议或远程资源访问机制。
- 不覆盖业务文档、代码文件或项目内容本身的功能规范。
- 不把 `PWD` 重新包装成可接受的资源边界语义。

## 4. Core Principles

### 4.1 边界先于路径

任何本地资源访问都必须先判断资源属于哪个语义边界，再选择路径解析方式。

### 4.2 `Plugin Root` 是插件资源的全局边界

任何插件资源访问都必须以 `Plugin Root` 作为全局边界定义。插件资源不能脱离该边界单独讨论。

### 4.3 资源可在边界内相对自身解析

一旦资源边界已确定，consumer 可以相对自身位置解析邻近辅助资源。但这种能力只在所属边界内成立，不能替代边界本身。

这里的“相对自身解析”指：consumer 先已经拥有明确的 `Plugin Root` 或 `Project Root`，再在该边界内以自身文件位置作为局部导航起点解析邻近资源。它不是对 `PWD` 的替代，也不是未建立边界时的兜底策略。

### 4.4 插件资源与项目资源严格分离

插件资源按 `Plugin Root` 语义解析，项目资源按 `Project Root` 语义解析。二者不得因运行环境“碰巧可用”而混用。

### 4.5 禁止隐式 fallback

插件资源访问失败时，不得退回 `PWD`、`Project Root` 或其他未声明基准继续尝试。

### 4.6 平台加载与执行期访问分离

本规格不定义平台如何发现 `SKILL.md`，但 `SKILL.md` 一旦进入执行语境，其后续触发的本地资源访问必须受本规格约束。

## 5. Terms

### 5.1 `Plugin Resource`

指随插件分发、位于插件目录树内、由插件自身拥有和维护的本地资源。

典型包括：

- `scripts/`
- `skills/`
- `hooks/`
- 模板文件
- references
- 静态配置文件

### 5.2 `Project Resource`

指当前用户项目目录树内、由具体仓库拥有和维护的本地资源。

典型包括：

- `docs/`
- 源代码
- 项目配置文件
- 测试文件

### 5.3 `Plugin Root`

指当前插件安装后的根目录，是插件资源解析的全局边界。

### 5.4 `Project Root`

指当前用户正在操作的项目根目录，是项目资源解析的全局边界。

`Project Root` 必须由调用方显式建立、发现或传入，不能仅因为某个 `Execution-time Consumer` 当前运行在某个 `PWD` 中，就默认把该 `PWD` 视为项目根。

### 5.5 `Execution-time Consumer`

指在 skill 被加载之后，真正发起本地资源访问的执行期主体。

典型包括：

- shell script
- hook script
- 模板读取逻辑
- skill 触发的后续命令流程

### 5.6 `Resource-local Resolution`

指资源在已确定所属边界后，相对其自身位置解析邻近资源的能力。

例如：脚本相对自己的目录加载同一插件内的库文件。

## 6. Resource Model

所有本地资源访问在规范上必须先归类为以下两类之一：

- 插件资源访问
- 项目资源访问

模型规则如下：

1. 插件资源访问的权威边界是 `Plugin Root`。
2. 项目资源访问的权威边界是 `Project Root`。
3. `PWD` 不是任何一类资源访问的权威边界。
4. 在插件资源边界内，允许使用 `Resource-local Resolution`。
5. 在项目资源边界内，允许使用项目自身既有相对路径规则；但其前提仍然是 `Project Root` 已被显式建立，而不是把当前 `PWD` 直接视为项目根。
6. 任何实现都不得把“碰巧在当前目录能找到文件”视为满足规范。

## 7. Access Contract

### 7.1 Contract 1 — Boundary Declaration

任何 `Execution-time Consumer` 在访问本地资源前，必须能判定该访问属于插件资源还是项目资源。

调用方必须先显式声明或建立资源语义；如果资源意图尚未确定，则不得直接尝试路径拼接、文件查找或 fallback。

### 7.2 Contract 2 — Plugin Resource Base

若访问目标属于插件资源，consumer 必须拥有 `Plugin Root` 或等价的显式边界上下文。

### 7.3 Contract 3 — Project Resource Base

若访问目标属于项目资源，consumer 必须拥有 `Project Root` 或等价的项目上下文。

### 7.4 Contract 4 — No Implicit Base Switching

资源一旦被判定为插件资源，不得再转而使用 `Project Root` 或 `PWD` 解析。

资源一旦被判定为项目资源，不得再借用 `Plugin Root` 解析其项目路径语义。

### 7.5 Contract 5 — Local Resolution Within Boundary

已确定属于插件资源的目标，可以在 `Plugin Root` 边界内相对 consumer 自身位置解析辅助资源。

这种相对解析是边界内行为，不改变其插件资源访问的本质。它要求：

- consumer 先已经拥有明确的 `Plugin Root`；
- 相对自身位置的解析结果仍必须落在 `Plugin Root` 内；
- 这种局部解析能力不能替代资源分类，也不能作为缺少 `Plugin Root` 时的 fallback。

### 7.6 Contract 6 — `SKILL.md` Post-load Contract

本规格不约束 Claude Code 如何发现或加载 `SKILL.md`。

但一旦 `SKILL.md` 触发后续本地资源访问，该访问所属的 `Execution-time Consumer` 必须遵守本规格中的边界判定与解析契约。

### 7.7 Contract 7 — No Silent Fallback

当插件资源访问缺失 `Plugin Root`、越出插件边界、或目标不存在时，必须立即失败。

不允许静默改用 `PWD`、`Project Root` 或其他隐式基准继续尝试。

### 7.8 Contract 8 — Bootstrap Exception

本规格允许一个严格受限的 bootstrap 例外：在某些 `Execution-time Consumer` 尚未建立 `Plugin Root` 之前，可以通过该 consumer 自身已知的安装位置加载一个固定的 bootstrap helper，以建立 `Plugin Root`。

该例外必须同时满足以下条件：

- 仅允许用于建立 `Plugin Root` 本身；
- 仅允许加载固定、预先已知的 bootstrap helper；
- 不得用于访问业务资源、模板、references 或其他目标插件资源；
- 不得扩展为通用路径解析机制或 fallback；
- bootstrap 失败时必须立即失败，并报告无法建立 `Plugin Root`。

## 8. Normative Rules

### 8.1 先分类，后解析

任意本地资源访问都必须先判断目标属于 `Plugin Resource` 还是 `Project Resource`。

未完成分类前，不得直接进入路径拼接或文件查找。

### 8.2 插件资源必须以 `Plugin Root` 为边界

插件资源访问必须以 `Plugin Root` 作为全局解析边界。

任何插件资源访问都不得把 `PWD` 解释为插件根目录。

### 8.3 项目资源必须以 `Project Root` 为边界

项目资源访问必须以 `Project Root` 作为全局解析边界。

任何项目资源访问都不得因某个 consumer 位于插件目录中而改用插件路径语义。

### 8.4 允许边界内的相对自身解析

在资源边界已确定的前提下，consumer 可以相对自身位置解析邻近辅助资源。

该能力仅用于边界内导航，不构成对边界的替代。

### 8.5 禁止隐式 fallback

插件资源访问失败时，不得继续尝试 `PWD`、`Project Root` 或其他未声明基准。

项目资源访问失败时，也不得反向退回 `Plugin Root`。

### 8.6 平台加载不等于执行期豁免

即使 `SKILL.md` 由平台正常发现和加载，它触发的后续本地资源访问仍必须遵守统一契约。

### 8.7 结果必须可诊断

访问失败时，错误必须能说明失败类别，而不是只返回缺少上下文的 “file not found”。

### 8.8 Bootstrap 例外必须受限

如果实现采用 bootstrap helper 建立 `Plugin Root`，该 helper 只能用于建立边界上下文，不得承担通用插件资源解析职责，也不得把 bootstrap 过程扩展为对 `PWD` 或其他隐式基准的 fallback。

## 9. Failure Semantics

### 9.1 Missing Boundary Context

目标已被判定为插件资源，但 consumer 没有 `Plugin Root`。

处理要求：立即失败，并明确指出缺少插件边界上下文。

### 9.2 Boundary Mismatch

目标属于插件资源，却被按项目路径语义解析；或目标属于项目资源，却被按插件路径语义解析。

处理要求：立即失败，并指出资源分类与解析基准不一致。

### 9.3 Boundary Escape

解析过程试图越出 `Plugin Root` 或 `Project Root` 的合法边界。

处理要求：立即失败，并指出存在越界访问。

### 9.4 Missing Target Resource

边界和语义都正确，但目标资源不存在。

处理要求：立即失败，并报告标准化后的目标路径。

### 9.5 Ambiguous Resource Intent

调用方无法判断请求的是插件资源还是项目资源。

处理要求：立即失败，并要求调用方先显式建立资源语义。

## 10. Acceptance Criteria

### Scenario 1: 语义一致性

Given 同一个插件内存在 skill、hook 和 script 三类 consumer
When 它们分别访问同一类插件资源
Then 它们遵守同一边界语义，不因入口不同而改变解释方式

### Scenario 2: 可移植性

Given 用户在不同项目目录、不同 `PWD` 下触发同一个插件流程
When 该流程访问插件资源
Then 访问结果保持一致，不依赖当前工作目录碰巧正确

### Scenario 3: Skill 后续访问受约束

Given `SKILL.md` 已被平台成功加载
When 它触发后续脚本、模板或 references 访问
Then 这些访问仍按统一资源契约执行，而不是继承不明确的路径语义

### Scenario 4: 严格失败

Given 一个插件资源访问缺少 `Plugin Root`
When consumer 试图继续查找目标文件
Then 系统立即失败，且不得退回 `PWD` 或项目目录继续尝试

### Scenario 5: 可诊断性

Given 某次资源访问失败
When 用户查看错误
Then 用户能区分是边界缺失、语义错误、越界访问还是目标不存在

### Scenario 6: 项目资源分离

Given 同一流程同时访问插件模板和项目文档
When 两类资源被解析
Then 插件模板按 `Plugin Root`，项目文档按 `Project Root`，且两者不会互相污染

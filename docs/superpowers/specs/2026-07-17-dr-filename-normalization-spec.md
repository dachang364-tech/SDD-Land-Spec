# SDD Plugin 设计规格：DR Filename Normalization

- 日期：2026-07-17
- 状态：draft
- 类型：Design Spec
- 目标：把新建 Decision Record 的标准文件名从 `<tag>-NNNN-<slug>.md` 统一调整为 `NNN-<tag>-<slug>.md`，并明确 DR basename、DR ID、标题格式、plan 关联、lookup、hook 门控与 doctor 一致性检查的单一权威契约。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| modifies | DR naming / ID contract | [2026-07-13-dr-advanced-spec.md](./2026-07-13-dr-advanced-spec.md) | - | 本规格重定义新建 DR 的 basename、DR ID 与标题标识规则 |
| modifies | plan / DR matching contract | [2026-07-14-document-references-advanced-spec.md](./2026-07-14-document-references-advanced-spec.md) | - | 本规格把 code-class plan 与 DR 的匹配规则改写为基于完整新 DR ID 的机械匹配 |
| references | historical workflow background | [2026-07-11-sdd-plugin-mvp-workflow-spec-design.md](./2026-07-11-sdd-plugin-mvp-workflow-spec-design.md) | - | 用于说明旧 tag-first DR basename 的来源，但不作为本规格的当前命名依据 |

## 1. Context

当前系统对新建 Decision Record 的标准输出仍采用 tag-first basename：

```text
docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md
```

这一格式已经被多处文档、skill、脚本与测试隐式复用：

- `DR ID` 通常被视为 decision 文件去掉 `.md` 的 basename。
- `/sdd:plan` 的 code-class DR mode 使用 `plans/NNN-<dr-id>.md`。
- `/sdd:code` 允许以 DR ID 查找 matching plan 或 lightweight fix DR。
- `PreToolUse hook` 通过 plan basename 去掉最前面的 `NNN-` 推导 DR ID，再定位对应 decision 文件。
- `/sdd:doctor` 通过 plan basename 与 DR basename 的关系检查 plan / DR consistency。

实际期望已经变化：用户希望新建 decision 采用前置编号风格：

```text
NNN-<tag>-<slug>.md
```

与此同时，`specs/*.md` 与 `plans/*.md` 的命名体系已经满足预期，不应被一并重构。问题因此收敛为：如何仅重定义 decision/DR 的标准 basename 与相关查找契约，同时保持 plan 编号体系与 workflow 入口稳定。

当前实现中，DR 文件名、DR ID、DR 标题标识、plan basename、hook 字符串截取和 doctor 一致性描述之间存在较强耦合。因此在修改生成逻辑前，必须先通过一份单主题 spec 明确稳定边界，避免把 archive、reference tables、resource boundary 等其他已稳定契约重新打开。

## 2. Goals

1. 只重定义新建 DR 的标准 basename、DR ID 和标题标识格式。
2. 保持 `plans/*.md` 的命名体系与三位 `plan number` 规则不变。
3. 明确 `DR number` 与 `plan number` 是两套独立三位编号。
4. 把 `/sdd:plan`、`/sdd:code`、hook 与 `/sdd:doctor` 的 DR 查找规则统一到同一套机械契约。
5. 明确错误处理：超出编号上限、找不到唯一 DR、歧义匹配、非法输入时必须失败。
6. 明确 DR basename/DR ID 是稳定标识符，用户可修改业务标题，但不能把 basename 当作可自由编辑字段。
7. 使后续实现能够围绕单一标准格式更新 README、skills、脚本和测试。

## 3. Non-Goals

本规格不要求实现：

- 修改 `specs/*.md` 命名体系。
- 修改 `plans/*.md` 命名体系。
- 兼容历史旧格式 `fix-0001-slug.md`。
- 批量重命名历史 DR 文件。
- 为旧文件创建 alias、镜像副本或双写输出。
- 引入自动 migration / rename / backfill 机制。
- 修改 DR 生命周期状态模型。
- 重写 reference table 格式。
- 修改 `archive` 的资源边界模型。
- 引入 slug-based fuzzy lookup。
- 允许用户通过手工改 basename 的方式改变 DR 标识符。

本规格只约束未来新建 DR 的标准生成规则。历史文档、历史示例或已有旧格式文件不属于本规格的实现范围，也不应驱动当前契约回退成双格式模型。

## 4. Terminology

### 4.1 `DR file basename`

`DR file basename` 指 decision 文件名本身，不含目录路径。

本规格固定为：

```text
NNN-<tag>-<slug>.md
```

例如：

```text
002-fix-particle-background-full-page-distribution.md
```

### 4.2 `DR ID`

`DR ID` 指去掉 `.md` 后的完整 DR basename。

本规格固定为：

```text
NNN-<tag>-<slug>
```

例如：

```text
002-fix-particle-background-full-page-distribution
```

规则：

- `DR ID` 与 `DR file basename` 去掉 `.md` 后严格等价。
- 工具层不得把 `DR ID` 解释为“只有 slug”或“旧 tag-first basename”。
- `DR ID` 是所有 lookup、plan 关联、hook 与 doctor consistency 的唯一权威标识符。

### 4.3 `DR title identifier`

`DR title identifier` 指 DR 文档标题开头的结构化标识，而不是全文标题本身。

本规格固定为：

```text
DR-NNN-<tag>
```

例如：

```markdown
# DR-002-fix：Particle background full page distribution
```

规则：

- 标题标识只保留 `DR number` 与 `tag`。
- `slug` 不进入标题标识。
- 标题正文仍为人类可读的业务标题。

### 4.4 `Plan basename`

`Plan basename` 是 plan 文件名本身，不含目录路径。

本规格保持现有两种形式不变：

```text
<plan-number>-<slug>.md
<plan-number>-<dr-id>.md
```

例如：

```text
007-auth-timeout-retry.md
007-002-fix-particle-background-full-page-distribution.md
```

### 4.5 `Plan number`

`Plan number` 指 plan basename 开头的三位十进制编号。

规则：

- 范围：`001` 到 `999`
- 只在 `plans/*.md` 中递增分配
- 与 `DR number` 独立

### 4.6 `DR number`

`DR number` 指 DR basename 开头的三位十进制编号。

规则：

- 范围：`001` 到 `999`
- 只在 active version 的 `decisions/*.md` 中递增分配
- 与 `plan number` 独立

### 4.7 Identifier stability

`DR basename / DR ID` 是稳定标识符，不是自由编辑字段。

规则：

- 用户可以修改 DR 的业务标题。
- 业务标题修改不得反向触发 basename 改名。
- 工具不得依据标题变化重算 slug 或重写 DR basename。
- 如果未来需要支持 rename，应作为独立功能另行设计，不属于本规格。

## 5. Functional Requirements

### FR1. New DR naming

新建 DR 必须生成：

```text
docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md
```

约束：

- `NNN` 为三位十进制编号。
- `tag` 仅允许：

```text
fix | feat | chg | arch | spec | doc | typo
```

- `slug` 必须为非空的小写 kebab-case。
- `slug` 的权威输出只允许 ASCII 小写字母、数字和连字符。
- basename 中各部分必须按 `DR number -> tag -> slug` 顺序输出。

### FR2. New DR title format

DR 模板标题必须同步到前置编号风格。

示例：

```markdown
# DR-001-fix：Login null handling
# DR-002-fix：Particle background full page distribution
```

规则：

- 标题中的编号顺序必须与新 `DR ID` 一致。
- 标题标识格式固定为 `DR-NNN-<tag>`。
- 业务标题允许是人类可读文本，不要求与 slug 完全一致。
- 修改业务标题不应改变 DR basename 或 DR ID。

### FR3. DR number allocation

新建 DR 的编号分配规则必须明确：

1. 只在 active version 的 `decisions/*.md` 内分配。
2. 编号跨 tag 共享，不按 tag 分桶。
3. 使用当前最大 `DR number + 1`。
4. 新格式三位编号是唯一权威输出格式。
5. 若目录中没有任何 decision 文件，则从 `001` 开始。
6. 超过 `999` 时必须失败，不得 silently 生成四位或更长新格式。

示例：

```text
001-fix-login-null.md
002-feat-session-timeout.md
003-doc-release-note-wording.md
```

### FR4. No historical compatibility requirement

本规格不为旧 tag-first DR basename 提供兼容模型。

规则：

- 新建 DR 不允许输出旧格式 `<tag>-NNNN-<slug>.md`。
- `/sdd:plan`、`/sdd:code`、hook、doctor 的本规格定义只认新 `DR ID`。
- 不设计对旧格式的读取兼容、模糊映射或等价解析。
- 如果仓库中未来仍存在旧格式文件，应由独立迁移或清理任务处理，而不是在本规格中引入双轨逻辑。

### FR5. `/sdd:plan` compatibility

plan 体系保持不变：

- spec mode: `plans/<plan-number>-<slug>.md`
- code-class DR mode: `plans/<plan-number>-<dr-id>.md`

当 DR 使用新 ID：

```text
001-fix-login-null
```

对应 plan 示例必须为：

```text
plans/002-001-fix-login-null.md
```

本规格必须明确：

- 第一个 `002` 是 `plan number`。
- 第二个 `001` 是 `DR ID` 中的 `DR number`。
- 两套编号独立，不绑定、不要求对齐。

### FR6. `/sdd:code` lookup rules

`/sdd:code` 必须继续区分三种输入：

- `plan number`
- 完整 `plan basename`
- 完整 `DR ID`

对 `DR ID` 的识别规则：

- 只支持新格式 `NNN-<tag>-<slug>`。
- 精确 basename 匹配是唯一合法查找方式。
- 不允许根据 slug 做模糊匹配。
- 不允许猜测别名或猜测 tag。

行为：

1. 若输入为 `plan number`，查找唯一 `plans/NNN-*.md`。
2. 若输入为完整 `plan basename`，按精确 basename 查找。
3. 若输入为完整 `DR ID`，优先查找 matching plan：`plans/<plan-number>-<dr-id>.md`。
4. 若不存在 matching plan，则仅在满足 lightweight fix DR 前提时直接读取 `decisions/<dr-id>.md`。
5. 找不到唯一 plan 或唯一 DR 时必须失败。

### FR7. PreToolUse hook gating

Hook 对 code-class DR plan 的门禁必须保持，但其 DR 定位规则必须改为新定义：

- 当写入 `plans/<plan-number>-<dr-id>.md` 时：
  1. 解析出完整 `<dr-id>`
  2. 在同版本 `decisions/` 中查找唯一对应 decision 文件
  3. 读取其状态
  4. 仅 `accepted` 放行
  5. `drafting`、缺失、歧义都必须阻断

本规格明确：

- hook 不得再假设 `decisions/<dr-id>.md` 属于旧 tag-first basename 语义。
- hook 必须按本规格定义的 `DR ID` 规则定位唯一实际文件。
- 任何零命中、多命中、非法 `<dr-id>` 输入都必须失败。
- hook 失败时不得回退到 spec-mode，也不得把 code-class plan 误判为普通 feature/spec-mode plan。

### FR8. Doctor consistency rules

`/sdd:doctor` 的 plan / DR consistency 规则必须改写为：

- code-class plan 去掉最前面的 `plan number` 与连字符后，剩余部分必须等于完整 `DR ID`
- 不再使用“plan filename minus `NNN-` equals old DR slug”之类只适用于旧格式的描述

具体规则：

1. accepted code-class DR 且 `plan_required: yes` 时，必须存在某个 `plans/<plan-number>-<dr-id>.md`。
2. 该匹配关系以完整 `DR ID` 精确比较。
3. accepted lightweight fix DR（`tag: fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`）没有 plan 是合法状态。
4. 当 matching plan 已为 `done`，而 DR 仍为 `accepted` 时，doctor 应报告 close reminder。

### FR9. Document references and examples

未来实现中，所有“新建 DR 标准格式”的文档说明与示例必须切换为新 basename。

至少包括：

- README 的 DR 结构示例
- skill 文档中关于 `/sdd:dr`、`/sdd:plan`、`/sdd:code`、`/sdd:doctor` 的示例
- cross-version locator、reference table 或 relation 说明中涉及“新建 DR 标准输出格式”的例子
- hook / doctor / tests 中对 decision basename 的契约描述

本规格不要求先清理历史示例文件，但要求实现后的“标准生成规则”描述不得继续把旧格式写成当前 canonical output。

## 6. Error Handling

本规格显式定义以下失败行为。

### 6.1 DR creation overflow

当 active version 的最大 `DR number` 已为 `999` 时：

- 阻止新建 DR。
- 输出明确错误信息。
- 不得输出 `1000-...`、`0001-...` 或其他 fallback 格式。

### 6.2 `/sdd:plan <dr-id>` resolution failure

当 `<dr-id>`：

- 不符合新 `DR ID` 语法
- 找不到唯一 DR
- 命中多个候选
- 指向 document-class DR

则 `/sdd:plan` 必须失败，并输出明确错误说明。

### 6.3 `/sdd:code <dr-id>` resolution failure

当 `<dr-id>`：

- 不符合新 `DR ID` 语法
- 找不到唯一 DR
- 找不到唯一 matching plan，且也不满足 lightweight fix DR 直接执行前提
- 指向 document-class DR

则 `/sdd:code` 必须失败，并输出明确错误说明。

### 6.4 Hook resolution failure

当 hook 无法从 `plans/<plan-number>-<dr-id>.md` 解析出唯一 DR 时：

- 必须失败。
- 不得回退到 spec-mode。
- 不得自动放行。

### 6.5 Ambiguous or invalid identifiers

任何输入只要出现以下情况之一，都必须失败：

- 非法 `DR ID` 语法
- 非法 `plan basename` 语法
- 查找结果不唯一
- 依赖完整 basename 的地方发生局部匹配或模糊匹配

## 7. Compatibility Boundaries

本规格的兼容边界如下：

- 新建 DR 只允许新格式。
- plan 不改名。
- 不引入自动 rename / migration。
- 不引入 alias 文件。
- 不引入 slug-based fuzzy lookup。
- 不引入标题变化驱动 basename 更新。
- 不引入双格式并存的 canonical contract。

补充边界：

- 用户可以修改 DR 的业务标题。
- 用户不能把 basename 当作日常可编辑内容。
- basename / DR ID 一旦创建完成，即视为 workflow 级稳定标识符。

## 8. Design Consequences

采用本规格后，系统会收敛到一套更直接的识别模型：

```text
DR file basename  -> NNN-tag-slug.md
DR ID             -> NNN-tag-slug
Plan basename     -> plan-number-dr-id.md
Doctor match      -> strip plan-number- == dr-id
Hook match        -> parse dr-id from plan basename, then exact decision lookup
```

直接结果：

- 用户可见的 DR 文件名统一为前置编号风格。
- 标题标识与 basename 顺序保持一致。
- `/sdd:plan`、`/sdd:code`、hook、doctor 不再需要围绕旧 tag-first 语义解释字符串。
- 标题编辑与标识符稳定性解耦。

实现影响范围至少包括：

- `README.md`
- `skills/dr/SKILL.md`
- `skills/plan/SKILL.md`
- `skills/code/SKILL.md`
- `skills/doctor/SKILL.md`
- `scripts/lib/sdd-common.sh`
- `scripts/hooks/pre-tool-use.sh`
- `tests/test-common-library.sh`
- `tests/test-pre-tool-use.sh`
- `tests/test-skill-contracts.sh`
- `tests/test-reference-validation.sh`
- `tests/test-doctor-contract.sh`
- `tests/test-mvp-acceptance.sh`

## 9. Acceptance Criteria

以下条件全部满足时，本规格视为被正确实现：

1. `/sdd:dr fix "Login null"` 生成 `001-fix-login-null.md`。
2. 第二个新建 DR 生成 `002-...`。
3. DR 标题同步为 `# DR-001-fix：...` 风格。
4. `/sdd:dr accept 001-fix-login-null` 能定位新 DR。
5. `/sdd:plan 001-fix-login-null` 生成 `plans/NNN-001-fix-login-null.md`。
6. `/sdd:code 001-fix-login-null` 能定位 matching plan 或 matching DR。
7. hook 对 `plans/NNN-001-fix-...md` 正确执行 `accepted` 状态门禁。
8. 标题修改后，basename 与 plan 关联保持不变。
9. `DR number` 与 `plan number` 独立递增，不要求相等或对齐。
10. 当 `decisions/` 已存在 `999-...` 时，新建 DR 被阻止并报错。
11. README、skills、脚本与测试不再把旧 tag-first 格式写成“新建 DR 的标准输出格式”。

## 10. Recommended Implementation Verification

后续实现完成后，至少应验证：

```bash
bash tests/test-common-library.sh
bash tests/test-pre-tool-use.sh
bash tests/test-skill-contracts.sh
bash tests/test-reference-validation.sh
bash tests/test-doctor-contract.sh
bash tests/test-mvp-acceptance.sh
bash scripts/package-local.sh
git diff --check
```

## 11. Decision Summary

本规格采用以下设计立场：

- 新格式 `NNN-<tag>-<slug>.md` 是唯一标准输出。
- `DR ID` 等于去掉 `.md` 的完整 basename。
- `DR title identifier` 采用 `DR-NNN-<tag>`。
- `plan number` 与 `DR number` 是独立三位编号。
- `DR basename / DR ID` 创建后不可变；用户只可修改业务标题。
- 所有 lookup、hook、doctor 一律依赖完整新 `DR ID` 的精确匹配。

这使后续 implementation plan 可以聚焦单一主题：重写 decision 命名与相关查找契约，而不是把整个 SDD 生命周期再次整体重构。

# /sdd:init 手动依赖安装提示设计

## 1. 背景

当前 `/sdd:init` 在 [skills/init/SKILL.md](skills/init/SKILL.md) 中把 `scripts/install-deps.sh` 作为初始化流程的强制步骤：先执行脚本，失败后再要求用户手动执行同一个脚本。与此同时，[scripts/hooks/session-start.sh](scripts/hooks/session-start.sh) 在发现缺少 `superpowers` 或 `spec-kit` 时，也固定提示用户运行 `scripts/install-deps.sh`。

这种设计把“项目骨架初始化”和“依赖插件安装”绑死在一起，导致两个问题：

1. `/sdd:init` 的职责过重。它本应只负责把当前 Git 项目初始化为 SDD 项目，不应替用户决定或执行依赖安装方式。
2. 用户缺少选择权。即使用户已经知道如何通过 Claude CLI 手动安装依赖插件，也会被强制引导到 `scripts/install-deps.sh`。

本设计的目标是把依赖安装调整为“提醒 + 手动步骤”，不再由 `/sdd:init` 自动执行安装脚本，同时保持 `scripts/install-deps.sh` 作为可选辅助工具继续存在。

## 2. 目标

本次变更要实现以下结果：

1. `/sdd:init` 只负责创建 SDD 项目骨架，不再执行 `scripts/install-deps.sh`。
2. `/sdd:init` 成功后明确提醒用户：本插件依赖 `superpowers` 和 `spec-kit`，需要用户自行安装。
3. `session-start` 在依赖缺失时继续提醒，但不再把 `scripts/install-deps.sh` 作为唯一下一步，而是给出手动安装步骤。
4. README、TESTING、打包 README 与契约测试同步更新到新的提示口径。
5. `scripts/install-deps.sh` 保留，但降级为“可选便捷脚本”，不再是初始化成功的前置条件。

## 3. 非目标

本次变更不处理以下事项：

1. 不移除 `scripts/install-deps.sh`。
2. 不修改 `/sdd:new`、`/sdd:doctor`、`/sdd:status` 等其他 skill 的职责边界。
3. 不改变 `session-start` 对项目是否已初始化的提示逻辑。
4. 不新增自动检测“依赖插件版本是否符合最低要求”的行为。
5. 不改变插件打包结构或 marketplace 元数据模型。

## 4. 设计原则

### 4.1 `/sdd:init` 的职责边界

`/sdd:init` 的职责应限定为“把当前项目初始化为 SDD 项目”，包括：

- 创建 `docs/requirements/`
- 创建 `docs/versions/`
- 创建 `docs/archive/`
- 复制 `CONSTITUTION.default.md` 到 `docs/CONSTITUTION.md`

它不应再承担“依赖插件安装执行器”的角色。因此：

- `/sdd:init` 不执行 `scripts/install-deps.sh`
- `/sdd:init` 不因为缺少 `superpowers` / `spec-kit` 而失败
- `/sdd:init` 输出中需要明确告知用户后续应自行安装依赖插件

### 4.2 提示优先于自动副作用

依赖安装涉及用户的 Claude Code 环境，不属于当前 Git 项目目录内部的纯文档初始化。对这类环境级动作，应采用提示优先、由用户显式执行的策略：

- 告知缺少什么
- 告知安装方式
- 不隐式执行
- 不把一个脚本当成唯一入口

### 4.3 保留辅助脚本但不绑定主流程

`scripts/install-deps.sh` 仍可保留，作为快速安装两个依赖插件的便捷方式。文档中可以继续提到它，但必须明确：

- 这是可选辅助脚本
- 用户也可以直接运行 Claude CLI 的安装命令
- `/sdd:init` 与 `session-start` 不再要求必须运行这个脚本

## 5. 详细设计

### 5.1 `/sdd:init` 新流程

`/sdd:init` 的新流程如下：

1. 检查 `docs/CONSTITUTION.md` 是否已存在。
2. 如果已存在，停止并提示项目已初始化。
3. 创建项目级目录：
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
4. 复制 `CONSTITUTION.default.md` 到 `docs/CONSTITUTION.md`。
5. 报告已创建/确认的项目级路径。
6. 追加一个“依赖插件提醒”区块，说明需要用户自行安装：
   - `superpowers`
   - `spec-kit`
7. 在提醒区块中给出手动安装步骤，并补充说明 `scripts/install-deps.sh` 可作为可选辅助脚本。

### 5.2 `/sdd:init` 输出设计

`/sdd:init` 的输出分为两层：

第一层保持现有的骨架结果输出：

```text
docs/CONSTITUTION.md
docs/requirements/
docs/versions/
docs/archive/
```

第二层新增依赖提醒，要求同时满足以下条件：

1. 明确指出依赖插件名称：`superpowers`、`spec-kit`
2. 明确指出“请用户自行安装”
3. 提供至少一种直接可执行的手动安装路径
4. 可以附带说明 `scripts/install-deps.sh` 为可选脚本，但不得把它描述成必需步骤

推荐文案风格如下：

```text
依赖插件提醒：
- 本插件依赖 Claude Code plugins：superpowers、spec-kit
- 请按 README 安装说明手动安装上述依赖插件
- 如需快捷安装，也可以自行运行 scripts/install-deps.sh
```

这里推荐把“直接安装命令”放在 README，而 `/sdd:init` 输出只提示阅读 README 安装说明，避免在 skill 正文里硬编码过多命令细节。这样技能提示更短，文档维护点也更集中。

### 5.3 `session-start` 新提示策略

`scripts/hooks/session-start.sh` 继续执行依赖检测，但提示方式改为提醒型：

- 缺少 `superpowers` 时：提示用户缺少该依赖插件，并参考 README 中的手动安装步骤
- 缺少 `spec-kit` 时：提示用户缺少该依赖插件，并参考 README 中的手动安装步骤
- 不再输出“请运行 scripts/install-deps.sh”
- 项目未初始化时，继续提示运行 `/sdd:init`

推荐文案风格如下：

```text
SDD Plugin: 缺少依赖 superpowers；请按 README 安装说明手动安装该插件。
SDD Plugin: 缺少依赖 spec-kit；请按 README 安装说明手动安装该插件。
```

这个文案强调“缺什么”和“去哪装”，但不替用户决定必须通过哪个脚本安装。

### 5.4 README 调整

README 中关于依赖安装的说明需要改成“双路径但不强制脚本”的结构：

1. 保留依赖插件列表：`superpowers`、`spec-kit`
2. 在本地安装章节中先说明用户需要先安装依赖插件
3. 给出两种路径：
   - 手动用 Claude CLI 安装
   - 可选地运行 `scripts/install-deps.sh`
4. 明确说明：`/sdd:init` 不会自动安装依赖插件，只会提示用户完成安装

README 应继续作为手动安装步骤的权威说明来源。这样 `session-start` 和 `/sdd:init` 都可以稳定引用“README 安装说明”，而不需要把完整命令分散复制到多个地方。

### 5.5 打包 README 调整

`scripts/package-local.sh` 当前会生成一个包内 README。该 README 也包含安装说明，因此必须同步到与仓库 README 一致的口径：

- 依赖插件需要用户自行安装
- `scripts/install-deps.sh` 是可选便捷脚本
- 不要让打包产物 README 暗示 `/sdd:init` 会自动安装依赖

### 5.6 TESTING 调整

`TESTING.md` 需要把 `/sdd:init` 的手动验收口径更新为：

- `/sdd:init` 创建项目骨架
- `/sdd:init` 不自动安装依赖插件
- `/sdd:init` 会输出依赖安装提醒

必要时可增加一条手工检查：确认 `/sdd:init` 输出包含“需要手动安装 `superpowers` / `spec-kit`”之类的提示。

## 6. 影响文件范围

本设计预期影响以下文件：

1. `skills/init/SKILL.md`
2. `scripts/hooks/session-start.sh`
3. `README.md`
4. `TESTING.md`
5. `scripts/package-local.sh`
6. 与上述行为相关的 shell contract tests，例如：
   - `tests/test-skill-contracts.sh`
   - `tests/test-package-local.sh`
   - 如已有覆盖 init / session-start 提示的测试，也应一并更新

## 7. 验收标准

本次变更完成后，必须满足以下验收标准：

1. `/sdd:init` 在依赖插件缺失时仍能成功创建：
   - `docs/CONSTITUTION.md`
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
2. `/sdd:init` 不执行 `scripts/install-deps.sh`。
3. `/sdd:init` 输出中明确提示用户需要手动安装 `superpowers` 和 `spec-kit`。
4. `session-start` 在依赖缺失时只做提醒，不再要求运行 `scripts/install-deps.sh`。
5. README 与打包 README 都说明：
   - 依赖插件需用户自行安装
   - `scripts/install-deps.sh` 是可选辅助脚本
6. `TESTING.md` 的手动验收步骤与新行为一致。
7. 相关 contract tests 更新后通过，能够阻止未来回归到“强制执行 install-deps.sh”的旧行为。

## 8. 风险与缓解

### 风险 1：行为改了，但文档还在说 `/sdd:init` 会装依赖

缓解：README、TESTING、打包 README、skill contract tests 必须一起更新。

### 风险 2：`session-start` 文案改了，但测试没覆盖

缓解：把新提示口径写进 contract tests，至少断言不再出现“请运行 scripts/install-deps.sh”这类旧文案。

### 风险 3：用户不知道如何手动安装依赖

缓解：README 保持完整、直接可执行的安装步骤；`/sdd:init` 和 `session-start` 都统一指向 README 安装说明。

## 9. 推荐实现策略

实现时应采用最小变更策略：

1. 先更新 skill 与 hook 契约文字
2. 再更新 README / TESTING / 打包 README
3. 最后更新 shell contract tests
4. 跑完整相关测试，确认行为与文档一致

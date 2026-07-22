---
name: review
description: 作为受管 SDD 文档的手工 review 入口，调用共享 review runner 并向用户交付 review 回执。用户请求复审 research、PRD、DR、spec 或 plan 文档时使用。
---

# /sdd:review

`/sdd:review` 是手工入口与用户回执层。/sdd:review 是手工入口。当前 Skill 只负责手工触发 review、展示结果并承接用户回执。

## 职责

- 接收 `/sdd:review <doc-path>`，将请求交给共享 review runner。
- 展示 runner 返回的结构化 review 结果，并承接需要用户确认的回执。
- `PostToolUse Hook` 是运行时集成相关机制；当前 Skill 不定义或承担自动 review 的触发职责。
- review 的执行由共享 review runner 与 `doc-reviewer` 承接；当前入口不展开其内部实现。

## 入口约束

1. 仅接受受支持的活动版本文档路径；不支持时提示“不是受支持的 SDD 文档路径”。
2. archived version 的文档不得执行 `/sdd:review`。
3. 项目必须已初始化，且 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 可用；缺失时提示运行 `/sdd:init`，不得使用 Plugin 内置资产替代。
4. 不新增命令名，也不改变项目模板、agent 或 runner 的既有运行时合同。

## 委托与回执

手工入口调用 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner。runner 使用项目级资产并委托 `agents/doc-reviewer.md` 定义的 `doc-reviewer`；入口不复制 runner 的内部输入、路由或执行细节。

将 runner 的结果作为用户回执：说明已评审文档、结果状态、自动修复摘要、剩余问题及是否需要用户确认。结果包含 `requires_user_confirmation=true` 时，先获取用户确认；写回后由 runner 重新复审。

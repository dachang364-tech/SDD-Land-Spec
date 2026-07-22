---
name: review
description: Review and improve research, PRD, DR, spec, or plan documents. Use for /sdd:review as the manual review entry and user receipt layer for managed SDD documents.
---

# /sdd:review

`/sdd:review` 是受管 SDD 文档的手工 review 入口与用户回执层。

## 职责

- 接收 `/sdd:review <doc-path>`，将请求交给共享 review runner。
- 展示 runner 返回的结构化 review 结果，并承接需要用户确认的回执。
- 自动 review 由 `PostToolUse Hook` 在文档写入后触发；当前 Skill 不承担自动触发、路由或修复实现。
- review 的类型识别、校验、执行策略与 `doc-reviewer` 调用由共享 review runner 负责。

## 入口约束

1. 仅接受受支持的活动版本文档路径；不支持时提示“不是受支持的 SDD 文档路径”。
2. archived version 的文档不得执行 `/sdd:review`。
3. 项目必须已初始化，且 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 可用；缺失时提示运行 `/sdd:init`，不得使用 Plugin 内置资产替代。
4. 不新增命令名，也不改变项目模板、agent 或 runner 的既有运行时合同。

## 委托与回执

手工入口调用 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner。runner 使用项目级资产并委托 `agents/doc-reviewer.md` 定义的 `doc-reviewer`；入口不复制 runner 的内部输入、路由或执行细节。

将 runner 的结果作为用户回执：说明已评审文档、结果状态、自动修复摘要、剩余问题及是否需要用户确认。结果包含 `requires_user_confirmation=true` 时，先获取用户确认；写回后由 runner 重新复审。

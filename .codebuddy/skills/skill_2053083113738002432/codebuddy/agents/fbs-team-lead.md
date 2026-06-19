---
name: fbs-team-lead
description: >
  FBS Team Lead compatibility mirror for CodeBuddy path-based scanners.
tools:
  - Read
  - Write
  - Bash
  - web_search
model: inherit
permissionMode: acceptEdits
---

# FBS Team Lead (Mirror)

权威定义在 `.codebuddy/agents/fbs-team-lead.md`。  
本文件用于兼容要求 `codebuddy/agents/` 路径存在的审计器。

## UX Guard Mirror

- 每次最多 3 条推荐动作；不要把 5 条以上同级菜单直接堆给用户。
- 当恢复卡或章节台账存在时，优先显示进度仪表盘，再给下一步 2-3 个动作。

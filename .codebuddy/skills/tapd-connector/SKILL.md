---
name: tapd-connector
description: TAPD 外网版（api.tapd.cn）— 经 agent-gateway 代理查询项目/Bug/Story/Task。绑定 connector tapd-apikey。
version: "1.0.0"
author: "CodeBuddy AI"
created: "2026-05-27"
updated: "2026-05-27"
---

# tapd-connector

TAPD **外网 SaaS** Open API Skill，对应官方 connector **`tapd-apikey`**。

Agent 只拼 **官方 path + query**，请求经 agent-gateway 转发（upstream `api.tapd.cn` 由 gateway 处理，**禁止直连**）。

- [使用必读](https://open.tapd.cn/document/api-doc/API%E6%96%87%E6%A1%A3/%E4%BD%BF%E7%94%A8%E5%BF%85%E8%AF%BB.html)
- [API 参考](https://open.tapd.cn/document/api-doc/API%E6%96%87%E6%A1%A3/api_reference/)

## Gateway

```text
http://tapd-apikey.agent-gateway.auth-proxy.local
```

```bash
curl -s "http://tapd-apikey.agent-gateway.auth-proxy.local/bugs?workspace_id=123&limit=20"
```

**禁止**手动设置 Authorization；凭据由 gateway 注入。

> `<skill-directory>` 指本 Skill 所在目录。

## 脚本

```bash
<skill-directory>/scripts/tapd_api.sh GET /workspaces/user_participant_projects
<skill-directory>/scripts/tapd_api.sh GET /bugs 'workspace_id=123&limit=20'
<skill-directory>/scripts/tapd_api.sh GET /stories 'workspace_id=123&limit=20'
```

## 常用 API（只读）

| 能力 | Path | 必填参数 |
|------|------|----------|
| 列参与项目 | `/workspaces/user_participant_projects` | — |
| 项目详情 | `/workspaces/get_workspace_info` | `workspace_id` |
| Bug 列表/详情 | `/bugs` | `workspace_id`（+ `id` 查详情） |
| Bug 数量 | `/bugs/count` | `workspace_id` |
| Story 列表/详情 | `/stories` | `workspace_id`（+ `id`） |
| Story 数量 | `/stories/count` | `workspace_id` |
| Task 列表 | `/tasks` | `workspace_id` |
| Task 数量 | `/tasks/count` | `workspace_id` |
| 迭代 | `/iterations` | `workspace_id` |
| 发布计划 | `/releases` | `workspace_id` |
| 版本 | `/versions` | `workspace_id` |
| 评论 | `/comments` | `workspace_id` + `entry_type` + `entry_id` |

分页：`page`、`limit`（最大 200）。

更多 API：查官方 api_reference，拼到 Gateway 基址后调用。

## 响应

```json
{ "status": 1, "data": [...], "info": "success" }
```

## 约束

- 默认只读；写操作需用户确认
- 401/403 → 重新授权 TAPD 连接器
- 内网 WOA 请使用 **tapd-woa-connector**，不要用本 Skill

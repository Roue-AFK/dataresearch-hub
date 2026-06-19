# WorkBuddy 官方审核包说明（v3.0.0）

- **版本**：`3.0.0`
- **状态**：3.0 候选提审包，基于 2.1.2 运行态兼容升级
- **审核包**：`dist/fbs-bookwriter-v300-workbuddy.zip`
- **校验报告**：`dist/fbs-bookwriter-v300-workbuddy.verification.json`
- **通道清单**：`workbuddy/channel-manifest.json`
- **配套 CodeBuddy 包**：`dist/fbs-bookwriter-v300-codebuddy.zip`

## 本次核心变化（相对 2.1.2）

- 报告驱动的 P0 后处理链：排版/导出预检、去 AI 味对照、后处理回归样稿。
- 跨会话恢复感知：`resumeProgressCard` 已接入 `intake-router` / `session-exit`。
- 权益来源观测：乐包/会员脚本支持 `benefitSource`、`creditsState`，为 API2 主后台和本地兜底区分来源。
- 3.0 overlay references：在不删除 2.1.2 完整规范的前提下，新增轻量入口层。

## 打包校验关注点

重点核对以下文件已进入 ZIP：

1. `workbuddy/channel-manifest.json`（version: 3.0.0）
2. `.codebuddy-plugin/plugin.json`（version: 3.0.0）
3. `.codebuddy/providers/provider-registry.yml`
4. `references/02-workflows/post-draft-pack.md`
5. `references/04-service/event-taxonomy.md`
6. `scripts/layout-preflight.mjs`
7. `scripts/de-ai-diff.mjs`
8. `scripts/event-writer.mjs`

以 `dist/fbs-bookwriter-v300-workbuddy.verification.json` 为最终校验真值。

## 提交建议

提交 WorkBuddy 官方审核时，优先附上：

1. `dist/fbs-bookwriter-v300-workbuddy.zip`
2. `dist/fbs-bookwriter-v300-workbuddy.verification.json`
3. `workbuddy/channel-manifest.json`
4. 本说明文件 `releases/workbuddy-review-v3.0.0.md`

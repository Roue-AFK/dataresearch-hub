# CodeBuddy 插件包说明（v3.0.0）

- **版本**：`3.0.0`
- **状态**：3.0 候选插件包，兼容 WorkBuddy 主体能力
- **产物**：`dist/fbs-bookwriter-v300-codebuddy.zip`
- **校验报告**：`dist/fbs-bookwriter-v300-codebuddy.verification.json`
- **通道清单**：`codebuddy/channel-manifest.json`
- **插件元数据**：`.codebuddy-plugin/plugin.json`（plugin-id: `fbs-bookwriter-v300`）

## 本次核心变化（相对 2.1.2）

- 与 WorkBuddy 主包保持同一 3.0 版本面与 overlay references。
- `resumeProgressCard` 与后处理最小脚本可在宿主机读面直接消费。
- `.codebuddy/agents/`、`.codebuddy/providers/provider-registry.yml`、`.codebuddy-plugin/plugin.json` 已补齐为可分发目录。

## 构建入口

- `npm run pack:codebuddy`
- `npm run pack:release -- --codebuddy`

## 提交 / 自测建议

1. 运行 `npm run pack:codebuddy`
2. 核查 `dist/fbs-bookwriter-v300-codebuddy.verification.json`
3. 重点确认 `.codebuddy-plugin/plugin.json`、`.codebuddy/providers/provider-registry.yml`、`codebuddy/channel-manifest.json` 已进入 ZIP 且版本一致

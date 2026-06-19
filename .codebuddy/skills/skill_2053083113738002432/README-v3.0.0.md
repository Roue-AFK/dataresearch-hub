# FBS-BookWriter v3.0.0 候选提审说明

> **福帮手出品 | 高质量长文档手稿工具链**：面向中文长文档生产的兼容升级版，重点加强成稿后处理、跨会话恢复感知、乐包/会员后台来源标注和 Windows CLI/JSON 稳定性。

## 版本定位

- **版本**：`3.0.0`
- **定性**：在 `2.1.2` 市场运行态基础上做兼容升级，不删老能力；把 3.0 重点收敛到“用得久、改得好、导得美”。
- **正式产物**：WorkBuddy Marketplace 主包（默认 `npm run pack:release`）；如需 CodeBuddy 包，执行 `npm run pack:codebuddy`。
- **WorkBuddy 包（示例名）**：`dist/fbs-bookwriter-v300-workbuddy.zip`
- **CodeBuddy 包（示例名）**：`dist/fbs-bookwriter-v300-codebuddy.zip`
- **plugin-id（SKILL frontmatter）**：`fbs-bookwriter-v300`

## 3.0 核心变化

- 成稿后处理最小链：新增 `layout-preflight.mjs`、`de-ai-diff.mjs`、回归样稿与后处理结果卡。
- 恢复/进度卡接线：`intake-router` 与 `session-exit` 输出 `resumeProgressCard`，显式告诉用户进度已保存和下一步建议。
- 乐包/会员链路增强：`verify-member.mjs` 与 `entitlement.mjs` 返回 `benefitSource` / `creditsState`，为 API2 主后台与本地兜底区分来源。
- 3.0 overlay references：增加轻量入口文档，减少首屏重型规范负担，同时保留 2.1.2 完整工作流。

## 部署自检

```bash
npm install --omit=dev
node scripts/env-preflight.mjs --json
node scripts/windows-cli-json-smoke.mjs
```

## 证据文件

- `data/fbs-bookwriter-3.0-validation-report.json`
- `data/fbs-bookwriter-3.0-smoke-report.json`
- `data/fbs-bookwriter-3.0-intake-router-resume.json`
- `data/fbs-bookwriter-3.0-session-exit.json`

## 延伸阅读

- [`releases/workbuddy-review-v3.0.0.md`](./releases/workbuddy-review-v3.0.0.md)
- [`releases/codebuddy-review-v3.0.0.md`](./releases/codebuddy-review-v3.0.0.md)
- `详细设计文档位于工作区 docs/ 目录，不随审核 ZIP 分发。`

# 排版导出预检报告
- 输入文件：`E:\FBS001\work\fbs-bookwriter-3.0-candidate\fixtures\regression\post-draft\sample-layout.md`
- 分析来源：`E:\FBS001\work\fbs-bookwriter-3.0-candidate\fixtures\regression\post-draft\sample-layout.md`
- 模板：`default`
- 结果：`ok`
## 结构指标
- 行数：24
- 标题数：6
- 首个标题行：1
- 最长行长度：78
- 最大连续空行：1
## 检查项
| 项目 | 状态 | 说明 |
| --- | --- | --- |
| title_heading | ok | 前 1 行内检测到标题型标题 |
| toc_or_outline | ok | 存在目录或足够的标题层级 |
| blank_page_risk | ok | 未发现连续空行堆积 |
| margin_risk | ok | 长行长度可控 |
| title_page_hint | ok | 检测到标题页或封面信号 |
## 建议
- 继续用宿主预览或 HTML 预览链做一次人工检查，确认标题页、目录和分页效果。
# DataResearch Hub v15.0.3 — 新项目(精简版)

## 新仓库
GitHub: https://github.com/Roue-AFK/dataresearch-hub

## 项目大小
268K（原 xianyu-tool 4.3M，去除了 .git 历史膨胀）

## 文件结构
```
dataresearch-hub/
  main.py              # 入口
  gui/main_window.py   # 主窗口 (Slate Professional 暗色主题)
  core/
    config.py          # 配置
    database.py        # SQLite 数据库
    crawler.py         # 闲鱼爬虫
    researcher.py      # AI 市场调研
    analyzer.py        # 数据分析 (jieba)
    exporter.py        # Excel/CSV 导出
    assistant.py       # AI 对话助手
```

## 功能
- 🐟 闲鱼: 数据采集 / AI对话 / 数据分析 / 调研报告
- 🎵 抖音: 热门话题 / AI调研 / 拟稿话术
- 📕 小红书: 笔记分析 / 关键词追踪 / AI调研
- ⚙️ 设置面板: AI配置 / 防封策略 / 检查更新

## 启动
```bash
git clone https://github.com/Roue-AFK/dataresearch-hub.git
cd dataresearch-hub
pip install -r requirements.txt
python main.py
```

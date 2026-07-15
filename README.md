# flutter_zero_doc

Flutter Zero 项目的**集中文档仓库**（仅包含文档，由 GitHub Pages 托管）。

- 文档站地址（待补充）：`https://<your-docs-site>/`
- 源码仓库：
  - `flutter_zero_app` —— 示例应用（模板落地后的真实项目样例）
  - `flutter_zero_cli` —— 脚手架工具 `fluzer`
  - `flutter_zero_template` —— 纯模板源（Mason Brick）

## 本地预览

```bash
pip install mkdocs-material
mkdocs serve
# 浏览器打开 http://localhost:8000
```

## 目录结构

```
flutter_zero_doc/
├── mkdocs.yml                 # 站点配置（导航 / 主题）
├── .github/workflows/
│   └── deploy.yml             # push 到 main 自动部署 GitHub Pages
├── docs/
│   ├── index.md               # 首页 / 总览
│   ├── architecture/          # 架构说明（目录结构 + MVI 设计 + 内部机制）
│   ├── getting-started/       # 快速上手（CLI 创建项目 / 生成模块 / add_counter）
│   ├── effect-system/         # Effect 系统 + Notifiers 系统设计
│   ├── cli/README.md          # CLI 参考（由 flutter_zero_cli 仓库迁移）
│   ├── release.md             # 发布流程
│   └── versioning-*.md         # 版本管理规则
└── LICENSE
```

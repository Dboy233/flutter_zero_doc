# flutter_zero_doc

> 🌐 简体中文 | [English](README.md)

Flutter Zero 项目的**集中文档仓库**（仅包含文档，由 GitHub Pages 托管）。

- 文档站地址：[Flutter Zero 文档](https://dboy233.github.io/flutter_zero_doc/)
- 源码仓库：
  - `flutter_zero_app` —— 示例应用（模板落地后的真实项目样例）
  - `flutter_zero_cli` —— 脚手架工具 `fluzer`
  - `flutter_zero_template` —— 纯模板源（Mason Brick）

## 本地预览

```bash
pip install mkdocs-material mkdocs-static-i18n
mkdocs serve
```

## 目录结构

```
flutter_zero_doc/
├── mkdocs.yml                 # 站点配置（导航 / 主题 / i18n 插件）
├── .github/workflows/
│   └── deploy.yml             # push 到 main 自动部署 GitHub Pages
├── docs/
│   ├── zh/                    # 中文文档（默认语言 → 站点根 /）
│   │   ├── index.md           # 首页 / 总览
│   │   ├── architecture/      # 架构说明
│   │   ├── getting-started/   # 快速上手
│   │   ├── effect-system/     # Effect 系统 + Notifiers 设计
│   │   ├── cli/README.md      # CLI 参考
│   │   ├── release.md         # 发布流程
│   │   └── versioning-*.md     # 版本管理规则
│   ├── en/                    # 英文文档（→ /en/），结构与 zh 镜像
│   ├── images/                # 共享图片资源（两语言共用，留在 docs 根）
│   ├── stylesheets/           # 共享 CSS
│   └── javascripts/           # 共享 JS
└── LICENSE
```

### 新增 / 修改文档

- 在 `docs/zh/` 下改中文，在 `docs/en/` 下改对应英文（结构、文件名需与 `zh` 镜像一致）。
- 共享资源（图片、CSS、JS）放在 `docs/` 根目录对应文件夹，两个语言通过相对路径共用。
- 导航菜单（`nav`）的标题翻译在 `mkdocs.yml` 的 `plugins.i18n.languages[en].nav_translations` 中维护。
- 增删页面后同步更新 `mkdocs.yml` 的 `nav`。

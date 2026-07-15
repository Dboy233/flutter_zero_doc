# Flutter Zero 文档

Flutter Zero 是一套 **企业级 Flutter MVI 模板**，由三个独立仓库协作：

| 仓库 | 角色 |
|------|------|
| `flutter_zero_app` | 示例应用（模板落地后的真实项目样例，含 `home` 模块演示） |
| `flutter_zero_cli` | 脚手架工具 `fluzer`（创建项目、生成功能模块） |
| `flutter_zero_template` | 纯模板源（Mason Brick），`fluzer` 由此渲染出项目与模块骨架 |

> 文档站地址（占位，待补充）：`https://<your-docs-site>/`

## 文档导航

- [架构说明](architecture/) —— `fluzer` 生成后的项目目录结构、MVI 如何设计、内部工作机制
- [快速上手](getting-started/) —— 用 `fluzer` 创建项目、生成模块、编写最小 `add_counter` 示例
- [Effect 与 Notifiers 系统](effect-system/) —— 一次性副作用与通知服务的设计
- [CLI 参考](cli/) —— `fluzer` 命令、目录结构、配置
- [发布流程](release/) / [CLI 版本管理](versioning-cli.md) / [模板版本管理](versioning-template.md)

!!! note "关于网络层"
    本文档基于当前代码编写。网络请求封装（`DioClient`、拦截器、`ErrorHandler`）与错误归一化属于数据层细节，本文档不展开，未来可能调整；业务侧只需关心 Repository 抛出的异常类型（如 `NetworkException`）。

# Flutter Zero 文档

Flutter Zero 是一套 **企业级 Flutter MVI 模板**，由三个独立仓库协作：

| 仓库 | 角色 |
|------|------|
| `flutter_zero_app` | 示例应用（模板落地后的真实项目样例，含 `home` / `counter` / `search` / `login` / `settings` 模块演示） |
| `flutter_zero_cli` | 脚手架工具 `fluzer`（创建项目、生成功能模块、检查更新） |
| `flutter_zero_template` | 纯模板源（Mason Brick），`fluzer` 由此渲染出项目与模块骨架 |

> 文档站地址（占位，待补充）：`https://<your-docs-site>/`

---

## 设计思想

模板围绕两条主线构建，所有封装都服务于此：

1. **单向数据流（MVI）**：用户操作 → `Event`（Intent）→ `Bloc`（ViewModel）→ `State`（ViewState）→ `View` 纯函数渲染。状态是唯一渲染来源，UI 永远只读取状态、发射意图。
2. **副作用与状态分离**：Toast / Loading / 弹窗等一次性 UI 行为走独立的 `Effect` 通道，**不污染** `State`，也不存在单槽覆盖 / 重复投递。
3. **错误归一化**：底层 `DioException` 等传输层异常被统一转换为 `AppException`，再封装为 `Result<T>`（成功 / 失败 / 取消），业务层只处理三种显式终态，不再写 `try/catch` 样板。

---

## 开箱即用的封装积木

| 积木 | 位置 | 解决什么 |
|------|------|----------|
| 四个 BLoC Mixin | `core/bloc/` | 可等待事件、自动取消网络、副作用流、统一错误处理 |
| Effect 系统 | `core/effect/` | `ToastEffect` / `DialogEffect` / `LoadingEffect` + 责任链处理 |
| Notifiers 系统 | `core/notifiers/` | 无 `BuildContext` 也能弹 Toast / Loading（桥接 `BuildContext`） |
| 错误体系 | `core/error/` + `core/result/` | `AppException` + `Result<T>` + `ErrorHandler` + `AppErrorCodes` |
| `BaseRepository` | `core/storage/` | 解析响应、统一抛出 `BusinessException` / `ParseException` |
| 三文件 DI | `core/di/` | 基础设施注册、模块自动注入、实现可替换 |

---

## 文档导航

- **[快速上手](getting-started/)** —— 安装 `fluzer`、创建项目、生成功能模块，并端到端写完一个功能模块。
- **[架构设计](architecture/)**
  - [总览与分层](architecture/) —— 三仓库关系、目录结构、MVI 落地、单向数据流、分层边界。
  - [BLoC 四个 Mixin](architecture/bloc-mixins.md) —— `BlocAwaitMixin` / `BlocCancelTokenMixin` / `BlocEffectMixin` / `BlocErrorHandlerMixin` 的用法。
  - [Effect 与 Notifiers](effect-system/index.md) —— 一次性副作用通道与通知服务。
  - [错误处理与 Result](architecture/error-handling.md) —— 异常归一化、`Result<T>`、业务状态码处理。
  - [依赖注入](architecture/dependency-injection.md) —— `get_it` 三文件约定与模块自动注册。
- **[CLI 参考](cli/)** —— `fluzer` 命令、目录结构、配置、调试环境变量。
- **发布与版本** —— [发布流程](release.md) / [CLI 版本管理](versioning-cli.md) / [模板版本管理](versioning-template.md)。

!!! note "关于网络层"
    网络请求封装（`DioClient`、拦截器）属于数据层细节，本身不在文档主体展开；业务侧只需关心 `Repository` 暴露的方法与抛出的异常类型（`AppException` 及其子类）。

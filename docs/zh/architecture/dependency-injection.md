# 依赖注入

模板用 `get_it` 做服务定位，DI 由**三个文件协作**，把「框架维护区」与「用户手写区」分离，从而让 `fluzer new` 能自动注入新模块而不会覆盖你的手写代码。

相关文件：`core/di/`。

---

## 1. 三个文件的职责

| 文件 | 角色 | 谁改 |
|------|------|------|
| `get_it_instance.dart` | 全局 `getIt` 实例 | 框架（不动） |
| `injection_base.dart` | `InjectionBase` 抽象类：`registerAll` + `registerFeatureModules`（脚本自动维护区） | `fluzer new` 自动写入 `XxxModule.register(getIt)` |
| `injection.dart` | `Injection extends InjectionBase`：实现 `registerBaseDependencies`（基础设施）+ `registerUserDependencies`（自定义） | **你**手写 |

### 注册顺序

`main.dart` 调用 `getIt.allReady()` 前的顺序由 `registerAll` 固定：

```dart
Future<void> registerAll() async {
  await registerBaseDependencies(); // 1. 基础设施：storage/auth/network/notifiers/l10n/theme
  await registerFeatureModules();   // 2. 功能模块（含 SharesRepositories.register）
  await registerUserDependencies(); // 3. 你自己的第三方 SDK / 自定义依赖
  await getIt.allReady();
}
```

---

## 2. 功能模块如何自动注册

`fluzer new login` 会在 `injection_base.dart` 的 `registerFeatureModules` 自动加一行：

```dart
@protected
Future<void> registerFeatureModules() async {
  // XxxModule.register(getIt);
  SharesRepositories.register(getIt);
  HomeModule.register(getIt);     // Generated for home
  CounterModule.register(getIt);  // Generated for counter
  SearchModule.register(getIt);   // Generated for search
  LoginModule.register(getIt);    // ← fluzer new login 注入
}
```

每个功能模块的 `<name>_module.dart` 只注册自己的 **Repository**（不注册 BLoC）：

```dart
class LoginModule {
  LoginModule._();
  static void register(GetIt getIt) {
    getIt.registerLazySingleton<LoginRepository>(
      () => LoginRepository(dio: getIt<Dio>()),
    );
  }
}
```

> **重要约定**：`Repository`、`Service` 注册为 `lazySingleton`；`Dio` 由框架基础设施统一注册；**BLoC 不进 DI**，由 `BlocProvider` 在页面创建（避免长期持有导致内存泄漏）。

---

## 3. 跨模块共享仓库

多个 feature 共用一份数据时，把仓库提到 `core/data/repositories/`，在 `core/data/shares_repositories.dart` 登记：

```dart
abstract class SharesRepositories {
  static void register(GetIt getIt) {
    getIt.registerLazySingleton<UserRepository>(
      () => UserRepository(dio: getIt<Dio>()),
    );
  }
}
```

`SharesRepositories.register(getIt)` 已在 `registerFeatureModules` 中被调用，启动时与功能模块一起生效。需用它的 feature 从 `core` 导入并 `getIt<UserRepository>()` 取用，**不要** import 另一个 feature 的目录（见 [架构总览](index.md) 的「跨模块数据共享」）。

---

## 4. 在页面取用依赖

页面只创建 BLoC，BLoC 所需的 Repository 从 DI 取：

```dart
BlocProvider(
  create: (_) => LoginBloc(repository: getIt<LoginRepository>()),
  child: const EffectListener<LoginBloc, LoginState>(
    effectsHandles: [loginEffectHandle],
    child: LoginBody(),
  ),
)
```

Notifiers / 业务 handle 同样用 `getIt` 取服务（如 `getIt<ToastService>()`）。

---

## 5. 替换基础设施实现

依赖倒置：切换底层实现**只改 `injection.dart` 的注册**，调用方 API 不变。例如桌面端改用 `ToastificationToastService`：

```dart
// injection.dart —— registerBaseDependencies / _registerNotifiersLayer
getIt.registerLazySingleton<ToastService>(ToastificationToastService.new);
```

网络层拦截器、存储实现、主题/国际化 Provider 的替换同理，全部集中在 `injection.dart`。这就是「用户手写区」存在的意义——框架升级（`injection_base.dart` 变化）不会冲掉你的依赖配置。

---

## 6. 小贴士

- 测试时直接 `getIt.reset()` 后重新注册 mock，或给 `getIt` 注入假实现。
- 想在启动时预加载？在 `registerUserDependencies` 里 `await` 你的初始化逻辑。
- 新增第三方 SDK：`registerUserDependencies` 是唯一的扩展点，保持 `registerFeatureModules` 归脚本维护。

<!-- source-footer -->

---

*本页原文：[docs/zh/architecture/dependency-injection.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/architecture/dependency-injection.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Farchitecture%2Fdependency-injection.md)*

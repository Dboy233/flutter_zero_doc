# 安装与创建项目

[![fluzer](https://img.shields.io/pub/v/fluzer.svg?label=fluzer)](https://pub.dev/packages/fluzer)
[![template](https://img.shields.io/github/v/release/Dboy233/flutter_zero_template.svg?label=template)](https://github.com/Dboy233/flutter_zero_template/releases)

本页面向 **`fluzer` 使用者**：如何安装、创建项目、生成功能模块，并跑起来。所有命令与骨架均基于真实代码。

---

## 1. 安装 fluzer

```bash
dart pub global activate fluzer
```

> 开发调试也可直接运行：`dart run bin/fluzer.dart <command>`（在 `flutter_zero_cli` 仓库内）。

安装后确认可执行：

```bash
fluzer version
```

> 如需英文界面，可加全局 `--locale en`（如 `fluzer --locale en version`）；`-l` 进入调试模式，排障时先加它重跑。

---

## 2. 创建项目

```bash
fluzer create my_app
```

`create` 的执行步骤（`create_command.dart`）：

1. 校验项目名合法性（小写字母开头，只含小写字母、数字、下划线）
2. 用 Mason 渲染 `project` brick（变量仅 `name`）到当前目录，直接生成 `./<name>` 项目目录
3. 执行 `flutter create . --org <org> --project-name <name>`
4. 清理 `flutter create` 生成的多余测试文件（`widget_test.dart`）
5. 执行 `flutter pub get`
6. 执行 `flutter gen-l10n`

可用选项：

```bash
fluzer create my_app \
  --org com.example
```

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `--org` | `com.example` | 组织标识，影响 bundle ID |

创建完成后进入项目：

```bash
cd my_app
flutter pub get
flutter gen-l10n
flutter run
```

> 新创建的干净模板已包含全部生成产物，通常无需 `build_runner`；只有当你新增了 freezed 模块后才需运行 `dart run build_runner build`。

---

## 3. 新增功能模块

```bash
fluzer new login
```

`new` 会：

- 渲染 `feature` brick 到 `lib/features/login/`
- 在 `core/di/injection_base.dart` 的 `registerFeatureModules` 区域注入 `LoginModule.register(getIt)`
- 默认运行 `build_runner`（`--no-build-runner` 跳过）

生成的骨架（节选自 brick）：

```dart
// lib/features/login/login_module.dart
class LoginModule {
  LoginModule._();
  static void register(GetIt getIt) {
    getIt.registerLazySingleton<LoginRepository>(
      () => LoginRepository(dio: getIt<Dio>()),
    );
  }
}
```

```dart
// lib/features/login/presentation/pages/login_page.dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.bloc});
  final LoginBloc? bloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => bloc ?? LoginBloc(repository: getIt<LoginRepository>()),
      child: const EffectListener<LoginBloc, LoginState>(
        effectsHandles: [loginEffectHandle],
        child: LoginBody(),
      ),
    );
  }
}
```

> `loginEffectHandle` 是 `presentation/effects/login_effect_handle.dart` 中导出的业务处理器函数；`EffectListener` 把它放在责任链**前置**，框架默认 handle 在链尾兜底。

---

## 4. 下一步

骨架生成后，目录里是 freezed 空壳（含注释指引）和已混入四个 Mixin 的 Bloc 占位。下一步就是 **[编写第一个功能模块](your-first-feature.md)** —— 用一个完整示例演示如何把封装好的 Mixin / Effect / 错误体系 / `BaseRepository` 串起来写业务。

!!! tip "关于 `version` 命令"
    运行 `fluzer version` 可查看当前版本，并自动检查 pub.dev 是否有更新（可用结果 24h 缓存、不可用结果 10min 缓存、静默降级）。详见 [CLI 参考](../cli/README.md)。

<!-- source-footer -->

---

*本页原文：[docs/zh/getting-started/index.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/getting-started/index.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Fgetting-started%2Findex.md)*

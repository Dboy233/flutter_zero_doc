# 快速上手

本页面向 **`fluzer` 使用者**：如何安装、创建项目、生成功能模块，并用 MVI 编写一个最小的 `add_counter` 示例。所有命令与骨架均基于真实代码。

---

## 1. 安装 fluzer

```bash
dart pub global activate fluzer
```

> 开发调试也可直接运行：`dart run bin/main.dart <command>`（在 `flutter_zero_cli` 仓库内）。

---

## 2. 创建项目

```bash
fluzer create my_app
```

`create` 的执行步骤（`create_command.dart`）：

1. 校验项目名合法性
2. 用 Mason 渲染 `project` brick（变量仅 `name`）到临时目录
3. 展平 brick 生成的 `{{name}}` 子目录到目标项目目录
4. 执行 `flutter create . --org <org> --project-name <name>`
5. 清理 `flutter create` 生成的多余测试文件
6. 执行 `flutter pub get`
7. 执行 `flutter gen-l10n`
8. 执行 `build_runner`（可选，`--no-build-runner` 跳过）

可用选项：

```bash
fluzer create my_app \
  --org com.example \
  --desc "My Flutter Zero app" \
  --no-build-runner
```

创建完成后进入项目：

```bash
cd my_app
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run
```

---

## 3. 新增功能模块

```bash
fluzer new counter
```

`new` 会：

- 渲染 `feature` brick 到 `lib/features/counter/`
- 在 `core/di/injection_base.dart` 的 `registerFeatureModules` 区域注入 `CounterModule.register(getIt)`
- 默认运行 `build_runner`（`--no-build-runner` 跳过）

生成的骨架（节选自 brick）：

```dart
// lib/features/counter/counter_module.dart
class CounterModule {
  CounterModule._();
  static void register(GetIt getIt) {
    getIt.registerLazySingleton<CounterRepository>(
      () => CounterRepository(client: getIt<DioClient>()),
    );
  }
}
```

```dart
// lib/features/counter/presentation/pages/counter_page.dart
class CounterPage extends StatelessWidget {
  const CounterPage({super.key, this.bloc});
  final CounterBloc? bloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => bloc ?? CounterBloc(repository: getIt<CounterRepository>()),
      child: const EffectListener<CounterBloc, CounterState>(
        effectsHandles: [counterEffectHandle],
        child: CounterBody(),
      ),
    );
  }
}
```

> `counter_effect_handle` 是 `presentation/effects/counter_effect_handle.dart` 中导出的业务处理器函数；`EffectListener` 把它放在责任链**前置**，框架默认 handle 在链尾兜底。

---

## 4. 编写最小 `add_counter` 示例

下面在 `fluzer new counter` 的骨架上补充，完成「点击按钮计数 +1，并弹一个 Toast」的最小 MVI 闭环。括号内为 `{{name}}` 经 Mason 渲染后的实际类名（`counter` → `Counter`）。

### 4.1 定义 Intent（事件）

```dart
// lib/features/counter/presentation/bloc/counter_event.dart
part of 'counter_bloc.dart';

@freezed
abstract class CounterEvent with _$CounterEvent {
  const factory CounterEvent.increment() = CounterIncrement;
}
```

### 4.2 定义 ViewState（状态）

```dart
// lib/features/counter/presentation/bloc/counter_state.dart
part of 'counter_bloc.dart';

@freezed
abstract class CounterState with _$CounterState {
  const factory CounterState({
    @Default(0) int count,
  }) = _CounterState;
}
```

### 4.3 处理事件并（可选）发副作用

```dart
// lib/features/counter/presentation/bloc/counter_bloc.dart
class CounterBloc extends Bloc<CounterEvent, CounterState>
    with BlocAwaitMixin, BlocEffectMixin, BlocCancelTokenMixin {
  CounterBloc({required this.repository}) : super(const CounterState()) {
    on<CounterIncrement>(_onIncrement);
  }

  final CounterRepository repository;

  Future<void> _onIncrement(CounterIncrement event, Emitter<CounterState> emit) async {
    // 改状态：单向、不可变 copyWith
    emit(state.copyWith(count: state.count + 1));
    // 一次性副作用：通知用户（不污染 State）
    emitEffect(const ToastEffect(messageCode: 'counterIncremented'));
  }
}
```

### 4.4 业务副作用处理器（messageCode → 文本）

```dart
// lib/features/counter/presentation/effects/counter_effect_handle.dart
import 'package:flutter/material.dart';
import 'package:flutter_zero_app/core/di/get_it_instance.dart';
import 'package:flutter_zero_app/core/effect/ui_effect.dart';
import 'package:flutter_zero_app/core/notifiers/toast_service.dart';
import 'package:flutter_zero_app/l10n/gen/app_localizations.dart';

bool counterEffectHandle(BuildContext context, UIEffect effect) {
  if (effect is ToastEffect && effect.messageCode != null) {
    getIt<ToastService>().showInfo(_map(effect.messageCode!, context.l));
    return true; // 认领，责任链命中即止
  }
  return false; // 其余交给框架默认 handle
}

String _map(String code, AppLocalizations l) =>
    switch (code) {
      'counterIncremented' => l.counterIncremented,
      _ => l.homeGenericError,
    };
```

并在 `app_zh.arb` / `app_en.arb` 增加对应 key（如 `"counterIncremented": "计数已 +1"`）。

### 4.5 渲染 View

```dart
// lib/features/counter/presentation/pages/counter_body.dart
class CounterBody extends StatelessWidget {
  const CounterBody({super.key});

  @override
  Widget build(BuildContext context) {
    // View 是 State 的纯函数：只读取、只发射 Intent
    final count = context.watch<CounterBloc>().state.count;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.read<CounterBloc>().add(const CounterIncrement()),
              child: const Text('+1'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4.6 运行

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run
```

完成后的数据流：`点击 +1` → `add(CounterIncrement)` → `_onIncrement` → `emit(count+1)` + `emitEffect(ToastEffect)` → View 重建显示新计数、NotifiersHost 弹 Toast。

---

## 5. 约定速记

- 事件/状态用 freezed；状态不可变，永远 `copyWith`。
- Bloc 不进 DI，由 `BlocProvider` 创建；Repository / Service 进 DI。
- 一次性 UI（Toast / Loading / Dialog）走 Effect 通道，不写进 State。
- 业务 `EffectHandle` 用 `is` 认领自己关心的类型，返回 `true` 即拦截；不认领的交给框架默认 handle。

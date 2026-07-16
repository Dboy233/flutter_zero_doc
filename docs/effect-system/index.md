# Effect 系统与 Notifiers 系统

本文档描述两件事：**Effect 系统**（一次性 UI 副作用的通道）与 **Notifiers 系统**（Toast / Loading 等通知服务的封装）。两者通过「Effect 处理器调用 Notifier 服务」衔接。所有描述基于当前代码。

---

## 1. 为什么需要 Effect 系统

MVI 要求 **State 只描述「渲染所需的数据」**。但应用有许多「一次性、无状态、不值得进 State」的 UI 行为：Toast 提示、Loading 遮罩、确认弹窗、导航跳转等。若把它们塞进 `State`，会造成单槽覆盖、重复投递、状态被副作用污染。

Effect 系统用一条**独立的 broadcast Stream** 承载这些一次性副作用，与状态流彻底分离。

---

## 2. `UIEffect`：开放基类

`core/effect/ui_effect.dart` 定义了开放基类 `UIEffect`（`abstract` 而非 `sealed`）：

```dart
abstract class UIEffect {
  const UIEffect();
}

final class ToastEffect extends UIEffect {
  const ToastEffect({this.message, this.l10nCode, this.code, this.extra});
  final String? message;   // 固定/服务端文本，优先显示
  final String? l10nCode;  // 开发者自定义本地化键，由业务 handle 翻译
  final int? code;         // 内部错误码（HTTP 状态码或 AppErrorCodes 哨兵码）
  final Object? extra;
}

final class DialogEffect extends UIEffect {
  const DialogEffect({required this.type, this.extra});
  final String type;       // 业务类型标识，如 'retry' / 'refresh_success'
  final Object? extra;
}

final class LoadingEffect extends UIEffect {
  const LoadingEffect({required this.show, this.extra});
  final bool show;         // true 显示 / false 隐藏
  final Object? extra;     // 可选状态文案（String），框架默认 handle 透传
}
```

**开放基类的意义**：任何库都能直接 `extends UIEffect` 新增类型，无需修改 `ui_effect.dart`、也无需同库声明。责任链中的处理器用 `is` 检查认领自己关心的类型，互不干扰——业务可自由加类型而框架代码零改动。

---

## 3. `BlocEffectMixin`：副作用流

`core/bloc/bloc_effect_mixin.dart` 为 BLoC 添加 `effectStream` 与 `emitEffect`：

```dart
mixin BlocEffectMixin<S> on BlocBase<S> {
  Stream<UIEffect> get effectStream => _effectController.stream;
  void emitEffect(UIEffect effect) => _effectController.add(effect);
}
```

BLoC 用法：

```dart
class HomeBloc extends Bloc<HomeEvent, HomeState>
    with BlocAwaitMixin, BlocEffectMixin, BlocCancelTokenMixin, BlocErrorHandlerMixin {
  // ...
  emitEffect(const ToastEffect(l10nCode: 'homeLoadFailed'));
  // 或：emitEffect(const ToastEffect(message: '加载失败'));
}
```

关闭 BLoC 时 Mixin 自动 `close()` 控制器，无泄漏。

---

## 4. `EffectListener` + 责任链 `EffectHandle`

`core/effect/effect_listener.dart`：

```dart
typedef EffectHandle = bool Function(BuildContext context, UIEffect effect);

class EffectListener<B extends BlocBase<S>, S> extends StatelessWidget {
  const EffectListener({required this.child, this.effectsHandles = const []});
  // build 内把业务 handles 放在链首，框架默认 handle 追加在链尾：
  //   [...effectsHandles, defaultToastHandle, defaultDialogHandle, defaultLoadingHandle]
}
```

**责任链规则**：

1. 业务 `effectsHandles` 排在链首，框架级通用 handle（`defaultToastHandle` / `defaultDialogHandle` / `defaultLoadingHandle`）自动追加在链尾兜底。
2. 对每条到达的 effect，**按序**调用 handle；**第一个返回 `true` 的胜出**，后续不再执行。
3. 任何库都能加自己的 handle，无需改 `EffectListener` 或 `BlocEffectMixin`。

> 注意：`build` 内构造的是**新的可变列表**再下传，绝不修改入参 `effectsHandles`（调用方可能传入 `const` 列表）。

---

## 5. 框架默认 handle（兜底）

| Handle | 认领类型 | 行为 |
|--------|----------|------|
| `defaultToastHandle` | `ToastEffect` | 优先级：**`message` → `code` → `l10nCode`**。`message` 直接显示；`code` 按 `AppErrorCodes` 映射兜底文案；`l10nCode` **不被默认 handle 处理**，必须由业务 handle 翻译（未处理则 debug 告警、release 静默） |
| `defaultDialogHandle` | `DialogEffect` | 为未被业务认领的弹窗渲染最小通用对话框，避免副作用被静默丢弃 |
| `defaultLoadingHandle` | `LoadingEffect` | 委托注入的 `LoadingService`；`show=true` 调 `svc.show(status:)`，否则 `svc.dismiss()` |

业务层只需 `emitEffect(const LoadingEffect(show: true))` 即可控制全局 loading，无需关心底层是 EasyLoading 还是其它实现。

### `defaultToastHandle` 的 code 映射

`code` 按 `AppErrorCodes`（负数内部码 + 常见 HTTP 4xx/5xx）映射为本地化文案，未列出的码走 `unknownErrorCode` 兜底。详见 [错误处理与 Result](error-handling.md)。

---

## 6. 业务自定义 handle（示例）

`lib/features/home/presentation/effects/home_effect_handle.dart`：

```dart
bool homeEffectHandle(BuildContext context, UIEffect effect) {
  if (effect is ToastEffect && effect.l10nCode != null) {
    final text = _mapToastMessageCode(effect.l10nCode!, context.l);
    if (text != null) {
      getIt<ToastService>().showError(text);
      return true; // 认领
    }
  }
  if (effect is DialogEffect) {
    return _handleDialog(context, effect.type, effect.extra);
  }
  return false; // 其余交给框架默认 handle
}

String? _mapToastMessageCode(String code, AppLocalizations l) => switch (code) {
  'homeLoadFailed' => l.homeLoadFailed,
  _ => null,
};
```

要点：

- 用 `is` 认领自己关心的类型；**不穷尽 `switch`**——新增 `UIEffect` 子类无需回来补 case。
- `l10nCode → 本地化文本` 的映射是业务职责（i18n 方案自选），框架默认 handle 不替你做这件事。
- 业务 handle 在 `EffectListener.effectsHandles` 传入（见 `home_page.dart` / 生成的 `<name>_page.dart`），排在链首优先胜出。
- 若直接用 `ToastEffect(message: '...')` 或 `ex.toToastEffect()`（带 `code`），**无需**任何业务 handle，默认 handle 即可显示。

---

## 7. 如何扩展一个新的 Effect 类型

1. 任意库中：`class XxxEffect extends UIEffect { ... }`
2. 若是通用意图（如 loading），框架默认 handle 统一处理；要换底层实现，只需在 DI 替换对应 `Service`。
3. 若是业务类型（如弹窗），在你的 handle 函数里用 `is XxxEffect` 认领，并把该函数传入 `EffectListener.effectsHandles`，返回 `true` 表示已处理。
4. 在 BLoC 中 `emitEffect(XxxEffect(...))`。
5. **不需要修改 `BlocEffectMixin` 或 `EffectListener`。**

---

## 8. Notifiers 系统

Notifiers 解决的是「**无 `BuildContext` 的环境（BLoC）如何驱动需要 `BuildContext` 的 UI 覆盖层（Toast / Loading）**」。

### 8.1 抽象服务 + 内部事件管道

`core/notifiers/toast_service.dart`：

```dart
abstract class ToastService {
  final StreamController<ToastEvent> _effects =
      StreamController<ToastEvent>.broadcast();
  Stream<ToastEvent> get effects => _effects.stream;

  void showError(String message) => _effects.add(ToastEvent.error(message));
  void showSuccess(String message) => _effects.add(ToastEvent.success(message));
  void showInfo(String message) => _effects.add(ToastEvent.info(message));
  void showWarning(String message) => _effects.add(ToastEvent.warning(message));
  void dismissAll() => _effects.add(const ToastEvent.dismiss());

  Widget build(BuildContext context, Widget child);   // 用 wrapper 包裹 child
  void onEvent(BuildContext context, ToastEvent event); // 事件到达时渲染
}
```

设计要点：

- **每个 service 就是调用入口**：`getIt<ToastService>().showError('...')` 直接在实例上调用，不经过单独 controller。
- 内部 `Stream` 把「无 context 调用」桥接到「有 context 渲染」：`NotifiersHost` 监听此流，并在 `onEvent` 中拿到 `BuildContext` 执行实际渲染。
- `LoadingService`（`core/notifiers/loading_service.dart`）是同一模式：`show({status})` / `dismiss()` 经内部 `Stream` 桥接。

### 8.2 `NotifiersHost`：桥接 Context

`core/notifiers/notifiers_host.dart` 放在 `MaterialApp.builder` 中（位于 MaterialApp 内部、Navigator 上层，使覆盖层覆盖所有页面）：

```dart
MaterialApp.router(
  builder: (context, child) => NotifiersHost(
    toasts: [getIt<ToastService>(), getIt<DeskTopToastService>()],
    loadings: [getIt<LoadingService>()],
    child: child!,
  ),
)
```

它订阅所有 service 的 `effects` 流，事件到达时调用 `onEvent(context, event)` 渲染。Wrapper 嵌套顺序：Loading 在内层（更靠近内容），Toast 在外层。

### 8.3 实现者可替换（依赖倒置）

具体实现与抽象解耦，切换只需改 DI 注册：

| 抽象 | 默认实现者 | 说明 |
|------|-----------|------|
| `ToastService` | `ToastificationToastService`（桌面）/ `EasyLoadingToastService` | 继承 `DeskTopToastService` 类型标记，桌面与移动端可共存于 DI |
| `LoadingService` | `EasyLoadingLoadingService` | 用 `FlutterEasyLoading` 包裹 child |

新增实现只需 `extends ToastService/LoadingService` 并实现 `build` + `onEvent`，再在 DI 注册即可，调用方 API 不变。

### 8.4 Effect 与 Notifiers 的衔接

Effect 是「意图」，Notifiers 是「执行者」：

```
BLoC: emitEffect(ToastEffect(l10nCode:'homeLoadFailed'))
        │
EffectListener 责任链
        │  homeEffectHandle 认领 → getIt<ToastService>().showError(本地化文本)
        │  或 defaultToastHandle 兜底 → getIt<ToastService>().showError/showInfo
        ▼
ToastService.effects 流
        │
NotifiersHost.onEvent(context, event)
        ▼
Toastification / EasyLoading 实际渲染
```

---

## 9. 小结

- **Effect 系统** = `UIEffect`（开放基类）+ `BlocEffectMixin`（流）+ `EffectListener`（责任链）+ 三默认 handle；业务用 `is` 认领、返回 `true` 拦截。
- **Notifiers 系统** = `ToastService` / `LoadingService`（抽象 + 内部 Stream）+ `NotifiersHost`（桥接 Context）+ 可替换实现者。
- 两者的边界清晰：**BLoC 只发意图（emitEffect），不知道 Toast 长什么样；Notifiers 只渲染，不知道业务为何触发**。这满足了「一次性副作用与状态分离」的 MVI 要求。

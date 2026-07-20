# Effect System & Notifiers System

This document describes two things: the **Effect system** (the channel for one-shot UI side-effects) and the **Notifiers system** (the wrapper for Toast / Loading and other notification services). The two connect through "an Effect handler calls a Notifier service". Everything described is based on the current code.

---

## 1. Why an Effect System

MVI requires **State to only describe "data needed for rendering"**. But there are many "one-shot, stateless, not worth putting into State" UI behaviors: Toast prompts, Loading overlays, confirmation dialogs, navigation jumps, etc. If you stuff them into `State`, you get single-slot overwrites, duplicate deliveries, and state polluted by side-effects.

The Effect system carries these one-shot side-effects through an **independent broadcast Stream**, completely separated from the state stream.

---

## 2. `UIEffect`: Open Base Class

`core/effect/ui_effect.dart` defines the open base class `UIEffect` (`abstract`, not `sealed`):

```dart
abstract class UIEffect {
  const UIEffect();
}

final class ToastEffect extends UIEffect {
  const ToastEffect({this.message, this.l10nCode, this.code, this.extra});
  final String? message;   // fixed/server text, displayed with priority
  final String? l10nCode;  // developer-defined localization key, translated by the business handle
  final int? code;         // internal error code (HTTP status code or AppErrorCodes sentinel)
  final Object? extra;
}

final class DialogEffect extends UIEffect {
  const DialogEffect({required this.type, this.extra});
  final String type;       // business type identifier, e.g. 'retry' / 'refresh_success'
  final Object? extra;
}

final class LoadingEffect extends UIEffect {
  const LoadingEffect({required this.show, this.extra});
  final bool show;         // true = show / false = hide
  final Object? extra;     // optional status text (String), passed through by the framework default handle
}
```

**Meaning of the open base class**: any library can directly `extends UIEffect` to add a new type, without modifying `ui_effect.dart` or declaring it in the same library. Handlers in the responsibility chain use `is` to claim the types they care about, independently — the business can freely add types while the framework code stays untouched.

---

## 3. `BlocEffectMixin`: Side-effect Stream

`core/bloc/bloc_effect_mixin.dart` adds `effectStream` and `emitEffect` to the BLoC:

```dart
mixin BlocEffectMixin<S> on BlocBase<S> {
  Stream<UIEffect> get effectStream => _effectController.stream;
  void emitEffect(UIEffect effect) => _effectController.add(effect);
}
```

BLoC usage:

```dart
class HomeBloc extends Bloc<HomeEvent, HomeState>
    with BlocAwaitMixin, BlocEffectMixin, BlocCancelTokenMixin, BlocErrorHandlerMixin {
  // ...
  emitEffect(const ToastEffect(l10nCode: 'homeLoadFailed'));
  // or: emitEffect(const ToastEffect(message: 'Load failed'));
}
```

When the BLoC is closed, the Mixin automatically `close()`s the controller — no leak.

---

## 4. `EffectListener` + Responsibility Chain `EffectHandle`

`core/effect/effect_listener.dart`:

```dart
typedef EffectHandle = bool Function(BuildContext context, UIEffect effect);

class EffectListener<B extends BlocBase<S>, S> extends StatelessWidget {
  const EffectListener({required this.child, this.effectsHandles = const []});
  // inside build, business handles are placed at the front of the chain,
  // framework default handles are appended at the end:
  //   [...effectsHandles, defaultToastHandle, defaultDialogHandle, defaultLoadingHandle]
}
```

**Responsibility chain rules**:

1. The business `effectsHandles` are at the front of the chain; the framework-level generic handles (`defaultToastHandle` / `defaultDialogHandle` / `defaultLoadingHandle`) are automatically appended at the end as fallback.
2. For each arriving effect, handles are called **in order**; the **first one that returns `true` wins**, and the rest are not executed.
3. Any library can add its own handle, without modifying `EffectListener` or `BlocEffectMixin`.

> Note: inside `build` a **new mutable list** is constructed and passed down; the input `effectsHandles` is never mutated (the caller may pass a `const` list).

---

## 5. Framework Default Handles (fallback)

| Handle | Claims type | Behavior |
|--------|-------------|----------|
| `defaultToastHandle` | `ToastEffect` | Priority: **`message` → `code` → `l10nCode`**. `message` displayed directly; `code` mapped to fallback text via `AppErrorCodes`; `l10nCode` **is not handled by the default handle** and must be translated by the business handle (unhandled → debug warning, silent in release) |
| `defaultDialogHandle` | `DialogEffect` | Renders a minimal generic dialog for unclaimed dialogs, avoiding side-effects being silently dropped |
| `defaultLoadingHandle` | `LoadingEffect` | Delegates to the injected `LoadingService`; `show=true` calls `svc.show(status:)`, otherwise `svc.dismiss()` |

The business layer only needs `emitEffect(const LoadingEffect(show: true))` to control global loading, without caring whether the underlying implementation is EasyLoading or something else.

### `defaultToastHandle`'s code mapping

`code` is mapped to localized text via `AppErrorCodes` (negative internal codes + common HTTP 4xx/5xx); unlisted codes fall back to `unknownErrorCode`. See [Error Handling & Result](../architecture/error-handling.md).

---

## 6. Business Custom Handle (example)

`lib/features/home/presentation/effects/home_effect_handle.dart`:

```dart
bool homeEffectHandle(BuildContext context, UIEffect effect) {
  if (effect is ToastEffect && effect.l10nCode != null) {
    final text = _mapToastMessageCode(effect.l10nCode!, context.l);
    if (text != null) {
      getIt<ToastService>().showError(text);
      return true; // claim
    }
  }
  if (effect is DialogEffect) {
    return _handleDialog(context, effect.type, effect.extra);
  }
  return false; // everything else falls through to the framework default handle
}

String? _mapToastMessageCode(String code, AppLocalizations l) => switch (code) {
  'homeLoadFailed' => l.homeLoadFailed,
  _ => null,
};
```

Key points:

- Use `is` to claim the types you care about; **don't exhaustively `switch`** — adding a `UIEffect` subclass needs no back-patching of cases.
- The `l10nCode → localized text` mapping is the business's responsibility (choose your own i18n approach); the framework default handle does not do this for you.
- The business handle is passed in via `EffectListener.effectsHandles` (see `home_page.dart` / the generated `<name>_page.dart`), placed at the front of the chain to win first.
- If you use `ToastEffect(message: '...')` or `ex.toToastEffect()` (with `code`) directly, **no** business handle is needed — the default handle can display it.

---

## 7. How to Extend a New Effect Type

1. In any library: `class XxxEffect extends UIEffect { ... }`
2. If it is a generic intent (e.g. loading), the framework default handle handles it uniformly; to swap the underlying implementation, just replace the corresponding `Service` in DI.
3. If it is a business type (e.g. a dialog), claim it in your handle function with `is XxxEffect`, and pass that function into `EffectListener.effectsHandles`, returning `true` to indicate it was handled.
4. `emitEffect(XxxEffect(...))` in the BLoC.
5. **No need to modify `BlocEffectMixin` or `EffectListener`.**

---

## 8. Notifiers System

Notifiers solve "**how a `BuildContext`-less environment (BLoC) drives a UI overlay (Toast / Loading) that needs `BuildContext`**".

### 8.1 Abstract Service + Internal Event Pipeline

`core/notifiers/toast_service.dart`:

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

  Widget build(BuildContext context, Widget child);   // wrap child with this
  void onEvent(BuildContext context, ToastEvent event); // render when event arrives
}
```

Design points:

- **Each service is the call entry**: `getIt<ToastService>().showError('...')` is called directly on the instance, not through a separate controller.
- The internal `Stream` bridges "context-less call" to "contextful render": `NotifiersHost` listens to this stream and gets `BuildContext` in `onEvent` to perform the actual rendering.
- `LoadingService` (`core/notifiers/loading_service.dart`) is the same pattern: `show({status})` / `dismiss()` bridged via the internal `Stream`.

### 8.2 `NotifiersHost`: Bridge to Context

`core/notifiers/notifiers_host.dart` is placed in `MaterialApp.builder` (inside MaterialApp, above the Navigator, so overlays cover all pages):

```dart
MaterialApp.router(
  builder: (context, child) => NotifiersHost(
    toasts: [getIt<ToastService>(), getIt<DeskTopToastService>()],
    loadings: [getIt<LoadingService>()],
    child: child!,
  ),
)
```

It subscribes to all services' `effects` stream, and calls `onEvent(context, event)` to render when an event arrives. Wrapper nesting order: Loading is inner (closer to content), Toast is outer.

### 8.3 Implementations Are Swappable (dependency inversion)

The concrete implementation is decoupled from the abstraction; switching only changes the DI registration:

| Abstraction | Default implementer | Description |
|-------------|---------------------|-------------|
| `ToastService` | `ToastificationToastService` (desktop) / `EasyLoadingToastService` | Extends the `DeskTopToastService` type marker, so desktop and mobile can coexist in DI |
| `LoadingService` | `EasyLoadingLoadingService` | Wraps child with `FlutterEasyLoading` |

Adding an implementation only requires `extends ToastService/LoadingService` and implementing `build` + `onEvent`, then registering it in DI; the caller's API is unchanged.

### 8.4 How Effect and Notifiers Connect

Effect is the "intent", Notifiers is the "executor":

```
BLoC: emitEffect(ToastEffect(l10nCode:'homeLoadFailed'))
        │
EffectListener responsibility chain
        │  homeEffectHandle claims → getIt<ToastService>().showError(localized text)
        │  or defaultToastHandle fallback → getIt<ToastService>().showError/showInfo
        ▼
ToastService.effects stream
        │
NotifiersHost.onEvent(context, event)
        ▼
Toastification / EasyLoading actual render
```

---

## 9. Summary

- **Effect system** = `UIEffect` (open base class) + `BlocEffectMixin` (stream) + `EffectListener` (responsibility chain) + three default handles; the business uses `is` to claim and returns `true` to intercept.
- **Notifiers system** = `ToastService` / `LoadingService` (abstraction + internal Stream) + `NotifiersHost` (bridge to Context) + swappable implementers.
- The boundary between the two is clear: **the BLoC only emits intent (emitEffect) and doesn't know what the Toast looks like; Notifiers only renders and doesn't know why the business triggered it**. This satisfies the MVI requirement of "one-shot side-effects separated from state".

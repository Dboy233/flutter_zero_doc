# BLoC 四个 Mixin

`core/bloc/` 提供四个可组合的 Mixin，解决 MVI 在 Flutter 下的四个常见痛点。**它们彼此正交，可任意组合**：

| Mixin | 解决的问题 |
|-------|-----------|
| `BlocAwaitMixin` | `add(Event)` 是 fire-and-forget，UI 无法 `await` |
| `BlocCancelTokenMixin` | 网络请求取消 / 去重，绑定 BLoC 生命周期 |
| `BlocEffectMixin` | 一次性副作用通道（Toast / Loading / Dialog） |
| `BlocErrorHandlerMixin` | 把异常包装为 `Result<T>`（成功 / 失败 / 取消），`Failure` 携带原始 `Exception` |

统一导出：`import 'package:flutter_zero_app/core/bloc/bloc.dart';`

---

## 1. BlocAwaitMixin —— 让事件可等待

`add` 返回 `void`，UI 没法 `await`。`runAwait` 返回一个 `Future`，事件处理结束时自动完成。

### 手动收尾

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState>
    with BlocAwaitMixin<ItemEvent, ItemState> {
  Future<void> refresh() =>
      runAwait(event: const ItemEvent.refresh(), key: 'refresh');

  Future<void> _onRefresh(ItemRefresh event, Emitter<ItemState> emit) async {
    try {
      emit(state.copyWith(isRefreshing: true));
      await _repository.fetch();
    } finally {
      emit(state.copyWith(isRefreshing: false));
      completeAwait('refresh'); // 必须手动收尾，否则 RefreshIndicator 挂起
    }
  }
}
```

```dart
RefreshIndicator(
  onRefresh: () => context.read<ItemBloc>().refresh(),
  child: ListView.builder(...),
)
```

### 自动收尾（推荐）

`onAwait` 用 `try/finally` 自动调用 `completeAwait`，避免漏写导致挂起：

```dart
ItemBloc(super.initialState) : super() {
  onAwait<ItemRefresh>('refresh', _onRefresh); // key + handler
}

Future<void> _onRefresh(ItemRefresh event, Emitter<ItemState> emit) async {
  emit(state.copyWith(isRefreshing: true));
  await _repository.fetch();
  emit(state.copyWith(isRefreshing: false));
} // finally 由 onAwait 自动补齐
```

- `runAwait` 默认 30s 超时，防止 handler 抛异常或 BLoC 关闭时永久挂起。
- 页面销毁时 `close()` 会清理所有未完成的 Completer（报错而非永久挂起）。

---

## 2. BlocCancelTokenMixin —— 自动取消网络

按操作 key 管理 Dio `CancelToken`，页面销毁自动取消、连续调用自动去重。

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState>
    with BlocCancelTokenMixin<ItemState> {

  Future<void> _onFetch(ItemFetch event, Emitter<ItemState> emit) async {
    try {
      final items = await _repository.fetchItems(
        cancelToken: token('items'), // 一行，全自动管理
      );
      emit(state.copyWith(items: items));
    } catch (e) {
      if (isCancelled(e)) return; // 主动取消 → 静默，无需 import Dio
      final ex = e is Exception ? e : Exception(e.toString());
      emitEffect(ex.toToastEffect());
    }
  }

  void onCancelTapped() => cancelAll(); // 取消按钮中断所有进行中请求
}
```

要点：

- **去重**：`token('items')` 每次调用都会先取消上一个同 key 请求再创建新 token。
- **生命周期绑定**：`close()` 自动 `cancelAll()`，页面 pop 后不会收到陈旧响应。
- **key 隔离**：不同 key（`'items'` / `'upload'`）互不影响；并发同类请求用不同 key。
- 默认 key 为 `'default'`，适合单一操作类型的简单 BLoC。

---

## 3. BlocEffectMixin —— 一次性副作用

提供 `effectStream` 与 `emitEffect`，副作用走独立 Stream，不污染 `State`。

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState>
    with BlocEffectMixin<ItemState> {

  Future<void> _onSubmit(ItemSubmit event, Emitter<ItemState> emit) async {
    emitEffect(const LoadingEffect(show: true));   // 显示 Loading
    // ... 业务逻辑 ...
    emitEffect(const LoadingEffect(show: false));  // 隐藏 Loading
    emitEffect(const ToastEffect(l10nCode: 'saved'));
  }
}
```

关闭 BLoC 时 Mixin 自动 `close()` 控制器，无泄漏。`UIEffect` 是**开放基类**，自定义类型只需 `extends UIEffect`（详见 [Effect 与 Notifiers](../effect-system/index.md)）。

---

## 4. BlocErrorHandlerMixin —— 统一错误处理

把底层异步操作（Dio 等）的异常包装成 `Result<T>`（成功 / 失败 / 取消）。`Failure` **直接携带原始 `Exception`**——框架不做任何业务或文案假设，提示文案由 BLoC 自行决定（见 [错误处理与 Result](../architecture/error-handling.md)）。

### 首选：`runCatching`

取代手写 `try/catch`，三态显式：

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState>
    with BlocEffectMixin<ItemState>, BlocErrorHandlerMixin<ItemState> {

  Future<void> _onFetch(ItemFetch event, Emitter<ItemState> emit) async {
    final result = await runCatching(() => _repository.fetchItems());
    result.when(
      success: (items) => emit(state.copyWith(items: items)),
      failure: (ex) => emitEffect(ex.toToastEffect()),
      cancel: () {/* 主动取消，通常什么都不做 */},
    );
  }
}
```

`runCatching` 的映射规则：成功 → `Success`；`Exception` → `Failure(e)`（原样保留）；主动取消 → `Cancel`；其余异常 → `Failure(Exception('unknown exception'))`。

### 能力清单

| 方法 | 作用 |
|------|------|
| `runCatching<T>(action)` | 包裹异步操作，返回 `Result<T>`；取消 → `Cancel`，`Exception` → `Failure(e)`，其余 → `Failure(Exception('unknown exception'))` |
| `isCancelled(error)` | 判断是否为主动取消（Dio 取消异常），用于避免弹 Toast |

> 取消判断默认按 Dio 的 `DioExceptionType.cancel`。使用其它 HTTP 客户端时，覆盖 `isCancelled` 即可。

---

## 组合示例（登录）

四个 Mixin 在 `login` 模块协同（完整代码见 [编写第一个功能模块](../getting-started/your-first-feature.md)）：

```dart
class LoginBloc extends Bloc<LoginEvent, LoginState>
    with
        BlocAwaitMixin<LoginEvent, LoginState>,
        BlocEffectMixin<LoginState>,
        BlocErrorHandlerMixin<LoginState> {
  Future<void> submit() =>
      runAwait(event: const LoginEvent.submit(), key: 'login_submit');

  Future<void> _onSubmit(LoginSubmit event, Emitter<LoginState> emit) async {
    emit(state.copyWith(isSubmitting: true));
    emitEffect(const LoadingEffect(show: true));
    final result = await runCatching(
      () => repository.login(username: state.username, password: state.password),
    );
    emitEffect(const LoadingEffect(show: false));
    result.when(
      success: (_) => emitEffect(const ToastEffect(l10nCode: 'loginSuccess')),
      failure: (_) => emitEffect(const ToastEffect(l10nCode: 'loginFailed')),
      cancel: () {},
    );
  }
}
```

- `BlocAwaitMixin` 让页面 `await submit()` 后能跳转。
- `BlocEffectMixin` 发 Loading / Toast。
- `BlocErrorHandlerMixin` 用 `runCatching` 消除 `try/catch`。
- （取消场景）若需要，`BlocCancelTokenMixin` 的 `token('login')` 可中断登录请求。

<!-- source-footer -->

---

*本页原文：[docs/zh/architecture/bloc-mixins.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/architecture/bloc-mixins.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Farchitecture%2Fbloc-mixins.md)*

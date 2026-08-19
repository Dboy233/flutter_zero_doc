# The Four BLoC Mixins

`core/bloc/` provides four composable Mixins that solve four common MVI pain points under Flutter. **They are orthogonal and can be combined arbitrarily**:

| Mixin | Problem solved |
|-------|----------------|
| `BlocAwaitMixin` | `add(Event)` is fire-and-forget; the UI cannot `await` |
| `BlocCancelTokenMixin` | Network request cancellation / deduplication, bound to the BLoC lifecycle |
| `BlocEffectMixin` | One-shot side-effect channel (Toast / Loading / Dialog) |
| `BlocErrorHandlerMixin` | Wraps exceptions into `Result<T>` (success / failure / cancel); `Failure` carries the raw `Exception` |

Unified export: `import 'package:flutter_zero_app/core/bloc/bloc.dart';`

---

## 1. BlocAwaitMixin — Make Events Awaitable

`add` returns `void`, so the UI cannot `await`. `runAwait` returns a `Future` that completes when the event handler finishes.

### Manual finalization

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
      completeAwait('refresh'); // must finalize manually, or RefreshIndicator hangs
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

### Auto-finalization (recommended)

`onAwait` uses `try/finally` to call `completeAwait` automatically, avoiding hangs from a forgotten call:

```dart
ItemBloc(super.initialState) : super() {
  onAwait<ItemRefresh>('refresh', _onRefresh); // key + handler
}

Future<void> _onRefresh(ItemRefresh event, Emitter<ItemState> emit) async {
  emit(state.copyWith(isRefreshing: true));
  await _repository.fetch();
  emit(state.copyWith(isRefreshing: false));
} // finally is auto-filled by onAwait
```

- `runAwait` has a default 30s timeout, preventing permanent hangs if the handler throws or the BLoC is closed.
- When the page is disposed, `close()` cleans up all unfinished Completers (errors rather than hanging forever).

---

## 2. BlocCancelTokenMixin — Automatic Network Cancellation

Manages Dio `CancelToken` by operation key; auto-cancels on page dispose and auto-dedupes on consecutive calls.

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState>
    with BlocCancelTokenMixin<ItemState> {

  Future<void> _onFetch(ItemFetch event, Emitter<ItemState> emit) async {
    try {
      final items = await _repository.fetchItems(
        cancelToken: token('items'), // one line, fully automatic
      );
      emit(state.copyWith(items: items));
    } catch (e) {
      if (isCancelled(e)) return; // active cancel → silent, no need to import Dio
      final ex = e is Exception ? e : Exception(e.toString());
      emitEffect(ex.toToastEffect());
    }
  }

  void onCancelTapped() => cancelAll(); // cancel button interrupts all in-flight requests
}
```

Key points:

- **Dedupe**: each call to `token('items')` cancels the previous same-key request before creating a new token.
- **Lifecycle binding**: `close()` auto-calls `cancelAll()`, so no stale response arrives after the page pops.
- **Key isolation**: different keys (`'items'` / `'upload'`) don't interfere; use different keys for concurrent same-kind requests.
- The default key is `'default'`, suitable for simple BLoCs with a single operation type.

---

## 3. BlocEffectMixin — One-shot Side-effects

Provides `effectStream` and `emitEffect`; side-effects travel through an independent Stream and do not pollute `State`.

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState>
    with BlocEffectMixin<ItemState> {

  Future<void> _onSubmit(ItemSubmit event, Emitter<ItemState> emit) async {
    emitEffect(const LoadingEffect(show: true));   // show Loading
    // ... business logic ...
    emitEffect(const LoadingEffect(show: false));  // hide Loading
    emitEffect(const ToastEffect(l10nCode: 'saved'));
  }
}
```

When the BLoC is closed, the Mixin automatically `close()`s the controller — no leak. `UIEffect` is an **open base class**; a custom type only needs to `extends UIEffect` (see [Effect & Notifiers](../effect-system/index.md)).

---

## 4. BlocErrorHandlerMixin — Unified Error Handling

Wraps exceptions from low-level async operations (Dio, etc.) into `Result<T>` (success / failure / cancel). `Failure` **carries the raw `Exception`** — the framework makes no business or message assumption; the BLoC decides the toast text (see [Error Handling & Result](../architecture/error-handling.md)).

### Preferred: `runCatching`

Replaces hand-written `try/catch`, with three explicit states:

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState>
    with BlocEffectMixin<ItemState>, BlocErrorHandlerMixin<ItemState> {

  Future<void> _onFetch(ItemFetch event, Emitter<ItemState> emit) async {
    final result = await runCatching(() => _repository.fetchItems());
    result.when(
      success: (items) => emit(state.copyWith(items: items)),
      failure: (ex) => emitEffect(ex.toToastEffect()),
      cancel: () {/* active cancel, usually do nothing */},
    );
  }
}
```

`runCatching` mapping: success → `Success`; `Exception` → `Failure(e)` (kept as-is); active cancel → `Cancel`; other errors → `Failure(Exception('unknown exception'))`.

### Capability list

| Method | Purpose |
|--------|---------|
| `runCatching<T>(action)` | Wrap an async action, return `Result<T>`; cancel → `Cancel`, `Exception` → `Failure(e)`, other → `Failure(Exception('unknown exception'))` |
| `isCancelled(error)` | Check whether it is an active cancel (Dio cancel exception), to avoid showing a Toast |

> Cancel detection defaults to Dio's `DioExceptionType.cancel`. Override `isCancelled` when using another HTTP client.

---

## Combination Example (Login)

The four Mixins work together in the `login` module (full code in [Write Your First Feature](../getting-started/your-first-feature.md)):

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

- `BlocAwaitMixin` lets the page `await submit()` then navigate.
- `BlocEffectMixin` emits Loading / Toast.
- `BlocErrorHandlerMixin` uses `runCatching` to eliminate `try/catch`.
- (Cancel scenario) if needed, `BlocCancelTokenMixin`'s `token('login')` can interrupt the login request.

<!-- source-footer -->

---

*Source of this page: [docs/en/architecture/bloc-mixins.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/architecture/bloc-mixins.md)*

*[Report an error on this page](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_en.md&title=%5BDocs%20error%5D%20docs%2Fen%2Farchitecture%2Fbloc-mixins.md)*

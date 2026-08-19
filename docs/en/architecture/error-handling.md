# Error Handling & Result

The template follows a **"zero wrapping, zero business assumptions"** principle for error handling: the framework does **not** catch, convert, or normalize any exception for you, nor does it parse responses for you. Everything — how to send the request, how to parse, how to throw — is decided by the developer inside the repository's public methods. This page explains the **minimal** contract the template provides.

Related files: `core/result/`, `core/network/base_repository.dart`, `core/effect/`, `core/bloc/bloc_error_handler_mixin.dart`.

---

## 1. Why there is no `AppException` / `ErrorHandler`

Starting from 2.0.0, the old `AppException` system (including `ErrorHandler` / `AppErrorCodes` / `ServerMessageExtractor`) has been **removed entirely**. Reasons:

- The framework cannot predict your backend's response shape (field names, whether it wraps `{code,message,data}`, business-code rules), so forcing normalization would only push assumptions onto you.
- `BaseRepository` only holds a `Dio` instance and **performs no response handling**: no parsing, no HTTP status validation, no exception throwing.

```dart
abstract class BaseRepository {
  const BaseRepository({required this.dio});
  final Dio dio;
}
```

So network exceptions (`DioException`) are thrown **as-is**; each repository's public method decides what to do — catch, convert, or pass through to the upper layer.

---

## 2. Three-State Result: `Result<T>`

`core/result/result.dart` uses a sealed class to make async terminal states explicit, replacing `try/catch/if-cancelled` boilerplate:

```dart
sealed class Result<T> { ... }
final class Success<T> extends Result<T> { final T value; }
final class Failure<T> extends Result<T> { final Exception exception; }  // wraps Exception
final class Cancel<T> extends Result<T> { const Cancel(); }
```

> `Failure` carries an `Exception` (not some framework exception type). Any exception — whether a `DioException` or your own custom `Exception` — is uniformly wrapped into `Failure`, and the business layer only handles three states: success / failure (with Exception) / cancel.

Extension methods:

```dart
result.when(
  success: (value) => emit(state.copyWith(data: value)),
  failure: (ex) => emitEffect(ex.toToastEffect()),  // ex is an Exception
  cancel: () {/* active cancel, usually do nothing */},
);

result.valueOrNull;          // value on success, else null
result.isSuccess / isFailure / isCancel;
```

> `Cancel` is a separate branch, not `Failure`: an active user cancel should not be treated as an "error" and show a Toast.

---

## 3. Using It in the BLoC: `BlocErrorHandlerMixin`

The most concise writing (replaces hand-written `try/catch`):

```dart
final result = await runCatching(() => repository.fetch());
result.when(
  success: (items) => emit(state.copyWith(items: items)),
  failure: (ex) => emitEffect(ex.toToastEffect()),
  cancel: () {},
);
```

Capability list:

| Method | Purpose |
|--------|---------|
| `runCatching<T>(action)` | Wrap an async action → `Result<T>`; success → `Success`; `Exception` → `Failure(Exception)`; active cancel → `Cancel`; other errors → `Failure(Exception(...))` |
| `isCancelled(error)` | Whether it is an active cancel (`DioExceptionType.cancel`) |

`ex.toToastEffect()` comes from the `ExceptionToToast` extension (see section 4); `ex` is an `Exception`, so it can be called directly.

---

## 4. Exception → Toast: `ExceptionToToast`

`core/effect/ui_effect.dart` provides a lightweight extension that turns any `Exception` into a one-shot Toast effect:

```dart
extension ExceptionToToast on Exception {
  String? get errorMessage;        // Exception('msg') → 'msg'; returns null when empty
  ToastEffect toToastEffect() => ToastEffect(message: errorMessage);
}
```

Convention: an exception thrown as `Exception('text')` exposes its quoted text as the `ToastEffect.message`; the framework **makes no business or type assumption** — for custom localization or error codes, build the `ToastEffect` yourself (with `l10nCode` / `code`), or define a custom exception type that exposes text.

---

## 5. Toast Resolution Priority

`default_toast_effect_handle.dart` (the framework default handle) resolves a `ToastEffect` by this priority:

1. **`message`**: fixed / server text, used first;
2. **`l10nCode`**: a developer-defined localization key, resolved by a business handle per the project's i18n setup (unclaimed → debug warning, release silent);
3. **`code`**: an internal network error code (HTTP status or custom sentinel), mapped to `l.unknownError(code)` as fallback;
4. None of the above → `l.unknownError('Unknown')`.

See [Effect & Notifiers](../effect-system/index.md).

---

## 6. Using It in the Repository: `BaseRepository`

The repository extends `BaseRepository` and uses `dio` directly; **parsing and error judgment are up to you**:

```dart
class UserRepository extends BaseRepository {
  Future<List<User>> fetchUsers({CancelToken? cancelToken}) async {
    final res = await dio.get<List<dynamic>>('/users', cancelToken: cancelToken);
    // Parse res.data yourself (e.g. json_serializable / freezed fromJson)
    return (res.data as List).map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

Key points:

- The framework provides no `parseList` / `parseSingle` / `parseResponse` / `parseBusinessResponse`, and does not intercept HTTP status codes.
- Whether to treat non-2xx as failure, or judge success by a business code `{code,message,data}`, is entirely your decision.
- Network exceptions are thrown as-is; in the BLoC, `runCatching` wraps them into `Failure(Exception)`, which is then reported via `toToastEffect()`.

### Business status code (handle it yourself)

If the backend wraps with `{code,message,data}`, you read and judge it yourself:

```dart
Future<String> login({required String username, required String password}) async {
  final res = await dio.post('/login', data: {...});
  final body = res.data as Map<String, dynamic>;
  if (body['code'] != 0) {
    throw Exception(body['message'] ?? 'login failed');  // throw a plain exception; BLoC reports via toToastEffect
  }
  return body['data'] as String;
}
```

You can also directly `throw Exception('username or password cannot be empty')` for client-side validation.

---

## 7. Quick Reference: How a Feature Handles Errors

1. **Repository**: `extends BaseRepository`, use `dio` to send requests, parse `res.data` yourself; throw `Exception(...)` on business failure.
2. **Bloc**: `with BlocErrorHandlerMixin`, `runCatching(() => repo.xxx())`, `result.when` handles three states.
3. **Success**: `emit(state.copyWith(...))`.
4. **Failure**: `emitEffect(ex.toToastEffect())` (text decided by `message` / `l10nCode` / `code`, see section 5).
5. **Cancel**: `cancel: () {}` silently.

The framework does not write error-text mappings for you, does not intercept HTTP status, and does not guess field names — all of that belongs to the developer's repository code.

<!-- source-footer -->

---

*Source of this page: [docs/en/architecture/error-handling.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/architecture/error-handling.md)*

*[Report an error on this page](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_en.md&title=%5BDocs%20error%5D%20docs%2Fen%2Farchitecture%2Ferror-handling.md)*

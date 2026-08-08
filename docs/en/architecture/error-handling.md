# Error Handling & Result

The template converges "countless low-level exceptions" into "the business layer only handles one exception type, `AppException`", then uses `Result<T>` to make the three terminal states of an async operation (success / failure / cancel) explicit. This page explains how to use this packaging.

Related files: `core/error/`, `core/result/`, `core/storage/base_repository.dart`.

---

## 1. Exception Normalization: `AppException`

Low-level `DioException`, JSON parse errors, business-status-code failures … are all unified into subclasses of `AppException`; the business layer no longer imports `dio`.

Each exception carries:

- `message`: a human-readable text suitable for display (usually from the server and already translated; may be `null`).
- `code`: HTTP status code (401/404/500…) or an internal sentinel code (see `AppErrorCodes`).
- `originalError`: the raw low-level exception that triggered it.

```dart
abstract class AppException implements Exception {
  ToastEffect toToastEffect() => ToastEffect(message: message, code: code);
}
```

Built-in subclasses (`core/error/app_exception.dart`):

| Subclass | Trigger scenario |
|----------|------------------|
| `NetworkException` | No network / DNS failure (`connectionError`) |
| `ServerException` | HTTP 4xx/5xx (`badResponse`) |
| `AuthException` | 401 / 403 |
| `TimeoutException` | Connect / send / receive timeout (falls back to HTTP 408) |
| `ParseException` | JSON parse failure or unexpected structure |
| `BusinessException` | **HTTP 200 but business-status-code failure** (e.g. `{code:10001, message:"out of stock"}`) |
| `UnknownException` | Other errors that cannot be classified |

> `AppException` is **abstract, not sealed**: any library can `extends AppException` to add custom business exceptions, without modifying the framework.

---

## 2. The Single Conversion Point: `ErrorHandler`

All exception mapping goes through `ErrorHandler`, guaranteeing a consistent experience. `BlocErrorHandlerMixin` already holds it internally; the business layer usually doesn't touch it directly.

```dart
final handler = ErrorHandler();
try {
  await fetch();
} on Object catch (e, stackTrace) {
  final ex = handler.handle(e); // AppException? — returns null on cancel
  if (ex != null) showToast(ex.message ?? 'error');
}
```

- **Server message extraction**: by default it reads in order `message` / `error` / `errorMsg` / `msg`. Different backend field names? Pass them at construction:
  ```dart
  ErrorHandler(serverMessageExtractor: ServerMessageExtractor(['msg', 'errorMessage']))
  // or override the errorHandler getter in the BLoC
  ```
- **Cancel recognition**: `handler.isCancelled(error)` — `DioExceptionType.cancel` returns `true`, and should be silently ignored (no Toast, no state change).
- **No hard-coded text**: timeout / no-connection / unknown errors carry no hard-coded text; the `code` is left to the frontend to localize via `AppErrorCodes` (see section 5).

---

## 3. Three-State Result: `Result<T>`

`core/result/result.dart` uses a sealed class to make async terminal states explicit, replacing `try/catch/if-cancelled` boilerplate:

```dart
sealed class Result<T> { ... }
final class Success<T> extends Result<T> { final T value; }
final class Failure<T> extends Result<T> { final AppException exception; }
final class Cancel<T> extends Result<T> { const Cancel(); }
```

Extension methods:

```dart
result.when(
  success: (value) => emit(state.copyWith(data: value)),
  failure: (ex) => emitEffect(ex.toToastEffect()),
  cancel: () {/* active cancel, usually do nothing */},
);

result.valueOrNull;          // value on success, else null
result.isSuccess / isFailure / isCancel;
```

> `Cancel` is a separate branch, not `Failure`: an active user cancel should not be treated as an "error" and show a Toast.

---

## 4. Using It in the BLoC: `BlocErrorHandlerMixin`

The most concise writing (replaces hand-written `try/catch`):

```dart
final result = await runToResult(() => repository.fetch());
result.when(
  success: (items) => emit(state.copyWith(items: items)),
  failure: (ex) => emitEffect(ex.toToastEffect()),
  cancel: () {},
);
```

Capability list:

| Method | Purpose |
|--------|---------|
| `runToResult<T>(action)` | Wrap an async action → `Result<T>`; cancel → `Cancel`, other exceptions → `Failure(AppException)` |
| `runWithErrorHandling(action, onSuccess, onError)` | Callback style; returns `null` on error/cancel |
| `handleError(error)` | Any exception → `AppException?` (null on cancel) |
| `isCancelled(error)` | Check whether it is an active cancel |
| `errorHandler` (overridable) | Inject a custom `ServerMessageExtractor` |

The resolution priority of `ex.toToastEffect()` (see [Effect & Notifiers](../effect-system/index.md)): display `message` directly → fall back to `code` via `AppErrorCodes` → if it carries an `l10nCode`, it must be translated by the business handle.

---

## 5. Error Codes & Localization: `AppErrorCodes`

`core/error/app_error_codes.dart` defines internal codes (a negative namespace, to avoid colliding with HTTP) and common HTTP code constants:

| Category | Constant |
|----------|----------|
| Internal | `unknown=-1` / `parseFromJson=-2` / `parseNullData=-3` / `parseWrongType=-4` / `noConnection=-5` |
| 4xx | `badRequest=400` … `tooManyRequests=429` |
| 5xx | `internalServerError=500` … `gatewayTimeout=504` |

`defaultToastHandle` maps these codes to localized text (e.g. `error404` → "The requested resource does not exist"); unlisted codes fall back to `unknownErrorCode`. So **even if the backend returns no text, the user still sees a readable error prompt**.

---

## 6. Using It in the Repository: `BaseRepository`

The repository extends `BaseRepository`, so you don't write JSON parsing and error checks by hand.

### Flat responses: `parseList` / `parseSingle` / `parseResponse`

```dart
class UserRepository extends BaseRepository {
  Future<List<User>> fetchUsers({CancelToken? cancelToken}) async {
    final res = await client.get<List<dynamic>>('/users', cancelToken: cancelToken);
    return parseList(res, User.fromJson);      // data is an array
    // or parseSingle(res, User.fromJson);       // data is a single object
    // or parseResponse<ApiResp>(res, ApiResp.fromJson); // nested structure to freezed
  }
}
```

A type mismatch automatically throws `ParseException` (with the corresponding `AppErrorCodes`).

### Business status code: `parseBusinessResponse`

HTTP 200 but `code != 0` in the body means a business failure. **The framework does not guess field names**; you provide the parsing and extraction logic, and it throws `BusinessException` after confirming 2xx:

```dart
Future<String> login({required String username, required String password}) async {
  final res = await client.post('/login', data: {...});
  return parseBusinessResponse<String, LoginResp>(
    res,
    parseBody: LoginResp.fromJson,
    isSuccess: (b) => b.code == 0,           // business success judgment
    extractCode: (b) => b.code,              // optional: error code
    extractMessage: (b) => b.message,        // optional: server text
    extractData: (b) => b.data,              // data extracted on success
  );
}
```

- Non-2xx response → immediately throws `ServerException` (fallback by HTTP code in `ErrorHandler`).
- 2xx but `isSuccess` is false → throws `BusinessException(extractMessage, code: extractCode)`.
- Pure client-side validation (e.g. empty username) can also directly `throw const BusinessException('Username or password cannot be empty')`.

### Full chain

```
Repository throws AppException
   ↓ (DioException already converted in ErrorHandler; BusinessException thrown by you)
BlocErrorHandlerMixin.runToResult
   ↓
Result<T>.when(success / failure / cancel)
   ↓
failure → emitEffect(ex.toToastEffect())
   ↓
EffectListener responsibility chain → Toast (message directly / code via AppErrorCodes / l10nCode business handle)
```

---

## 7. Quick Reference: How a Feature Handles Errors

1. **Repository**: `extends BaseRepository`, uses `parseBusinessResponse` etc.; throws `BusinessException` on business failure.
2. **Bloc**: `with BlocErrorHandlerMixin`, `runToResult(() => repo.xxx())`, `result.when` handles three states.
3. **Success**: `emit(state.copyWith(...))`.
4. **Failure**: `emitEffect(ex.toToastEffect())` (auto-fallback by message / code, or a custom `l10nCode` goes through the business handle).
5. **Cancel**: `cancel: () {}` silently.

No `try/catch`, no `dio` import, no hand-written error-text mapping — all taken over by the packaging.

<!-- source-footer -->

---

*Source of this page: [docs/en/architecture/error-handling.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/architecture/error-handling.md)*

*[Report an error on this page](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_en.md&title=%5BDocs%20error%5D%20docs%2Fen%2Farchitecture%2Ferror-handling.md)*

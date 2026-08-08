# 错误处理与 Result

模板把「底层异常千奇百怪」收敛为「业务层只处理 `AppException` 一种异常」，再用 `Result<T>` 把异步操作的三种终态（成功 / 失败 / 取消）显式化。本页讲清这套封装怎么用。

相关文件：`core/error/`、`core/result/`、`core/storage/base_repository.dart`。

---

## 1. 异常归一化：`AppException`

底层 `DioException`、JSON 解析错、业务状态码失败……都被统一成 `AppException` 的子类，业务层不再 import `dio`。

每个异常携带：

- `message`：适合展示的可读文本（通常来自服务端且已翻译，可为 `null`）。
- `code`：HTTP 状态码（401/404/500…）或内部哨兵码（见 `AppErrorCodes`）。
- `originalError`：触发它的原始底层异常。

```dart
abstract class AppException implements Exception {
  ToastEffect toToastEffect() => ToastEffect(message: message, code: code);
}
```

内置子类（`core/error/app_exception.dart`）：

| 子类 | 触发场景 |
|------|----------|
| `NetworkException` | 无网络 / DNS 失败（`connectionError`） |
| `ServerException` | HTTP 4xx/5xx（`badResponse`） |
| `AuthException` | 401 / 403 |
| `TimeoutException` | 连接 / 发送 / 接收超时（按 HTTP 408 兜底） |
| `ParseException` | JSON 解析失败或结构不符预期 |
| `BusinessException` | **HTTP 200 但业务状态码失败**（如 `{code:10001, message:"库存不足"}`） |
| `UnknownException` | 无法归类的其它错误 |

> `AppException` 是 **abstract 而非 sealed**：任何库都能 `extends AppException` 加自定义业务异常，无需改框架。

---

## 2. 单一转换点：`ErrorHandler`

所有异常映射都经过 `ErrorHandler`，保证一致体验。`BlocErrorHandlerMixin` 内部已持有它，业务层通常不直接接触。

```dart
final handler = ErrorHandler();
try {
  await fetch();
} on Object catch (e, stackTrace) {
  final ex = handler.handle(e); // AppException? —— 取消返回 null
  if (ex != null) showToast(ex.message ?? '出错');
}
```

- **服务端消息提取**：默认按 `message` / `error` / `errorMsg` / `msg` 顺序取值。后端字段名不同？构造时传入：
  ```dart
  ErrorHandler(serverMessageExtractor: ServerMessageExtractor(['msg', 'errorMessage']))
  // 或在 BLoC 覆盖 errorHandler getter
  ```
- **取消识别**：`handler.isCancelled(error)` —— `DioExceptionType.cancel` 返回 `true`，应静默忽略（不弹 Toast、不更状态）。
- **不写死文案**：超时 / 无连接 / 未知错误都不带硬编码文本，`code` 交给前端按 `AppErrorCodes` 本地化（见第 5 节）。

---

## 3. 三态结果：`Result<T>`

`core/result/result.dart` 用密封类把异步终态显式化，取代 `try/catch/if-cancelled` 样板：

```dart
sealed class Result<T> { ... }
final class Success<T> extends Result<T> { final T value; }
final class Failure<T> extends Result<T> { final AppException exception; }
final class Cancel<T> extends Result<T> { const Cancel(); }
```

扩展方法：

```dart
result.when(
  success: (value) => emit(state.copyWith(data: value)),
  failure: (ex) => emitEffect(ex.toToastEffect()),
  cancel: () {/* 主动取消，通常什么都不做 */},
);

result.valueOrNull;          // 成功取 value，否则 null
result.isSuccess / isFailure / isCancel;
```

> `Cancel` 是独立分支而非 `Failure`：用户主动取消不应被当作「错误」弹 Toast。

---

## 4. 在 BLoC 里用：`BlocErrorHandlerMixin`

最简洁的写法（取代手写 `try/catch`）：

```dart
final result = await runToResult(() => repository.fetch());
result.when(
  success: (items) => emit(state.copyWith(items: items)),
  failure: (ex) => emitEffect(ex.toToastEffect()),
  cancel: () {},
);
```

能力清单：

| 方法 | 作用 |
|------|------|
| `runToResult<T>(action)` | 包裹异步操作 → `Result<T>`；取消 → `Cancel`，其余异常 → `Failure(AppException)` |
| `runWithErrorHandling(action, onSuccess, onError)` | 回调式，出错/取消返回 `null` |
| `handleError(error)` | 任意异常 → `AppException?`（取消为 `null`） |
| `isCancelled(error)` | 判断是否主动取消 |
| `errorHandler`（可覆盖） | 注入自定义 `ServerMessageExtractor` |

`ex.toToastEffect()` 的解析优先级（见 [Effect 与 Notifiers](../effect-system/index.md)）：`message` 直接显示 → `code` 按 `AppErrorCodes` 兜底 → 若带 `l10nCode` 则必须由业务 handle 翻译。

---

## 5. 错误码与本地化：`AppErrorCodes`

`core/error/app_error_codes.dart` 定义了内部码（负数命名空间，避免与 HTTP 冲突）与常见 HTTP 码常量：

| 类别 | 常量 |
|------|------|
| 内部码 | `unknown=-1` / `parseFromJson=-2` / `parseNullData=-3` / `parseWrongType=-4` / `noConnection=-5` |
| 4xx | `badRequest=400` … `tooManyRequests=429` |
| 5xx | `internalServerError=500` … `gatewayTimeout=504` |

`defaultToastHandle` 按这些码映射为本地化文案（如 `error404` → "请求的资源不存在"）；未列出的码走 `unknownErrorCode` 兜底。因此**即便后端没返回文案，用户也能看到可读的错误提示**。

---

## 6. 在 Repository 里用：`BaseRepository`

仓库继承 `BaseRepository`，无需手写 JSON 解析与错误判断。

### 扁平响应：`parseList` / `parseSingle` / `parseResponse`

```dart
class UserRepository extends BaseRepository {
  Future<List<User>> fetchUsers({CancelToken? cancelToken}) async {
    final res = await client.get<List<dynamic>>('/users', cancelToken: cancelToken);
    return parseList(res, User.fromJson);      // data 是数组
    // 或 parseSingle(res, User.fromJson);       // data 是单对象
    // 或 parseResponse<ApiResp>(res, ApiResp.fromJson); // 嵌套结构交给 freezed
  }
}
```

类型不符会自动抛 `ParseException`（带对应 `AppErrorCodes`）。

### 业务状态码：`parseBusinessResponse`

HTTP 200 但 body 内 `code != 0` 表示业务失败。**框架不猜字段名**，由你提供解析与提取逻辑，它在确认 2xx 后抛 `BusinessException`：

```dart
Future<String> login({required String username, required String password}) async {
  final res = await client.post('/login', data: {...});
  return parseBusinessResponse<String, LoginResp>(
    res,
    parseBody: LoginResp.fromJson,
    isSuccess: (b) => b.code == 0,           // 业务成功判定
    extractCode: (b) => b.code,              // 可选：错误码
    extractMessage: (b) => b.message,        // 可选：服务端文案
    extractData: (b) => b.data,              // 成功时提取的数据
  );
}
```

- 非 2xx 响应 → 立即抛 `ServerException`（由 `ErrorHandler` 按 HTTP 码兜底）。
- 2xx 但 `isSuccess` 为 false → 抛 `BusinessException(extractMessage, code: extractCode)`。
- 纯客户端校验（如空用户名）也可直接 `throw const BusinessException('用户名或密码不能为空')`。

### 完整链路

```
Repository 抛 AppException
   ↓（DioException 已在 ErrorHandler 转好；BusinessException 由你抛）
BlocErrorHandlerMixin.runToResult
   ↓
Result<T>.when(success / failure / cancel)
   ↓
failure → emitEffect(ex.toToastEffect())
   ↓
EffectListener 责任链 → Toast（message 直接 / code 按 AppErrorCodes / l10nCode 业务 handle）
```

---

## 7. 速查：一个功能怎么处理错误

1. **Repository**：`extends BaseRepository`，用 `parseBusinessResponse` 等；业务失败抛 `BusinessException`。
2. **Bloc**：`with BlocErrorHandlerMixin`，`runToResult(() => repo.xxx())`，`result.when` 处理三态。
3. **成功**：`emit(state.copyWith(...))`。
4. **失败**：`emitEffect(ex.toToastEffect())`（自动按 message / code 兜底，或自定义 `l10nCode` 走业务 handle）。
5. **取消**：`cancel: () {}` 静默。

无需 `try/catch`、无需 import `dio`、无需手写错误文案映射——全部由封装接管。

<!-- source-footer -->

---

*本页原文：[docs/zh/architecture/error-handling.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/architecture/error-handling.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Farchitecture%2Ferror-handling.md)*

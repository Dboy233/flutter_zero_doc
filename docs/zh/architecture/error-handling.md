# 错误处理与 Result

模板对错误处理奉行**「零封装、零业务假设」**原则：框架不替你捕获、转换、归一化任何异常，也不替你解析响应。所有「怎么发请求、怎么解析、怎么抛错」都由开发者在仓库公开方法里自行决定。本页讲清模板提供的**最小化**契约。

相关文件：`core/result/`、`core/network/base_repository.dart`、`core/effect/`、`core/bloc/bloc_error_handler_mixin.dart`。

---

## 1. 为什么没有 `AppException` / `ErrorHandler`

2.0.0 起，旧版的 `AppException` 体系（含 `ErrorHandler` / `AppErrorCodes` / `ServerMessageExtractor`）已**整体移除**。原因：

- 框架无法预判你的后端返回结构（字段名、是否包裹 `{code,message,data}`、业务码规则），强行归一化只会把假设塞给你。
- `BaseRepository` 只持有一个 `Dio` 实例，**不做任何响应处理**：不解析、不校验 HTTP 状态码、不抛任何异常。

```dart
abstract class BaseRepository {
  const BaseRepository({required this.dio});
  final Dio dio;
}
```

因此网络异常（`DioException`）会**原样外抛**，由各 Repository 的公开方法决定如何处理——捕获、转换、还是直接透传给上层。

---

## 2. 三态结果：`Result<T>`

`core/result/result.dart` 用密封类把异步操作的三种终态显式化，取代 `try/catch/if-cancelled` 样板：

```dart
sealed class Result<T> { ... }
final class Success<T> extends Result<T> { final T value; }
final class Failure<T> extends Result<T> { final Exception exception; }  // 包 Exception
final class Cancel<T> extends Result<T> { const Cancel(); }
```

> `Failure` 携带的是 `Exception`（不是某种框架异常类型）。任何异常——无论 `DioException` 还是你自定义的 `Exception`——统一包进 `Failure`，业务层只处理「成功 / 失败（带 Exception）/ 取消」三态。

扩展方法：

```dart
result.when(
  success: (value) => emit(state.copyWith(data: value)),
  failure: (ex) => emitEffect(ex.toToastEffect()),  // ex 是 Exception
  cancel: () {/* 主动取消，通常什么都不做 */},
);

result.valueOrNull;          // 成功取 value，否则 null
result.isSuccess / isFailure / isCancel;
```

> `Cancel` 是独立分支而非 `Failure`：用户主动取消不应被当作「错误」弹 Toast。

---

## 3. 在 BLoC 里用：`BlocErrorHandlerMixin`

最简洁的写法（取代手写 `try/catch`）：

```dart
final result = await runCatching(() => repository.fetch());
result.when(
  success: (items) => emit(state.copyWith(items: items)),
  failure: (ex) => emitEffect(ex.toToastEffect()),
  cancel: () {},
);
```

能力清单：

| 方法 | 作用 |
|------|------|
| `runCatching<T>(action)` | 包裹异步操作 → `Result<T>`；成功 → `Success`；`Exception` → `Failure(Exception)`；主动取消 → `Cancel`；其它异常 → `Failure(Exception(...))` |
| `isCancelled(error)` | 是否主动取消（`DioExceptionType.cancel`） |

`ex.toToastEffect()` 来自 `ExceptionToToast` 扩展（见第 4 节），`ex` 是 `Exception`，可直接调用。

---

## 4. 异常 → Toast：`ExceptionToToast`

`core/effect/ui_effect.dart` 提供了一个轻量扩展，把任意 `Exception` 转成一次性 Toast 副作用：

```dart
extension ExceptionToToast on Exception {
  String? get errorMessage;        // Exception('msg') → 'msg'；无文案返回 null
  ToastEffect toToastEffect() => ToastEffect(message: errorMessage);
}
```

约定：`Exception('文案')` 抛出的异常会取其引号内文案作为 `ToastEffect.message`；框架**不做任何业务或类型假设**——需要本地化或错误码时，业务层自行构造 `ToastEffect`（带 `l10nCode` / `code`），或定义携带文案的自定义异常类型。

---

## 5. Toast 的展示优先级

`default_toast_effect_handle.dart`（框架默认 handle）对 `ToastEffect` 的解析优先级：

1. **`message`**：可直接显示的固定/服务端文本，优先使用；
2. **`l10nCode`**：开发者自定义的本地化键，由业务 handle 按项目 i18n 方案解析（未被认领时 debug 模式告警、release 静默）；
3. **`code`**：网络请求内部错误码（HTTP 状态码或自定义哨兵码），统一走 `l.unknownError(code)` 兜底文案；
4. 三者皆无 → `l.unknownError('Unknown')`。

详见 [Effect 与 Notifiers](../effect-system/index.md)。

---

## 6. 在 Repository 里用：`BaseRepository`

仓库继承 `BaseRepository`，直接用 `dio` 发请求，**解析与错误判断由你决定**：

```dart
class UserRepository extends BaseRepository {
  Future<List<User>> fetchUsers({CancelToken? cancelToken}) async {
    final res = await dio.get<List<dynamic>>('/users', cancelToken: cancelToken);
    // 自行解析 res.data（如 json_serializable / freezed 的 fromJson）
    return (res.data as List).map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

要点：

- 框架不提供 `parseList` / `parseSingle` / `parseResponse` / `parseBusinessResponse`，也不拦截 HTTP 状态码。
- 是否需要把 HTTP 非 2xx 当失败、是否按业务码 `{code,message,data}` 判断成功，完全由你决定。
- 网络异常会原样外抛；BLoC 中 `runCatching` 会把它包成 `Failure(Exception)`，再经 `toToastEffect()` 上报。

### 业务状态码（自行处理）

若后端用 `{code,message,data}` 包裹，由你读取并判断：

```dart
Future<String> login({required String username, required String password}) async {
  final res = await dio.post('/login', data: {...});
  final body = res.data as Map<String, dynamic>;
  if (body['code'] != 0) {
    throw Exception(body['message'] ?? '登录失败');  // 抛普通异常，BLoC 经 toToastEffect 上报
  }
  return body['data'] as String;
}
```

也可直接 `throw Exception('用户名或密码不能为空')` 做客户端校验。

---

## 7. 速查：一个功能怎么处理错误

1. **Repository**：`extends BaseRepository`，用 `dio` 发请求，自行解析 `res.data`；需要业务失败时 `throw Exception(...)`。
2. **Bloc**：`with BlocErrorHandlerMixin`，`runCatching(() => repo.xxx())`，`result.when` 处理三态。
3. **成功**：`emit(state.copyWith(...))`。
4. **失败**：`emitEffect(ex.toToastEffect())`（由 `message` / `l10nCode` / `code` 决定文案，见第 5 节）。
5. **取消**：`cancel: () {}` 静默。

框架不替你写错误文案映射、不拦截 HTTP 状态、不做字段名猜测——这些都交给开发者的仓库代码。

<!-- source-footer -->

---

*本页原文：[docs/zh/architecture/error-handling.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/architecture/error-handling.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Farchitecture%2Ferror-handling.md)*

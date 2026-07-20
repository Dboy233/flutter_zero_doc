# 编写第一个功能模块

本页用一个完整的 **登录功能** 演示如何把模板封装好的积木串起来写业务。每一步都对应一个封装点，照着做你就能在任何功能里复用同一套路。

先生成骨架：

```bash
fluzer new login
```

生成后目录：

```
lib/features/login/
├── login_module.dart                     # DI 注册（只注册 Repository）
├── data/
│   ├── models/login_model.dart          # 数据模型（freezed）
│   └── repositories/login_repository.dart
└── presentation/
    ├── bloc/
    │   ├── login_bloc.dart               # 已混入四个 Mixin
    │   ├── login_event.dart              # freezed 空壳
    │   └── login_state.dart              # freezed 空壳
    ├── effects/login_effect_handle.dart  # 业务副作用处理器
    └── pages/
        ├── login_page.dart               # BlocProvider + EffectListener
        └── login_body.dart               # 纯渲染内容
```

---

## 1. 定义 Intent（事件）与 ViewState（状态）

`login_event.dart` / `login_state.dart` 用 freezed 定义，状态永远不可变、只 `copyWith`：

```dart
// login_event.dart
@freezed
abstract class LoginEvent with _$LoginEvent {
  const factory LoginEvent.usernameChanged(String value) =
      LoginUsernameChanged;
  const factory LoginEvent.passwordChanged(String value) =
      LoginPasswordChanged;
  const factory LoginEvent.submit() = LoginSubmit;
}

// login_state.dart
@freezed
abstract class LoginState with _$LoginState {
  const factory LoginState({
    @Default('') String username,
    @Default('') String password,
    @Default(false) bool isSubmitting,
    @Default(false) bool isSuccess,
    String? nickname,
    String? error,
  }) = _LoginState;
}
```

!!! note "为什么状态不持有 DTO？"
    模板接受「状态直接持有数据层 DTO」的主流取舍（见 [架构总览](../architecture/)）。若你追求最严格分层，可在 Bloc 内把 `XxxModel` 映射成 `XxxUiModel` 再进 `State`。

---

## 2. 写 Repository（继承 BaseRepository）

仓库负责网络与解析，**业务状态码失败主动抛 `BusinessException`**。`BaseRepository` 已提供 `parseList` / `parseSingle` / `parseResponse` / `parseBusinessResponse`，无需手写 JSON 解析。

```dart
// login_repository.dart
class LoginRepository extends BaseRepository {
  const LoginRepository({required super.client});

  Future<String> login({
    required String username,
    required String password,
    CancelToken? cancelToken,
  }) async {
    final response = await client.post('/login', data: {
      'username': username,
      'password': password,
    });

    // 假设后端返回 {code:0, message:'ok', data:'昵称'}
    return parseBusinessResponse<String, LoginResp>(
      response,
      parseBody: LoginResp.fromJson,
      isSuccess: (body) => body.code == 0,
      extractCode: (body) => body.code,
      extractMessage: (body) => body.message,
      extractData: (body) => body.data,
    );
  }
}
```

- HTTP 非 2xx → 自动抛 `ServerException`，由 `ErrorHandler` 按 HTTP 码兜底翻译。
- HTTP 200 但 `code != 0` → 抛 `BusinessException`，文案来自后端 `message`。
- 纯客户端校验（如空用户名）也可直接 `throw const BusinessException('用户名或密码不能为空')`。

---

## 3. 写 Bloc（四个 Mixin 协同）

`login_bloc.dart` 已 `with` 四个 Mixin。把它们组合起来完成一次「可等待 + 带 Loading + 统一错误处理」的登录：

```dart
class LoginBloc extends Bloc<LoginEvent, LoginState>
    with
        BlocAwaitMixin<LoginEvent, LoginState>,
        BlocEffectMixin<LoginState>,
        BlocErrorHandlerMixin<LoginState>,
        BlocCancelTokenMixin<LoginState> {
  LoginBloc({required this.repository}) : super(const LoginState()) {
    on<LoginUsernameChanged>(_onUsernameChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    onAwait<LoginSubmit>(_awaitKeySubmit, _onSubmit); // 自动收尾的 await
  }

  final LoginRepository repository;
  static const String _awaitKeySubmit = 'login_submit';

  /// 页面可 await 这次提交（如登录成功后跳转）。
  Future<void> submit() =>
      runAwait(event: const LoginEvent.submit(), key: _awaitKeySubmit);

  Future<void> _onSubmit(LoginSubmit event, Emitter<LoginState> emit) async {
    emit(state.copyWith(isSubmitting: true, error: null));

    // 1) 副作用：显示全局 Loading（交给框架默认 handle）
    emitEffect(const LoadingEffect(show: true));

    // 2) 统一错误处理：成功 / 失败 / 取消 三态显式
    final result = await runToResult(
      () => repository.login(
        username: state.username,
        password: state.password, 
        cancelToken: token('login')
      ),
    );

    // 3) 副作用：隐藏 Loading
    emitEffect(const LoadingEffect(show: false));

    result.when(
      success: (nickname) {
        emit(state.copyWith(isSubmitting: false, isSuccess: true, nickname: nickname));
        emitEffect(const ToastEffect(l10nCode: 'loginSuccess'));
      },
      failure: (ex) {
        emit(state.copyWith(isSubmitting: false, error: ex.message));
        emitEffect(const ToastEffect(l10nCode: 'loginFailed'));
      },
      cancel: () => emit(state.copyWith(isSubmitting: false)),
    );
  }
}
```

要点：

- **`runToResult`** 取代手写 `try/catch`：网络异常 / 取消都被归一化，你只需处理三态。
- **`LoadingEffect`** 不经过业务 handle，由框架默认 handle 调 `LoadingService` 显示/隐藏全局 Loading。
- **`ToastEffect(l10nCode: ...)`** 用自定义本地化键，由业务 handle 翻译（见第 4 步）。若只想显示服务端文案，可直接用 `ToastEffect(message: ex.message)` 或 `ex.toToastEffect()`。

---

## 4. 写业务副作用处理器（l10nCode → 文本）

`login_effect_handle.dart` 用 `is` 认领自己关心的 `l10nCode`，**不穷尽 `switch`**；其余交给框架默认 handle：

```dart
bool loginEffectHandle(BuildContext context, UIEffect effect) {
  if (effect is ToastEffect && effect.l10nCode != null) {
    final service = getIt<ToastService>();
    final l = context.l;
    switch (effect.l10nCode) {
      case 'loginSuccess':
        service.showSuccess(l.loginSuccess);
        return true;
      case 'loginFailed':
        service.showError(l.loginFailed);
        return true;
      default:
        return false;
    }
  }
  return false; // 其余交给框架默认 handle
}
```

并在 `l10n/app_zh.arb` / `app_en.arb` 增加对应 key：

```json
{
  "loginSuccess": "登录成功",
  "loginFailed": "登录失败"
}
```

> `context.l` 是模板提供的便捷扩展，等价于 `AppLocalizations.of(context)`。

---

## 5. 接 Page（BlocProvider + EffectListener）

骨架的 `login_page.dart` 已经接好：

```dart
BlocProvider(
  create: (_) => LoginBloc(repository: getIt<LoginRepository>()),
  child: const EffectListener<LoginBloc, LoginState>(
    effectsHandles: [loginEffectHandle],
    child: LoginBody(),
  ),
)
```

`login_body.dart` 是 `State` 的纯函数：只读 `context.watch<LoginBloc>()`，只通过 `context.read<LoginBloc>().add(...)` / `.submit()` 发射意图：

```dart
final bloc = context.watch<LoginBloc>();
final state = bloc.state;
// 渲染 state.username / state.isSubmitting ...
// 提交：await bloc.submit();  // 可等待
// 或：context.read<LoginBloc>().add(const LoginEvent.submit());
```

---

## 6. 运行

```bash
flutter gen-l10n
dart run build_runner build
flutter run
```

完成后的数据流：

```
点击登录 → bloc.submit()（可 await）
  → emit(isSubmitting:true) + emitEffect(LoadingEffect(show:true))
  → runToResult(repository.login)
  → emitEffect(LoadingEffect(show:false))
  → result.when: 成功→emit(state)+Toast(l10nCode:loginSuccess)
               失败→emit(state)+Toast(l10nCode:loginFailed)
               取消→emit(isSubmitting:false)
```

---

## 套路小结（复制即用）

任意功能模块都遵循同一套：

1. `fluzer new <name>` 生成骨架。
2. `Event` / `State` 用 freezed；状态不可变。
3. `Repository extends BaseRepository`，用 `parseBusinessResponse` 等业务状态码解析，失败抛 `BusinessException`。
4. Bloc `with` 四个 Mixin：`onAwait` 做可等待操作，`runToResult` 做统一错误处理，`emitEffect(LoadingEffect/ToastEffect)` 做一次性副作用。
5. `effects/<name>_effect_handle.dart` 只翻译自定义 `l10nCode`，其余交默认 handle。
6. 页面只渲染 `State`、只发射意图。

更细的封装用法见 [BLoC 四个 Mixin](../architecture/bloc-mixins.md)、[错误处理与 Result](../architecture/error-handling.md)、[Effect 与 Notifiers](../effect-system/index.md)。

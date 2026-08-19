# Write Your First Feature

This page uses a complete **login feature** to demonstrate how to wire the template's packaged building blocks together to write business logic. Each step corresponds to one abstraction point; follow it and you can reuse the same pattern in any feature.

Generate the skeleton first:

```bash
fluzer new login
```

Directory after generation:

```
lib/features/login/
├── login_module.dart                     # DI registration (only the Repository)
├── data/
│   ├── models/login_model.dart          # Data model (freezed)
│   └── repositories/login_repository.dart
└── presentation/
    ├── bloc/
    │   ├── login_bloc.dart               # Already mixes in the four Mixins
    │   ├── login_event.dart              # freezed empty shell
    │   └── login_state.dart              # freezed empty shell
    ├── effects/login_effect_handle.dart  # Business side-effect handler
    └── pages/
        ├── login_page.dart               # BlocProvider + EffectListener
        └── login_body.dart               # Pure render content
```

---

## 1. Define Intent (Event) and ViewState (State)

`login_event.dart` / `login_state.dart` are defined with freezed; state is always immutable and only `copyWith`:

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

!!! note "Why doesn't State hold the DTO?"
    The template accepts the mainstream trade-off of "state holding the data-layer DTO directly" (see [Architecture Overview](../architecture/)). If you want the strictest layering, map `XxxModel` to `XxxUiModel` inside the Bloc before it enters `State`.

---

## 2. Write the Repository (extend BaseRepository)

The repository handles the network and parsing. The framework **does not parse the response for you** — everything about "sending the request / parsing / judging business errors / throwing" is decided in `LoginRepository`'s public methods (see [Error Handling & Result](../architecture/error-handling.md)). `BaseRepository` only holds `Dio` and provides no `parse*` helper.

```dart
// login_repository.dart
class LoginRepository extends BaseRepository {
  const LoginRepository({required super.dio});

  Future<String> login({
    required String username,
    required String password,
    CancelToken? cancelToken,
  }) async {
    final response = await dio.post('/login', data: {
      'username': username,
      'password': password,
    });

    // Suppose the backend returns {code:0, message:'ok', data:'nickname'}
    // The framework does not parse for you: response structure, business-code
    // checks, and how to throw are all your decision.
    final body = response.data as Map<String, dynamic>;
    if (body['code'] != 0) {
      // business code != 0 → throw Exception; text from backend message,
      // handled by the Bloc's failure branch
      throw Exception(body['message']?.toString() ?? 'login failed');
    }
    return body['data'] as String; // nickname
  }
}
```

- Non-2xx HTTP → Dio throws `DioException` directly; for a unified prompt, use `ex.toToastEffect()` in the Bloc's `failure` branch (the framework does no auto-translation).
- HTTP 200 but a non-zero business code → throw `Exception` (text from the backend `message`), handled by the Bloc's `failure` branch.
- Pure client-side validation (e.g. empty username) can also directly `throw Exception('Username or password cannot be empty')`.

---

## 3. Write the Bloc (four Mixins working together)

`login_bloc.dart` already `with` the four Mixins. Combine them to complete a single "awaitable + with Loading + unified error handling" login:

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
    onAwait<LoginSubmit>(_awaitKeySubmit, _onSubmit); // auto-finalized await
  }

  final LoginRepository repository;
  static const String _awaitKeySubmit = 'login_submit';

  /// The page can await this submission (e.g. navigate after a successful login).
  Future<void> submit() =>
      runAwait(event: const LoginEvent.submit(), key: _awaitKeySubmit);

  Future<void> _onSubmit(LoginSubmit event, Emitter<LoginState> emit) async {
    emit(state.copyWith(isSubmitting: true, error: null));

    // 1) Side-effect: show global Loading (handled by the framework default handle)
    emitEffect(const LoadingEffect(show: true));

    // 2) Unified error handling: three explicit terminal states (success/failure/cancel)
    final result = await runCatching(
      () => repository.login(
        username: state.username,
        password: state.password,
        cancelToken: token('login'),
      ),
    );

    // 3) Side-effect: hide Loading
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

Key points:

- **`runCatching`** replaces hand-written `try/catch`: network exceptions / cancellations are wrapped into the three-state `Result`; you only handle the three states, and `Failure` carries the raw `Exception` (no normalization).
- **`LoadingEffect`** does not go through the business handle; the framework default handle calls `LoadingService` to show/hide the global Loading.
- **`ToastEffect(l10nCode: ...)`** uses a custom localization key, translated by the business handle (see step 4). To show the server text directly, use `ToastEffect(message: ex.message)` or `ex.toToastEffect()`.

---

## 4. Write the business side-effect handler (l10nCode → text)

`login_effect_handle.dart` uses `is` to claim the `l10nCode` it cares about, and does **not exhaustively `switch`**; everything else falls through to the framework default handle:

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
  return false; // everything else falls through to the framework default handle
}
```

And add the corresponding keys to `l10n/app_zh.arb` / `app_en.arb`:

```json
{
  "loginSuccess": "Login successful",
  "loginFailed": "Login failed"
}
```

> `context.l` is a convenience extension provided by the template, equivalent to `AppLocalizations.of(context)`.

---

## 5. Wire the Page (BlocProvider + EffectListener)

The skeleton's `login_page.dart` is already wired:

```dart
BlocProvider(
  create: (_) => LoginBloc(repository: getIt<LoginRepository>()),
  child: const EffectListener<LoginBloc, LoginState>(
    effectsHandles: [loginEffectHandle],
    child: LoginBody(),
  ),
)
```

`login_body.dart` is a pure function of `State`: it only reads `context.watch<LoginBloc>()`, and only emits intents via `context.read<LoginBloc>().add(...)` / `.submit()`:

```dart
final bloc = context.watch<LoginBloc>();
final state = bloc.state;
// render state.username / state.isSubmitting ...
// submit: await bloc.submit();  // awaitable
// or: context.read<LoginBloc>().add(const LoginEvent.submit());
```

---

## 6. Run

```bash
flutter gen-l10n
dart run build_runner build
flutter run
```

Data flow after completion:

```
Tap login → bloc.submit() (awaitable)
  → emit(isSubmitting:true) + emitEffect(LoadingEffect(show:true))
  → runCatching(repository.login)
  → emitEffect(LoadingEffect(show:false))
  → result.when: success → emit(state)+Toast(l10nCode:loginSuccess)
                failure → emit(state)+Toast(l10nCode:loginFailed)
                cancel  → emit(isSubmitting:false)
```

---

## Pattern Recap (copy-paste ready)

Every feature module follows the same recipe:

1. `fluzer new <name>` generates the skeleton.
2. `Event` / `State` use freezed; state is immutable.
3. `Repository extends BaseRepository`, sends requests directly via `dio`, parses the response manually, and throws `Exception` as needed — the framework makes no parsing assumption.
4. The Bloc `with` the four Mixins: `onAwait` for awaitable actions, `runCatching` for unified error handling, `emitEffect(LoadingEffect/ToastEffect)` for one-shot side-effects.
5. `effects/<name>_effect_handle.dart` only translates custom `l10nCode`; everything else falls through to the default handle.
6. The page only renders `State` and only emits intents.

For finer-grained usage, see [The Four BLoC Mixins](../architecture/bloc-mixins.md), [Error Handling & Result](../architecture/error-handling.md), and [Effect & Notifiers](../effect-system/index.md).

<!-- source-footer -->

---

*Source of this page: [docs/en/getting-started/your-first-feature.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/getting-started/your-first-feature.md)*

*[Report an error on this page](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_en.md&title=%5BDocs%20error%5D%20docs%2Fen%2Fgetting-started%2Fyour-first-feature.md)*

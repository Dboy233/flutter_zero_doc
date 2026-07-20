# Dependency Injection

The template uses `get_it` for service location. DI is coordinated by **three files**, separating the "framework-maintained region" from the "hand-written region", so that `fluzer new` can auto-inject new modules without overwriting your hand-written code.

Related files: `core/di/`.

---

## 1. Responsibilities of the Three Files

| File | Role | Who edits |
|------|------|-----------|
| `get_it_instance.dart` | The global `getIt` instance | Framework (untouched) |
| `injection_base.dart` | `InjectionBase` abstract class: `registerAll` + `registerFeatureModules` (script-maintained region) | `fluzer new` auto-writes `XxxModule.register(getIt)` |
| `injection.dart` | `Injection extends InjectionBase`: implements `registerBaseDependencies` (infrastructure) + `registerUserDependencies` (custom) | **You** hand-write |

### Registration order

The order before `main.dart` calls `getIt.allReady()` is fixed by `registerAll`:

```dart
Future<void> registerAll() async {
  await registerBaseDependencies(); // 1. Infrastructure: storage/auth/network/notifiers/l10n/theme
  await registerFeatureModules();   // 2. Feature modules (incl. SharesRepositories.register)
  await registerUserDependencies(); // 3. Your own third-party SDKs / custom dependencies
  await getIt.allReady();
}
```

---

## 2. How Feature Modules Auto-Register

`fluzer new login` auto-adds a line in `injection_base.dart`'s `registerFeatureModules`:

```dart
@protected
Future<void> registerFeatureModules() async {
  // XxxModule.register(getIt);
  SharesRepositories.register(getIt);
  HomeModule.register(getIt);     // Generated for home
  CounterModule.register(getIt);  // Generated for counter
  SearchModule.register(getIt);   // Generated for search
  LoginModule.register(getIt);    // ← injected by fluzer new login
}
```

Each feature module's `<name>_module.dart` only registers its own **Repository** (not the BLoC):

```dart
class LoginModule {
  LoginModule._();
  static void register(GetIt getIt) {
    getIt.registerLazySingleton<LoginRepository>(
      () => LoginRepository(client: getIt<DioClient>()),
    );
  }
}
```

> **Important convention**: `DioClient`, `Repository`, `Service` are registered as `lazySingleton`; **BLoCs are not in DI**, but created by `BlocProvider` on the page (to avoid memory leaks from long-lived holding).

---

## 3. Cross-Module Shared Repositories

When multiple features share a piece of data, promote the repository to `core/data/repositories/` and register it in `core/data/shares_repositories.dart`:

```dart
abstract class SharesRepositories {
  static void register(GetIt getIt) {
    getIt.registerLazySingleton<UserRepository>(
      () => UserRepository(client: getIt<DioClient>()),
    );
  }
}
```

`SharesRepositories.register(getIt)` is already called inside `registerFeatureModules`, taking effect at startup alongside the feature modules. Features that need it import from `core` and fetch via `getIt<UserRepository>()`, and **do not** import another feature's directory (see "Cross-module data sharing" in [Architecture Overview](index.md)).

---

## 4. Consuming Dependencies on the Page

The page only creates the BLoC; the Repository the BLoC needs comes from DI:

```dart
BlocProvider(
  create: (_) => LoginBloc(repository: getIt<LoginRepository>()),
  child: const EffectListener<LoginBloc, LoginState>(
    effectsHandles: [loginEffectHandle],
    child: LoginBody(),
  ),
)
```

Notifiers / business handles also fetch services via `getIt` (e.g. `getIt<ToastService>()`).

---

## 5. Swapping Infrastructure Implementations

Dependency inversion: switching the underlying implementation **only changes the registration in `injection.dart`**; the caller's API stays the same. For example, on desktop switch to `ToastificationToastService`:

```dart
// injection.dart —— registerBaseDependencies / _registerNotifiersLayer
getIt.registerLazySingleton<ToastService>(ToastificationToastService.new);
```

Network-layer interceptors, storage implementations, and theme/i18n Provider swaps work the same way — all centralized in `injection.dart`. This is the point of the "hand-written region": a framework upgrade (changes to `injection_base.dart`) won't wipe out your dependency configuration.

---

## 6. Tips

- In tests, directly `getIt.reset()` then re-register mocks, or inject fake implementations into `getIt`.
- Want to preload at startup? `await` your init logic inside `registerUserDependencies`.
- Adding a third-party SDK: `registerUserDependencies` is the only extension point; keep `registerFeatureModules` for script maintenance.

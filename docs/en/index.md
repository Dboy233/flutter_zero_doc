# Flutter Zero Documentation

Flutter Zero is an **enterprise-grade Flutter MVI template**, built from three independent repositories working together:

| Repository | Role |
|------------|------|
| `flutter_zero_app` | Example app (a real project generated from the template, demonstrating the `home` / `counter` / `search` / `login` / `settings` modules) |
| `flutter_zero_cli` | Scaffolding CLI `fluzer` (create projects, generate feature modules, generate the type-safe localization access layer, manage the template cache, check for updates) |
| `flutter_zero_template` | Pure template source (Mason Brick); `fluzer` renders projects and module skeletons from it |

---

## Design Philosophy

The template is built around two main threads; every abstraction serves them:

1. **Unidirectional data flow (MVI)**: user action → `Event` (Intent) → `Bloc` (ViewModel) → `State` (ViewState) → `View` rendered as a pure function. State is the single source of rendering; the UI only ever reads state and emits intents.
2. **Side-effects separated from state**: one-shot UI behaviors such as Toast / Loading / dialogs travel through a dedicated `Effect` channel and **never pollute** `State` — no single-slot overwrites or duplicate deliveries.
3. **Error handling**: low-level `DioException` and other exceptions are wrapped by `runCatching` into `Result<T>` (success / failure / cancel); `Failure` carries the raw `Exception`, and the business layer only handles three explicit terminal states, without `try/catch` boilerplate.

---

## Batteries Included

| Building block | Location | What it solves |
|----------------|----------|----------------|
| Four BLoC Mixins | `core/bloc/` | awaitable events, automatic network cancellation, side-effect stream, unified error handling |
| Effect system | `core/effect/` | `ToastEffect` / `DialogEffect` / `LoadingEffect` + responsibility-chain handling |
| Notifiers system | `core/notifiers/` | show Toast / Loading without a `BuildContext` (bridges to `BuildContext`) |
| Error system | `core/result/` | `Result<T>` (Success / Failure / Cancel); `Failure` carries the raw `Exception` |
| `BaseRepository` | `core/network/` | holds `Dio` only; it does no response parsing and throws no framework exceptions — parsing and throwing are up to you |
| Three-file DI | `core/di/` | infrastructure registration, automatic module injection, swappable implementations |

---

## Documentation Navigation

- **[Getting Started](getting-started/)** — Install `fluzer`, create a project, generate a feature module, and build a complete feature end-to-end.
- **[Architecture](architecture/)**
  - [Overview & Layering](architecture/) — the three-repository relationship, directory structure, how MVI lands, unidirectional data flow, and layer boundaries.
  - [The Four BLoC Mixins](architecture/bloc-mixins.md) — usage of `BlocAwaitMixin` / `BlocCancelTokenMixin` / `BlocEffectMixin` / `BlocErrorHandlerMixin`.
  - [Effect & Notifiers](effect-system/index.md) — the one-shot side-effect channel and notification services.
  - [Error Handling & Result](architecture/error-handling.md) — exception handling, `Result<T>`, and the zero-wrapping principle.
  - [Dependency Injection](architecture/dependency-injection.md) — the `get_it` three-file convention and automatic module registration.
- **[CLI Reference](cli/)** — `fluzer` commands, directory structure, configuration, and debug environment variables.
- **Release & Versions** — [Version Constraint Rules](versioning-rules.md) / [Release Process](release.md) / [CLI Versioning](versioning-cli.md) / [Template Versioning](versioning-template.md).

!!! note "About the network layer"
    The network-request wrapper (`Dio`, interceptors) is a data-layer detail and is not covered in the main docs. On the business side you only care about the methods `Repository` exposes and the exception types it throws (any `Exception`).

<!-- source-footer -->

---

*Source of this page: [docs/en/index.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/index.md)*

*[Report an error on this page](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_en.md&title=%5BDocs%20error%5D%20docs%2Fen%2Findex.md)*

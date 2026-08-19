# CLI Versioning

This spec defines the version-number management rules for `flutter_zero_cli` (the `fluzer` tool), and the compatibility constraints with `flutter_zero_template` (the bricks template repository).

The CLI and the template are two independent version lines. Template/CLI compatibility is decided by each command's "version adapter" based on the project `version` range; the CLI no longer reads any `minCliVersion` to gate at runtime (that field has been removed from both the config and the registry).

## Semantic Versioning (SemVer)

Version format `MAJOR.MINOR.PATCH` (e.g. `1.0.0`).

## CLI Version Bump Rules

| Position | Trigger | Impact on template | Note |
|----------|---------|--------------------|------|
| **PATCH** `1.0.x` | CLI bug fix (e.g. http timeout not handled, codemod boundary error) | Transparent | Existing adapter still covers it |
| **MINOR** `1.x.0` | Backward-compatible **new** feature: new command, registry-pull support, new env var | Existing template loads as usual | Existing adapter still covers it |
| **MAJOR** `x.0.0` | **Breaking change**: start passing **new required variables** to the brick that the old template lacks, or rewrite codemod injection logic so old template anchors break | Old template may fail to generate | Need to push a new template or add a version-specific adapter |

## Template Cache

Cache and refresh rules of the template loader (`TemplateSourceResolver`, implemented in `lib/src/template/template_source.dart`):

> The cache directory is named by template version number first (`template_<version>`); on env-var override / fallback it degrades to a URL-hash name.
> Different versions in the template registry naturally hit different cache directories, so old-version caches are never misused and no manual cleanup is needed.
> To force a refresh, run `fluzer cache clean`.

> The template-source selection (`create` picks the largest `version`, `new` pins the exact `version`) and the version-adapter logic are unified in [Version Constraint Rules](versioning-rules.md).

## Version Adaptation (the minCliVersion gate has been removed)

Since 2.0.0 the `minCliVersion` field has been removed from the config and registry, and the CLI no longer gates on it. Template/CLI compatibility is instead decided by each command's **version adapter** based on the project `version` range:

- **`create` (CLI-driven)** does not validate versions. It simply picks the entry with the **largest `version`** from the template registry to download (always the latest template); if the registry fetch fails it **silently falls back** to the built-in `defaultTemplateZipUrl`, so a project can always be created.
- **`new` / `gen-l10n` (project-driven)** read the project's `fluzer.yaml` `version` and walk the command's adapter chain to pick a claimant; if the version is outside the adapter's supported range it **aborts and prompts the user to upgrade the CLI / upgrade the template**, avoiding generating broken code with an incompatible CLI.

> The full adapter-selection and boundary scenarios are in [Version Constraint Rules](versioning-rules.md).

## Compatibility Contract Watershed (CLI side)

To decide which position to bump, the key is whether you touched the **contract**:

1. **Mason variable contract**: if the CLI starts passing new required variables to the brick (beyond `name` + `package_name`), and the old template doesn't declare them → breaking → CLI MAJOR.
2. **Generated code structure contract**: `CodeMod` (`addImport` / `insertAtMethodEnd`) relies on generated code's class/method names for location. If the CLI rewrites injection logic and old template anchors break → CLI MAJOR.
3. **DI registration anchor**: a signature change in `registerFeatureModules()`'s injection region → CLI MAJOR.

> Rule of thumb: **only touch "content / internal implementation" → don't bump major; touch "contract / anchor" → must bump major and notify the template side to sync.**

## Release Process (CLI)

1. Modify the CLI code.
2. Bump the version per the table above (`pubspec.yaml`'s `version`).
3. If this is a **MAJOR affecting the template contract** → notify the template side to release the corresponding version (and cover its behavior differences with a version-specific adapter).
4. Release: `dart pub publish` or `dart pub global activate fluzer`.

## Related Documents

- Template version spec: see [Template Versioning](versioning-template.md).
- Three-version constraint relationship and command version adaptation: see [Version Constraint Rules](versioning-rules.md).

<!-- source-footer -->

---

*Source of this page: [docs/en/versioning-cli.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/versioning-cli.md)*

*[Report an error on this page](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_en.md&title=%5BDocs%20error%5D%20docs%2Fen%2Fversioning-cli.md)*

# CLI Versioning

This spec defines the version-number management rules for `flutter_zero_cli` (the `fluzer` tool), and the compatibility constraints with `flutter_zero_template` (the bricks template repository).

The CLI and the template are two independent version lines, bridged by the `minCliVersion` field in `template_registry.json`: the CLI reads this field at runtime to verify whether its own version satisfies the template's requirement.

## Semantic Versioning (SemVer)

Version format `MAJOR.MINOR.PATCH` (e.g. `1.0.0`).

## CLI Version Bump Rules

| Position | Trigger | Impact on template | Note |
|----------|---------|--------------------|------|
| **PATCH** `1.0.x` | CLI bug fix (e.g. http timeout not handled, codemod boundary error) | Transparent | Template `minCliVersion` still satisfied |
| **MINOR** `1.x.0` | Backward-compatible **new** feature: new command, registry-pull support, new env var | Existing template loads as usual | `minCliVersion` unchanged |
| **MAJOR** `x.0.0` | **Breaking change**: start passing **new required variables** to the brick that the old template lacks, or rewrite codemod injection logic so old template anchors break | Old template may fail to generate | Need to push a new template or make a compat branch |

## resolveBrickLoader Compatibility Logic

The CLI's template-source resolution flow at runtime (`lib/src/template/template_source.dart`):

1. `FLUZER_BRICKS_DIR` non-empty → local load (dev/debug).
2. Otherwise pull `template_registry.json` (hardcoded registry URL):
   - Success → read `url` and `minCliVersion`; if `own version < minCliVersion` → error prompting to upgrade.
   - Failure (offline / poor network) → fall back to the built-in `defaultTemplateZipUrl`.
3. Build `RemoteBrickLoader` from the resolved `url`.

> The cache directory is named by template version number first (`template_<version>`); on env-var override / fallback it degrades to a URL-hash name.
> Different versions in the registry naturally hit different cache directories, so old-version caches are never misused and no manual cleanup is needed.
> To force a refresh, run `fluzer cache clean`.

## minCliVersion Validation

- The CLI validates at startup whether its own version is ≥ the registry's `minCliVersion`.
- If not satisfied → abort and prompt the user to upgrade the CLI, avoiding generating bad code with an incompatible CLI.

## Compatibility Contract Watershed (CLI side)

To decide which position to bump, the key is whether you touched the **contract**:

1. **Mason variable contract**: if the CLI starts passing new required variables to the brick (beyond `name` + `package_name`), and the old template doesn't declare them → breaking → CLI MAJOR.
2. **Generated code structure contract**: `CodeMod` (`addImport` / `insertAtMethodEnd`) relies on generated code's class/method names for location. If the CLI rewrites injection logic and old template anchors break → CLI MAJOR.
3. **DI registration anchor**: a signature change in `registerFeatureModules()`'s injection region → CLI MAJOR.

> Rule of thumb: **only touch "content / internal implementation" → don't bump major; touch "contract / anchor" → must bump major and notify the template side to sync.**

## Release Process (CLI)

1. Modify the CLI code.
2. Bump the version per the table above (`pubspec.yaml`'s `version`).
3. If this is a **MAJOR affecting the template contract** → notify the template side to release the corresponding version and raise its `minCliVersion`.
4. Release: `dart pub publish` or `dart pub global activate fluzer`.

## Related Documents

- Template version spec: see [Template Versioning](versioning-template.md).

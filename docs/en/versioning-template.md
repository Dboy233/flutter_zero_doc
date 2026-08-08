# Template Versioning

This spec defines the version-number management rules for `flutter_zero_template` (the bricks template repository), and the compatibility constraints with `flutter_zero_cli` (the `fluzer` tool).

The template and the CLI are two independent version lines, bridged by the `minCliVersion` field in `template_registry.json`: "this template version requires CLI ≥ some version".

## Semantic Versioning (SemVer)

Version format `MAJOR.MINOR.PATCH` (e.g. `1.0.1`).

## Template Version Bump Rules

| Position | Trigger | Impact on CLI | minCliVersion |
|----------|---------|---------------|---------------|
| **PATCH** `1.0.x` | Fix bug, copy, layout error, comment; minor template-file fix. **No change to brick variable contract, no change to generated code structure** | Transparent; old CLI just pulls the new zip and uses it | unchanged |
| **MINOR** `1.x.0` | Backward-compatible **new** content: new optional brick, add an **optional variable with default** to a brick, new optional DI hook | Old CLI still usable (no impact if new content isn't triggered) | unchanged |
| **MAJOR** `x.0.0` | **Breaking change**: change/remove a brick's required variable, change generated code's class/method names (affects CLI codemod anchors), delete a brick | Old CLI pulls it then fails to generate | **must raise to new CLI version** |

## Compatibility Contract Watershed

To decide which position to bump, the key is whether you touched the **contract**:

1. **Mason variable contract**: the feature brick currently declares only `name` + `package_name`. As long as these two don't change → at most PATCH/MINOR.
2. **Generated code structure contract**: the CLI's `CodeMod` (`addImport` / `insertAtMethodEnd`) relies on class/method names as anchor points. If the template changes these names → breaks CLI injection → MAJOR.
3. **DI registration anchor**: a signature change in `registerFeatureModules()`'s auto-injection region → MAJOR.

> Rule of thumb: **only touch "content" → don't bump major; touch "contract / anchor" → must bump major and sync `minCliVersion`.**

## When to Update minCliVersion

- Template **PATCH / MINOR** → **usually don't touch** `minCliVersion`. When the template fixes a bug or adds a feature, the CLI needs zero changes; the old CLI automatically pulls the new zip.
- Exception: if the PATCH/MINOR change **introduces a new dependency on a higher CLI version** (e.g. adding a field consumed by the `fluzer new`/`gen-l10n` version gate — such as `minCliVersion` in `flutter_zero_config.yaml`, or docs/comments referencing a command that only exists in a newer CLI), you must **bump `minCliVersion` to that CLI version**. 1.0.1 is such a case: `default_toast_effect_handle.dart` references `fluzer gen-l10n` (introduced in CLI 1.1.0), so `minCliVersion` was raised to `1.1.0`.
- Template **MAJOR** → **bump** `minCliVersion` to the corresponding CLI version. When the old CLI runs and reads `minCliVersion > own version`, it clearly errors "please upgrade the CLI" instead of silently generating bad code.

## Release Process (Template)

1. Modify the template content.
2. Package: `zip -r bricks.zip bricks`.
3. Publish a GitHub Release (fixed version number, e.g. `v1.0.1`, **don't use `/latest`** to avoid 302 and cache traps).
4. Update `template_registry.json`:
   - `version` → new version number
   - `url` → the new Release's `bricks.zip` fixed link
   - `minCliVersion` → raise if this is MAJOR, or if PATCH/MINOR introduced a new CLI dependency (see above); otherwise keep
5. Push to `main`; `raw.githubusercontent.com/<owner>/<repo>/main/template_registry.json` takes effect immediately.
6. **The CLI does not need to release** (unless the new CLI capability required by `minCliVersion` is not yet published).

## Related Documents

- CLI version spec: see [CLI Versioning](versioning-cli.md).
- Three-version constraint relationship and command gating: see [Version Constraint Rules](versioning-rules.md).

<!-- source-footer -->

---

*Source of this page: [docs/en/versioning-template.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/versioning-template.md)*

# Template Versioning

This spec defines the version-number management rules for `flutter_zero_template` (the bricks template repository), and the compatibility constraints with `flutter_zero_cli` (the `fluzer` tool).

The template and the CLI are two independent version lines. Template/CLI compatibility is decided by each command's "version adapter" based on the project `version` range (the `minCliVersion` field has been removed).

## Semantic Versioning (SemVer)

Version format `MAJOR.MINOR.PATCH` (e.g. `1.0.1`).

## Template Version Bump Rules

| Position | Trigger | Impact on CLI | Version adapter |
|----------|---------|---------------|---------------|
| **PATCH** `1.0.x` | Fix bug, copy, layout error, comment; minor template-file fix. **No change to brick variable contract, no change to generated code structure** | Transparent; old CLI just pulls the new zip and uses it | unchanged (existing adapter covers it) |
| **MINOR** `1.x.0` | Backward-compatible **new** content: new optional brick, add an **optional variable with default** to a brick, new optional DI hook | Old CLI still usable (no impact if new content isn't triggered) | unchanged (existing adapter covers it) |
| **MAJOR** `x.0.0` | **Breaking change**: change/remove a brick's required variable, change generated code's class/method names (affects CLI codemod anchors), delete a brick | Old CLI pulls it then fails to generate | **add a version-specific adapter** |

## Compatibility Contract Watershed

To decide which position to bump, the key is whether you touched the **contract**:

1. **Mason variable contract**: the feature brick currently declares only `name` + `package_name`. As long as these two don't change → at most PATCH/MINOR.
2. **Generated code structure contract**: the CLI's `CodeMod` (`addImport` / `insertAtMethodEnd`) relies on class/method names as anchor points. If the template changes these names → breaks CLI injection → MAJOR.
3. **DI registration anchor**: a signature change in `registerFeatureModules()`'s auto-injection region → MAJOR.

> Rule of thumb: **only touch "content" → don't bump major; touch "contract / anchor" → must bump major and add a version-specific adapter for the new template version.**

## When to Add a Version Adapter

- Template **PATCH / MINOR** → **usually no new adapter needed**. When the template fixes a bug or adds a feature, the CLI needs zero changes; the old CLI automatically pulls the new zip, and the existing adapter covers it.
- Template **MAJOR** → if the change introduces a **behavioral difference** in `new`/`gen-l10n` execution flow (e.g. DI injection anchor change, directory structure adjustment), add an adapter covering that version range to the command's adapter chain. When the old CLI encounters a version outside the adapter range, it clearly errors "please upgrade the CLI" instead of silently generating bad code.

> Since 2.0.0 the `minCliVersion` gate is no longer used. Historical versions (e.g. 1.0.1 once raised `minCliVersion` to `1.1.0` because it referenced `fluzer gen-l10n`) are still handled correctly by the existing adapters.

## Release Process (Template)

1. Modify the template content.
2. Package: `zip -r bricks.zip bricks`.
3. Publish a GitHub Release (fixed version number, e.g. `v1.0.1`, **don't use `/latest`** to avoid 302 and cache traps).
4. Update `template_registry.json`:
   - `version` → new version number
   - `url` → the new Release's `bricks.zip` fixed link
   - (the `minCliVersion` field has been removed; the registry only needs `version` + `url`)
5. Push to `main`; `raw.githubusercontent.com/<owner>/<repo>/main/template_registry.json` takes effect immediately.
6. **The CLI does not need to release** (unless the MAJOR's behavioral difference requires a new version adapter on the CLI side).

## Related Documents

- CLI version spec: see [CLI Versioning](versioning-cli.md).
- Three-version constraint relationship and command version adaptation: see [Version Constraint Rules](versioning-rules.md).

<!-- source-footer -->

---

*Source of this page: [docs/en/versioning-template.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/versioning-template.md)*

*[Report an error on this page](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_en.md&title=%5BDocs%20error%5D%20docs%2Fen%2Fversioning-template.md)*

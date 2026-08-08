# Release Process (RELEASE)

> This document describes the development, verification, and release process for the three `flutter_zero` repositories
> (`flutter_zero_app` / `flutter_zero_cli` / `flutter_zero_template`).
>
> **Core principle: the template and CLI are released decoupled.** The template can release independently and frequently; the CLI usually does not need to follow.
> The two are connected through the compatibility-bucket mechanism in `template_registry.json`.

---

## 0. Prerequisites

| Topic | Document |
|-------|----------|
| Three-repository responsibilities & architecture | [Architecture Overview](architecture/index.md) |
| Template version rules (SemVer bump) | [Template Versioning](versioning-template.md) |
| CLI version rules & compatibility logic | [CLI Versioning](versioning-cli.md) |
| Template distribution mechanism (registry) | `flutter_zero_template/template_registry.json` |

**Version rules in one line**:

- **PATCH (0.0.x)** = bug fix / minor content fix, no contract change → CLI does nothing
- **MINOR (0.x.0)** = backward-compatible addition (optional variable with default, optional brick) → CLI does nothing
- **MAJOR (x.0.0)** = breaking change (change brick variable contract / generated code structure / DI anchor) → must bump `minCliVersion`

---

## 1. Overall Flow

```
Phase A: Template development & verification (app → template → local verification)
Phase B: CLI adjustments (as needed)
Phase C: Release (decoupled) — the template can almost always move without the CLI
```

> ⚠️ **Key correction**: releasing the template ≠ the CLI must release. When the template is PATCH/MINOR, the CLI does not need to release at all,
> because `template_registry.json` will automatically point to the new template, and old CLI runs will automatically pull the latest compatible version.

---

## Phase A: Template Development & Verification

### A1. Verify architecture & template in `flutter_zero_app`

Implement / verify business, architecture, and template structure. `flutter_zero_app` is the template's **verification project** and the input source for the sync script.

### A2. Sync template to `flutter_zero_template`

Use the sync script to sync the app into `bricks/`:
```bash
cd flutter_zero_template
dart run scripts/sync_project_brick.dart
```
The script copies + content-replaces (`flutter_zero_app` → `{{name}}`) + renames + overwrites files (see the variable config inside the script).

### A3. Verify brick generation locally with mason

Make sure both bricks render correctly (requires global mason install: `dart pub global activate mason_cli`):
```bash
# enter the template directory
cd flutter_zero_template

# (optional) initialize the directory
mason init

# add the brick to local mason run
mason add feature --path brick/feature

# verify the feature template generation
mason make feature --name demo --package_name demo
```
The above command generates a directory in the current directory (flutter_zero_template); check whether the content is correct.

### A4. End-to-end verification with CLI local mode

Load the template locally via env var so it touches no network:
```bash
cd flutter_zero_cli
FLUZER_BRICKS_DIR=../flutter_zero_template/bricks dart run bin/fluzer.dart new demo
FLUZER_BRICKS_DIR=../flutter_zero_template/bricks dart run bin/fluzer.dart create demo_app
```

---

## Phase B: CLI Adjustments (as needed)

### B1. Modify `flutter_zero_cli`

When the template's **variable contract** or **codemod anchor** (class name / method name / DI injection region) changes, adjust the CLI code.

### B2. Verify

```bash
cd flutter_zero_cli
dart analyze
dart test
```
Must be **0 issues + all green** before release.

---

## Phase C: Release (decoupled)

### C1. Release the template (core step, usually independent of the CLI)

1. **Decide the bump**: per [Template Versioning](versioning-template.md) decide PATCH / MINOR / MAJOR.
2. **Package**:
   ```bash
   cd flutter_zero_template
   zip -r bricks.zip bricks     # top level is directly bricks/...
   ```
3. **Publish a GitHub Release** (**fixed version URL**, not a `/latest` redirect link):
   ```bash
   gh release create v1.0.1 bricks.zip --title "Templates v1.0.1"
   # yields the fixed link:
   # https://github.com/OWNER/REPO/releases/download/v1.0.1/bricks.zip
   ```
4. **Update `template_registry.json`** (compatibility-bucket rules):
   - **PATCH / MINOR** → only update the `version` + `url` of the current `minCliVersion` bucket entry (no new entry)
   - **MAJOR** → add a new entry (new `minCliVersion`), keep the old entry
5. **Push to main** (ensure the raw URL stays stably reachable):
   ```bash
   git add template_registry.json && git commit -m "chore: update template registry to v1.0.1" && git push
   ```

> ✅ At this point, old CLI users will automatically pull the new template on their next run, **with no CLI changes needed**.

### C2. Decide whether the CLI needs to release

| Scenario | Does the CLI release? |
|----------|------------------------|
| Template PATCH / MINOR | **No** (registry already points to the new template) |
| Template MAJOR (requires higher `minCliVersion`) | Release if the CLI injection logic needs to change; otherwise only the registry constraint takes effect |
| CLI itself has changes / bug fixes / new features | Release |

### C3. Release the CLI (only when C2 decides it's needed)

1. Update the `cliVersion` constant in `lib/src/config/template_config.dart` (**must stay in sync with `pubspec.yaml`**).
2. If the template is MAJOR, confirm `TemplateSourceResolver.resolve()`'s `minCliVersion` validation is compatible.
3. Re-run `dart analyze` + `dart test`.
4. Publish:
   ```bash
   cd flutter_zero_cli
   dart pub publish
   ```

### C4. Post-release verification

- **Version prompt**: `fluzer version` should show the new-version prompt (after the CLI is published to pub.dev).
- **Real pull**: via the real registry (the Release link `template_registry.json` points to), verify `fluzer new` end-to-end pulls the new template and generates correctly.

---

## 2. Pre-release Checklist

**Before releasing the template**

- [ ] Decide the bump type per [Template Versioning](versioning-template.md)
- [ ] `bricks.zip` packaged, top level is `bricks/`
- [ ] GitHub Release uses a **fixed version URL** (not `/latest`)
- [ ] `template_registry.json` updated (PATCH/MINOR changes the bucket entry, MAJOR adds an entry)
- [ ] `template_registry.json` pushed to main

**Before releasing the CLI**

- [ ] `cliVersion` constant matches the `pubspec.yaml` version
- [ ] `dart analyze` 0 issues
- [ ] `dart test` all green
- [ ] Placeholder URLs replaced with real addresses (see appendix 3.1)
- [ ] `CHANGELOG.md` and `CHANGELOG_CN.md` both have the new entry at the top, with matching content
- [ ] `dart pub publish --dry-run` passes (no missing-dependency or similar errors)
- [ ] If i18n strings changed, `dart run slang` has been run to regenerate `strings*.g.dart`
- [ ] `intl` is explicitly declared in `pubspec.yaml` `dependencies` (slang's pure-Dart output still does `import 'package:intl/intl.dart'`)
- [ ] `dart pub publish` succeeds

---

## 3. Appendix

### 3.1 Placeholders to replace (required before release)

Location: `flutter_zero_cli/lib/src/config/template_config.dart`

- `templateRegistryUrl` → real raw URL
  `https://raw.githubusercontent.com/OWNER/REPO/main/template_registry.json`
- `defaultTemplateZipUrl` → real Release **fixed-version** URL (fallback when pull fails)
- `cliVersion` → in sync with `pubspec.yaml` (must change on every CLI release)

> ⚠️ **Never modify `minimumSupportedVersion`**: this constant is the "oldest template version the CLI accepts",
> unrelated to the CLI's own version (`cliVersion`). Bumping it to the CLI version would wrongly reject valid
> older templates such as `1.0.x` and break the gate. It must stay at `1.0.0`.

### 3.2 Command Quick Reference

| Purpose | Command |
|---------|---------|
| Sync template | `cd flutter_zero_template && dart run scripts/sync_project_brick.dart` |
| Verify brick locally | `mason make feature --name demo --package_name demo` |
| CLI load template locally | `FLUZER_BRICKS_DIR=../flutter_zero_template/bricks dart run bin/fluzer.dart new demo` |
| CLI check version update | `fluzer version` (use the global command after release) |
| Release template | `zip -r bricks.zip bricks` + `gh release create vX.Y.Z bricks.zip` + update registry + push |
| Release CLI | `dart pub publish` |

---

> Doc maintenance: this process evolves with release practice. If you find a step that doesn't match reality, prioritize updating this document and the two `versioning-xxx.md` files.

<!-- source-footer -->

---

*Source of this page: [docs/en/release.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/en/release.md)*

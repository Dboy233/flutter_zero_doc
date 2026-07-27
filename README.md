# flutter_zero_doc

> 🌐 [简体中文](README_CN.md) | English

The **central documentation repository** for the Flutter Zero project (documentation only, hosted via GitHub Pages).

- Documentation site: [Flutter Zero Docs](https://dboy233.github.io/flutter_zero_doc/)
- Source repositories:
  - `flutter_zero_app` — Example application (real-world project sample built from the template)
  - `flutter_zero_cli` — Scaffolding tool `fluzer`
  - `flutter_zero_template` — Pure template source (Mason Brick)

## Local Preview

```bash
pip install mkdocs-material mkdocs-static-i18n
mkdocs serve
```

## Directory Structure

```
flutter_zero_doc/
├── mkdocs.yml                 # Site config (nav / theme / i18n plugin)
├── .github/workflows/
│   └── deploy.yml             # Auto-deploy to GitHub Pages on push to main
├── docs/
│   ├── zh/                    # Chinese docs (default language → site root /)
│   │   ├── index.md           # Home / overview
│   │   ├── architecture/      # Architecture docs
│   │   ├── getting-started/   # Quick start
│   │   ├── effect-system/     # Effect system + Notifiers design
│   │   ├── cli/README.md      # CLI reference
│   │   ├── release.md         # Release process
│   │   └── versioning-*.md     # Versioning rules
│   ├── en/                    # English docs (→ /en/), mirrors zh structure
│   ├── images/                # Shared image assets (used by both languages)
│   ├── stylesheets/           # Shared CSS
│   └── javascripts/           # Shared JS
└── LICENSE
```

### Adding / Modifying Documentation

- Edit Chinese content under `docs/zh/` and the corresponding English under `docs/en/` (structure and filenames must mirror `zh`).
- Shared resources (images, CSS, JS) go in the respective folders under `docs/` root; both languages reference them via relative paths.
- Navigation menu (`nav`) title translations are maintained in `mkdocs.yml` under `plugins.i18n.languages[en].nav_translations`.
- After adding or removing pages, sync the `nav` section in `mkdocs.yml`.

# Wasfati

Save recipes from TikTok, Instagram, YouTube and any website as clean Arabic recipes, then cook, plan meals and shop from one list.

**Principles:** Arabic first (right-to-left, Arabic units and numerals); no account in v1, and recipes leave the device only through a backup the user chooses to make; only what the user sends for an AI import (a post link, caption or photo) goes to our import server, which neither keeps it nor sells it; ads never appear in cook mode, the recipe editor or the import review; honest paying: store prices, two-tap cancel, a reminder before any trial charges, and nothing that already works moves behind a payment.

## Getting started

```bash
flutter pub get > $null
flutter run
```

## Docs

- [Roadmap](docs/ROADMAP.md): phases and what's done
- [Product rules](docs/PRODUCT_RULES.md): how the app behaves, with rule IDs
- [Releasing](docs/RELEASING.md): versions, signing, stores
- [Privacy policy](https://oasis-forge.github.io/wasfati/privacy-policy)
- [Changelog](CHANGELOG.md)

## Development

Built with Claude Code. `CLAUDE.md` holds the conventions. The project skills are `/spec` (rules before code), `/verify` (checks), `/release` (version bump), `/ship` (pre-merge gate), and `/handoff` (session notes). Every PR merged to `main` is a release.

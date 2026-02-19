---
doc_type: docs_home
product_name: AwakeBar
version: 1.3.0
status: active
owners:
  - dshakiba
last_reviewed: 2026-02-19
---

# AwakeBar Documentation

This directory follows a Markdown-only specification system.

- `FEATURES.md` is the source of truth for feature IDs, names, status, and hierarchy.
- `features/` contains per-feature implementation and acceptance specs, including dotted child IDs (`F-xxx.yy`) for setup, transport, persistence, and recovery behaviors.
- `PRODUCT_MAP.md` is a rendered hierarchy from `FEATURES.md`.
- `MASTER_SPEC.md` captures product-level vision, constraints, and release scope.
- `DECISIONS/` records architecture decisions (ADRs) tied to feature IDs.
- `templates/FEATURE_TEMPLATE.md` is the scaffold for new feature specs.

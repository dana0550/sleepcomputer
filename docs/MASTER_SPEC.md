---
doc_type: master_spec
product_name: AwakeBar
version: 1.0.0
status: active
owners:
  - dshakiba
last_reviewed: 2026-02-17
sources_of_truth:
  features_index: ./FEATURES.md
  product_map: ./PRODUCT_MAP.md
---

# Master Spec

## Product Vision

AwakeBar provides a minimal, menu bar-first experience for quickly controlling macOS awake behavior.

## Release Scope (v1)

- Lightweight menu bar app with no Dock icon.
- Open-lid keep-awake mode via IOKit assertions.
- Closed-lid mode via privileged `pmset` toggles.
- Startup restore of safe settings and launch-at-login toggle.
- SVG-driven iconography pipeline.

## Constraints

- No credential storage.
- Minimal memory and CPU footprint during idle operation.
- Native macOS interaction patterns.

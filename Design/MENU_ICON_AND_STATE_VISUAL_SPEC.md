# AwakeBar Menu Icon and State Visual Spec (v3)

Date: 2026-02-18
Owner: AwakeBar product/engineering
Applies to: menu bar status icon and simplified OFF/Full Awake state model

## 1) Objective

AwakeBar now uses a simplified two-state model:
- OFF
- Full Awake (ON)

Design goal is instant recognition at menu bar size with no ambiguous intermediate icon set.

## 2) Required Deliverables

Designer delivers updated source SVGs in this folder:
- `/Users/dshakiba/sleepcomputer/Design/icons/awakebar-off.svg`
- `/Users/dshakiba/sleepcomputer/Design/icons/awakebar-closed.svg`

Do not rename files. The generation pipeline depends on these exact names.

## 3) Menu Bar Icon Geometry Spec

Both SVGs must follow this exactly:
- Canvas: `20x20`.
- Live drawing area: centered `19x19` (max `0.5px` inset on any side).
- Optical occupancy target: `>= 88%` of the 20x20 area.
- Stroke range: `2.0` to `2.6`.
- No micro-details smaller than `2px` at 1x render.
- Monochrome template style (`currentColor`), transparent background.
- Pixel alignment: snap key endpoints to 0.5 px or whole px to avoid blur.

## 4) State Semantics by Icon

- `awakebar-off.svg`:
  - OFF state.
  - Closed-eye glyph.
  - Must read as inactive even at very small size.

- `awakebar-closed.svg`:
  - Full Awake ON state.
  - Open-eye + lock glyph.
  - Lock must remain legible at 1x; keep lock form simple and chunky.

## 5) UI State Indicators (Implemented in Code)

- Menu bar glyph:
  - OFF uses `AwakeBarStatusOff`.
  - ON uses `AwakeBarStatusClosed`.
- Menu status dot:
  - OFF is neutral gray.
  - ON is explicit blue `#0A84FF`.
- Toggle:
  - Label is `Full Awake`.
  - Switch tint is blue when ON.

## 6) Handoff Validation Checklist

Designer must verify before handoff:
- In a 20x20 artboard, each icon uses near-full live area (19x19 target).
- At 100% and 200% zoom, strokes remain crisp and not muddy.
- At simulated 18x18 and 16x16 raster preview, OFF and ON remain clearly distinct.
- No decorative marks that disappear at small size.
- Lock in `awakebar-closed.svg` remains clear at 1x.

## 7) Engineering Regeneration Step

After SVG drop-in, run:

```bash
cd /Users/dshakiba/sleepcomputer
./Scripts/build-icons.sh
```

This regenerates:
- `/Users/dshakiba/sleepcomputer/AwakeBar/Assets.xcassets/AwakeBarStatusOff.imageset/AwakeBarStatusOff.svg`
- `/Users/dshakiba/sleepcomputer/AwakeBar/Assets.xcassets/AwakeBarStatusClosed.imageset/AwakeBarStatusClosed.svg`

## 8) Removed Legacy Asset

The legacy open-eye icon is intentionally removed from runtime and pipeline:
- `Design/icons/awakebar-open.svg`
- `AwakeBar/Assets.xcassets/AwakeBarStatusOpen.imageset/*`

## 9) Non-Goals

- No changes to app icon (`AppIcon.appiconset`) in this pass.
- No multi-color menu bar status icons.
- No filename changes for retained assets.

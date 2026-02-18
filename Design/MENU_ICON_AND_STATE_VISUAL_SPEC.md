# AwakeBar Menu Icon and ON-State Visual Spec (v2)

Date: 2026-02-18
Owner: AwakeBar product/engineering
Applies to: menu bar status icon and menu row ON/OFF icon states

## 1) Objective

The current menu bar icon still reads too small. We need a larger optical footprint and stronger state legibility.

Design goals:
- Menu bar icon should feel comparable in visual size to adjacent menu bar apps.
- OFF and ON states must be distinguishable instantly by shape and color.
- ON states in menu rows must use an explicit blue circle indicator, similar to Apple list rows.

## 2) Required Deliverables

Designer delivers updated source SVGs in this folder:
- `/Users/dshakiba/sleepcomputer/Design/icons/awakebar-off.svg`
- `/Users/dshakiba/sleepcomputer/Design/icons/awakebar-open.svg`
- `/Users/dshakiba/sleepcomputer/Design/icons/awakebar-closed.svg`

Do not rename files. The build pipeline depends on these exact names.

## 3) Menu Bar Icon Geometry Spec

All three SVGs must follow this exactly:
- Canvas: `20x20`.
- Live drawing area: centered `19x19` (max `0.5px` inset on any side).
- Optical occupancy target: `>= 88%` of the 20x20 area.
- Stroke range: `2.0` to `2.6`.
- No micro-details smaller than `2px` at 1x render.
- Monochrome template style (`currentColor`), transparent background.
- Pixel alignment: snap key endpoints to 0.5 px or whole px to avoid blur.

## 4) State Semantics by Icon

- `awakebar-off.svg`:
  - Closed-eye OFF state.
  - Must read as inactive even at very small size.
  - Avoid eyelashes or thin decorative details.

- `awakebar-open.svg`:
  - Open-eye ON state for lid-open mode.
  - Center feature should be bold and filled (not thin-line only).

- `awakebar-closed.svg`:
  - Open-eye + lock ON state for lid-closed/external mode.
  - Lock must stay legible at 1x; keep lock form simple and chunky.

## 5) Menu Row ON/OFF Visual Rules

These are product behavior requirements the icons must support:
- OFF rows use `awakebar-off.svg`.
- ON rows use mode icon (`awakebar-open.svg` or `awakebar-closed.svg`).
- ON icon container is an explicit blue circle: `#0A84FF`.
- ON icon color is white inside the blue circle.
- OFF icon container is neutral gray.
- OFF icon color is secondary tint.

## 6) ON-State Circle Dimensions (Implemented in UI)

These UI values are now in code and should be respected in previews:
- Circle size: `26x26`.
- ON circle fill: `#0A84FF`.
- Asset icon size inside circle: `14x14`.
- System symbol size inside circle: `11pt semibold`.

## 7) Handoff Validation Checklist

Designer must verify before handoff:
- In a 20x20 artboard, each icon uses near-full live area (19x19 target).
- At 100% and 200% zoom, strokes remain crisp and not muddy.
- At simulated 18x18 and 16x16 raster preview, OFF/OPEN/CLOSED remain distinct.
- No tiny eyelashes, highlights, or decorative marks that disappear at small size.
- Lock in `awakebar-closed.svg` remains clear at 1x.

## 8) Engineering Regeneration Step

After SVG drop-in, run:

```bash
cd /Users/dshakiba/sleepcomputer
./Scripts/build-icons.sh
```

This regenerates:
- `/Users/dshakiba/sleepcomputer/AwakeBar/Assets.xcassets/AwakeBarStatusOff.imageset/AwakeBarStatusOff.svg`
- `/Users/dshakiba/sleepcomputer/AwakeBar/Assets.xcassets/AwakeBarStatusOpen.imageset/AwakeBarStatusOpen.svg`
- `/Users/dshakiba/sleepcomputer/AwakeBar/Assets.xcassets/AwakeBarStatusClosed.imageset/AwakeBarStatusClosed.svg`

## 9) Non-Goals

- No changes to app icon (`AppIcon.appiconset`) in this pass.
- No multi-color menu bar status icons.
- No filename or asset ID changes.

# AwakeBar

AwakeBar is a lightweight macOS menu bar utility for controlling sleep behavior with two simple modes:

- **Full Caffeine**: keeps the Mac awake while the lid is open (no admin prompt).
- **Closed-Lid Mode (Admin)**: toggles system sleep disable via `pmset` with native administrator authentication.

## Requirements

- macOS 14.0+
- Xcode 26.2+
- Swift 6

## Project Layout

- `AwakeBar/`: app source code.
- `AwakeBarTests/`: unit and integration-style tests with mocks.
- `Design/icons/`: source-of-truth SVG icon files.
- `Scripts/build-icons.sh`: SVG -> PDF asset pipeline.
- `docs/`: product and feature specification system (`FEATURES.md` is SSOT).

## Build

```bash
xcodegen generate
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -destination 'platform=macOS' build
```

## Test

```bash
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -destination 'platform=macOS' test
```

## Notes

- Closed-lid mode uses privileged commands and can increase thermals/power use.
- AwakeBar intentionally does not store any admin credentials.

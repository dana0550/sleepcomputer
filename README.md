<div align="center">
  <img src="AwakeBar/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png" width="96" alt="AwakeBar app icon" />
  <h1>AwakeBar</h1>
  <p><strong>Minimal macOS menu bar control for sleep behavior</strong></p>
  <p>Fast toggles. Clear states. No credential storage.</p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift 6.0" />
    <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT License" />
  </p>
  <p>
    <a href="#install-and-run-release">Install</a> •
    <a href="#what-each-mode-does">Modes</a> •
    <a href="#menu-controls">Menu</a> •
    <a href="#asset-handoff-for-designers">Designer Handoff</a>
  </p>
</div>

## Overview

AwakeBar is a menu bar utility for controlling when your Mac sleeps.

It provides two modes:

- `Full Caffeine`: keeps your Mac awake while the lid is open.
- `Closed-Lid Mode (Admin)`: toggles system-wide sleep disable with native macOS admin authentication.

## Visual Identity

| App Icon | Off | Open-Lid Active | Closed-Lid Active |
|---|---|---|---|
| <img src="AwakeBar/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png" width="64" alt="App icon" /> | <img src="Design/icons/awakebar-off.svg" width="22" alt="Off icon" /> | <img src="Design/icons/awakebar-open.svg" width="22" alt="Open icon" /> | <img src="Design/icons/awakebar-closed.svg" width="22" alt="Closed icon" /> |

## What Each Mode Does

| Mode | Behavior | Admin Prompt | Best For |
|---|---|---|---|
| `Full Caffeine` | Prevents idle system sleep + display sleep while the Mac is open | No | Builds, long tasks, remote sessions while working |
| `Closed-Lid Mode (Admin)` | Runs `pmset -a disablesleep 1` (and `0` when disabled) | Yes | Intentional closed-lid operation when you understand thermal/power impact |

## Menu Controls

- `Status`: shows `Off`, `Open-Lid Active`, `Closed-Lid Active`, or `External Closed-Lid Active`.
- `Full Caffeine`: non-privileged keep-awake toggle.
- `Closed-Lid Mode (Admin)`: privileged closed-lid toggle.
- `Start automatically at login`: login item registration toggle.
- `Turn Everything Off`: disables all active modes.
- `Quit`: exits the app.

Hover any control to view quick inline help text.

## Safety

- `Closed-Lid Mode (Admin)` can increase thermals and battery drain.
- AwakeBar does not save or cache admin credentials.
- If sleep disable was turned on outside AwakeBar, startup displays `External Closed-Lid Active`.

## Requirements

- macOS 14.0+
- Xcode 26.2+
- Swift 6
- `xcodegen` (`brew install xcodegen`)

## Install and Run (Release)

```bash
cd /Users/dshakiba/sleepcomputer
xcodegen generate
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -configuration Release -destination 'platform=macOS' build
APP_PATH="$(xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -configuration Release -showBuildSettings | awk '/TARGET_BUILD_DIR =/{dir=$3} /FULL_PRODUCT_NAME =/{name=$3} END{print dir"/"name}')"
rm -rf /Applications/AwakeBar.app
ditto "$APP_PATH" /Applications/AwakeBar.app
open /Applications/AwakeBar.app
```

## Developer Workflow

```bash
# Generate project
xcodegen generate

# Build debug
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -destination 'platform=macOS' build

# Run tests
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -destination 'platform=macOS' test
```

## Project Layout

```text
AwakeBar/
  App/          # app entry + menu controller
  Domain/       # state + mode mapping
  Services/     # pmset, assertions, login, auth runner
  State/        # persistence
  UI/           # menu UI
AwakeBarTests/  # tests with mocks
Design/icons/   # menu icon source SVGs
docs/           # product spec system (FEATURES.md SSOT)
```

## Asset Handoff for Designers

Use these files for icon delivery requirements:

- `Design/ICON_ASSET_SPECS.csv`
- `Design/MENU_COPY.csv`

After new SVG icon drop-ins:

```bash
./Scripts/build-icons.sh
```

## Documentation System

This repo uses a spec workflow with `docs/FEATURES.md` as source of truth.

- Update `docs/FEATURES.md` first.
- Then update `docs/features/*.md`.
- Keep `docs/PRODUCT_MAP.md` in sync.

## License

MIT (`LICENSE`).

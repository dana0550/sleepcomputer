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

- `Keep Awake (Lid Open)`: keeps your Mac and display awake while the lid stays open.
- `Keep Awake (Lid Closed)`: disables system sleep so your Mac can keep running with the lid closed.

## Visual Identity

Current icon pack: `HERMES Green` (20x20 menu SVGs + refreshed full-color app icon set).

| App Icon | Normal Sleep | Stay Awake (Lid Open) | Stay Awake (Lid Closed) |
|---|---|---|---|
| <img src="AwakeBar/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png" width="64" alt="App icon" /> | <img src="Design/icons/awakebar-off.svg" width="22" alt="Off icon" /> | <img src="Design/icons/awakebar-open.svg" width="22" alt="Open icon" /> | <img src="Design/icons/awakebar-closed.svg" width="22" alt="Closed icon" /> |

## What Each Mode Does

| Mode | Behavior | Admin Prompt | Best For |
|---|---|---|---|
| `Keep Awake (Lid Open)` | Prevents idle system sleep + display sleep while the Mac is open | No | Builds, long tasks, remote sessions while working |
| `Keep Awake (Lid Closed)` | Calls a privileged helper daemon to run `pmset -a disablesleep 1` (and `0` when disabled) | One-time helper setup + approval in System Settings | Closed-lid operation when you understand thermal/power impact |

## Menu Controls

- `Status`: shows `Normal Sleep`, `Stay Awake (Lid Open)`, `Stay Awake (Lid Closed)`, or `Stay Awake (External)`.
- `Keep Awake (Lid Open)`: button to toggle non-privileged keep-awake.
- `Keep Awake (Lid Closed)`: button to toggle privileged closed-lid keep-awake (enabled only after setup).
- `Start at Login`: button to toggle login item registration.
- `Turn Everything Off`: disables all active modes.
- `Quit AwakeBar`: exits the app.

Hover any control to view quick inline help text.

## Closed-Lid Setup

Closed-lid control requires privileged helper registration.

1. Install `AwakeBar.app` in `/Applications`.
2. Open AwakeBar and click `Enable Closed-Lid Control`.
3. If prompted, open `Login Items` settings and approve the helper.
4. Return to AwakeBar; status should show `Closed-Lid Control Ready`.

Architecture details:

- Helper registration uses `SMAppService.daemon(plistName:)`.
- Runtime control uses XPC (`com.dshakiba.AwakeBar.PrivilegedHelper`) with code-signing requirements in both directions.
- Runtime does not use `sudo`, AppleScript, or Touch ID/PAM mutation fallbacks.

## Safety

- `Keep Awake (Lid Closed)` can increase thermals and battery drain.
- AwakeBar does not save or cache admin credentials.
- Closed-lid mode uses a scoped privileged helper with a fixed command surface.
- Legacy `sudoers`/PAM artifacts from prior versions are backed up and cleaned once helper setup is healthy.
- If sleep disable was turned on outside AwakeBar, startup displays `Stay Awake (External)`.

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

## Signed/Notarized Release

- CI workflow: `.github/workflows/release-macos.yml` (tag push `v*`).
- Local parity script: `Scripts/release-notarize.sh`.

Required environment variables/secrets:

- `APPLE_TEAM_ID`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_API_KEY_P8_BASE64`
- `DEVELOPER_ID_APP_CERT_P12_BASE64`
- `DEVELOPER_ID_APP_CERT_PASSWORD`
- `KEYCHAIN_PASSWORD`

Release scripts set `AWAKEBAR_TEAM_ID` from `APPLE_TEAM_ID` so XPC code-sign checks bind both bundle ID and team ID in production builds.

## Project Layout

```text
AwakeBar/
  App/          # app entry + menu controller
  Domain/       # state + mode mapping
  Services/     # setup controller, helper client, assertions, login
  State/        # persistence
  UI/           # menu UI
AwakeBarPrivilegedHelper/      # privileged daemon executable
AwakeBarPrivilegedHelperTests/ # helper tests
AwakeBarShared/                # shared XPC protocol/constants
AwakeBarTests/  # tests with mocks
Design/icons/   # menu icon source SVGs
docs/           # product spec system (FEATURES.md SSOT)
```

## Asset Handoff for Designers

Use these files for icon delivery requirements:

- `Design/ICON_ASSET_SPECS.csv`
- `Design/ICON_MANIFEST.json`
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

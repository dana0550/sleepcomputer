# AwakeBar

Lightweight macOS menu bar control for sleep behavior.

AwakeBar gives you one-click control over two modes:

- `Full Caffeine`: keep the Mac awake while the lid is open.
- `Closed-Lid Mode (Admin)`: toggle system-wide sleep disable (`pmset`) with native macOS admin authentication.

## Why This Exists

Built for people who need a fast, no-noise way to keep a Mac awake for long jobs, remote sessions, uploads, or demos, without digging through terminal commands every time.

## At a Glance

| Mode | What it does | Admin prompt | Typical use |
|---|---|---|---|
| `Full Caffeine` | Prevents idle system sleep and display sleep while the Mac is open | No | Active desk work, builds, long local tasks |
| `Closed-Lid Mode (Admin)` | Sets `pmset -a disablesleep 1` (and `0` when disabled) | Yes | Clamshell/closed-lid workflows where you intentionally override default sleep behavior |

## Menu Controls

- `Status`: current power mode (`Off`, `Open-Lid Active`, `Closed-Lid Active`, `External Closed-Lid Active`).
- `Full Caffeine`: toggle non-privileged keep-awake behavior.
- `Closed-Lid Mode (Admin)`: toggle privileged closed-lid behavior.
- `Start automatically at login`: register/unregister as login item.
- `Turn Everything Off`: disable both modes in one action.
- `Quit`: close the app.

Tip: hover controls in the menu for inline explanations.

## Safety Notes

- `Closed-Lid Mode (Admin)` changes system sleep policy and can increase thermals and battery drain.
- AwakeBar does **not** store your admin password or credentials.
- If `SleepDisabled` was enabled outside AwakeBar, startup will show `External Closed-Lid Active`.

## Requirements

- macOS 14.0+
- Xcode 26.2+
- Swift 6
- `xcodegen` (for generating the Xcode project)

Install xcodegen:

```bash
brew install xcodegen
```

## Quick Start (Developers)

1. Generate project files:

```bash
xcodegen generate
```

2. Build:

```bash
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -destination 'platform=macOS' build
```

3. Test:

```bash
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -destination 'platform=macOS' test
```

## Build a Release App and Install to Applications

```bash
xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -configuration Release -destination 'platform=macOS' build
APP_PATH="$(xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -configuration Release -showBuildSettings | awk '/TARGET_BUILD_DIR =/{dir=$3} /FULL_PRODUCT_NAME =/{name=$3} END{print dir"/"name}')"
ditto "$APP_PATH" /Applications/AwakeBar.app
open /Applications/AwakeBar.app
```

## Project Structure

```text
AwakeBar/
  App/          # SwiftUI app + menu-bar controller
  Domain/       # App state + mode mapping
  Services/     # pmset, assertions, auth runner, login item control
  State/        # Persistence layer
  UI/           # Menu content
AwakeBarTests/  # Unit tests + controller tests with mocks
Design/icons/   # Source-of-truth SVG icons
Scripts/        # Asset build scripts
docs/           # Product spec system (FEATURES.md is SSOT)
```

## Icon Pipeline

Source icons live in `Design/icons/*.svg`.

Regenerate asset catalog PDFs after icon edits:

```bash
./Scripts/build-icons.sh
```

## Documentation System

This repository uses a docs spec workflow where `docs/FEATURES.md` is the source of truth for feature IDs and hierarchy.

- Update `docs/FEATURES.md` first.
- Then update corresponding files in `docs/features/`.
- Keep `docs/PRODUCT_MAP.md` synchronized.

## Troubleshooting

- App does not appear in menu bar:
  - Confirm `AwakeBar.app` is running in Activity Monitor.
  - Relaunch with `open /Applications/AwakeBar.app`.
- Closed-lid toggle fails:
  - Check if admin auth was cancelled.
  - Verify current state with `pmset -g | grep SleepDisabled`.
- Login item toggle fails:
  - Re-open AwakeBar and toggle it again.

## License

MIT. See `LICENSE`.

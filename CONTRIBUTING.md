# Contributing

## Development Setup

1. Install dependencies:
   - Xcode 26.2+
   - `xcodegen` (`brew install xcodegen`)
2. Generate the project:
   ```bash
   xcodegen generate
   ```
3. Build and test:
   ```bash
   xcodebuild -project AwakeBar.xcodeproj -scheme AwakeBar -destination 'platform=macOS' test
   ```

## Documentation Workflow

- `docs/FEATURES.md` is the source of truth for feature identity and hierarchy.
- Update `docs/FEATURES.md` first, then propagate to `docs/features/*.md` and `docs/PRODUCT_MAP.md`.
- Keep feature IDs stable (`F-###`).

## Commit Style

- Prefer small, focused commits.
- Include relevant feature IDs in commit messages when changing specs.

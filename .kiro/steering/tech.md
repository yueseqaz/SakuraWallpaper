# Tech Stack & Build System

## Language & Platform

- **Swift** (no SwiftUI — all UI is AppKit/Cocoa)
- **macOS 12.0+** minimum deployment target
- No third-party dependencies; pure Apple frameworks only

## Frameworks Used

| Framework | Purpose |
|---|---|
| Cocoa / AppKit | Windows, menus, status bar, collection views |
| AVFoundation / AVKit | Video playback, frame extraction |
| ServiceManagement | Launch-at-login via `SMAppService` |
| ImageIO | Image format handling |
| IOKit | Battery/power source monitoring |

## Build System

The app is built with `swiftc` directly — there is **no Xcode project file**. The build script compiles all `.swift` files in a specific order and assembles the `.app` bundle manually.

### Common Commands

```bash
# Build the app
./build.sh

# Open the built app
open build/SakuraWallpaper.app

# Build and package as DMG (requires create-dmg and Pillow)
./build.sh dmg

# Run unit tests (Swift Package Manager)
swift test

# Build the testable library target only
swift build
```

### Build Script Notes (`build.sh`)

- Cleans `build/` on every run
- Compiles with `swiftc` in a fixed source order (dependencies first: `SettingsManager`, `MediaType`, `PlaylistBuilder`, then UI layers)
- Copies `Resources/` (localization `.lproj` bundles) and `AppIcon.icns` into the bundle
- Writes `Info.plist` inline; `LSUIElement = true` hides the Dock icon

## Testing

Tests live in `Tests/SakuraWallpaperCoreTests/` and use **XCTest**. Only the pure-logic layer is testable via SPM (`SakuraWallpaperCore` library target):

- `SettingsManager` — injected `UserDefaults` suite for isolation
- `MediaType` — extension detection by file extension
- `PlaylistBuilder` — file collection and index logic

UI/AppKit-dependent files (`AppDelegate`, `WallpaperManager`, `ScreenPlayer`, etc.) are excluded from the SPM target and are not unit-tested.

### Test Isolation Pattern

`SettingsManager` accepts a `UserDefaults` instance in its initializer. Tests create a unique named suite and tear it down in `tearDown()` — never touch `UserDefaults.standard`.

## Localization

Strings are stored in `Resources/en.lproj/Localizable.strings` and `Resources/zh-Hans.lproj/Localizable.strings`. The `String.localized` extension (in `Localization.swift`) resolves strings at runtime based on `SettingsManager.shared.language` (`"system"`, `"en"`, or `"zh-Hans"`).

All user-visible strings must use localization keys, never hardcoded literals.

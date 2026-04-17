# Project Structure

```
SakuraWallpaper/
├── main.swift                    # Entry point — creates NSApplication, sets .accessory policy
├── AppDelegate.swift             # App lifecycle, status bar menu, top-level coordination
├── MainWindowController.swift    # Main window UI (drag-drop, screen picker, controls)
├── WallpaperManager.swift        # Central playback engine; owns ScreenPlayer instances per display
├── ScreenPlayer.swift            # Per-screen AVPlayer window positioned behind desktop icons
├── SettingsManager.swift         # UserDefaults wrapper; single source of truth for all prefs
├── MediaType.swift               # File-extension-based media type detection enum
├── PlaylistBuilder.swift         # Folder scanning and playlist index logic (pure, no side effects)
├── Localization.swift            # String.localized extension + WallpaperError enum
├── PerformanceMonitor.swift      # Lightweight timing/logging utility
├── ThumbnailItem.swift           # NSCollectionViewItem subclass for playlist grid previews
├── ThumbnailProvider.swift       # Async thumbnail generation for menu items and grid
├── AboutWindowController.swift   # About window
│
├── Resources/
│   ├── en.lproj/
│   │   └── Localizable.strings   # English UI strings
│   └── zh-Hans.lproj/
│       └── Localizable.strings   # Simplified Chinese UI strings
│
├── Tests/
│   └── SakuraWallpaperCoreTests/
│       ├── MediaTypeTests.swift
│       ├── PlaylistBuilderTests.swift
│       └── SettingsManagerTests.swift
│
├── Package.swift                 # SPM manifest — testable core library (no AppKit UI files)
├── build.sh                      # swiftc-based build script; assembles .app bundle
├── docs/
│   └── RegressionChecklist.md
└── img/                          # Screenshots and demo GIF for README
```

## Architectural Layers

```
AppDelegate  ──────────────────────────────────────────────────────────
  │  owns                                                              │
  ▼                                                                    ▼
WallpaperManager                                              MainWindowController
  │  owns N                                                            │
  ▼                                                                    │ reads/writes
ScreenPlayer (one per NSScreen)                              SettingsManager.shared
  │  uses                                                              ▲
  ▼                                                                    │
AVPlayer + NSWindow (desktop level)                         PlaylistBuilder (pure)
                                                            MediaType (pure)
```

## Key Conventions

- **Screen identity**: `SettingsManager.screenIdentifier(_:)` returns a stable `"screen_<CGDirectDisplayID>"` string used as dictionary keys throughout `WallpaperManager`.
- **Testable core**: `SettingsManager`, `MediaType`, and `PlaylistBuilder` have no AppKit/UI imports and are compiled into the `SakuraWallpaperCore` SPM library for testing. Keep new pure logic in this layer.
- **Singleton**: `SettingsManager.shared` is used app-wide. The designated initializer accepts a `UserDefaults` parameter for test injection — always use that pattern for new testable code.
- **Localization keys**: All UI strings go through `"key".localized` or `"key".localized(arg)`. Add keys to both `.lproj` files when adding new strings.
- **No Xcode project**: Do not add `.xcodeproj` or `.xcworkspace` files. The build is driven by `build.sh` and `swift test`.
- **Compile order matters**: `build.sh` lists source files explicitly. When adding a new `.swift` file, insert it in the correct dependency order in `build.sh` and exclude it from the SPM target's `exclude` list if it has AppKit dependencies.

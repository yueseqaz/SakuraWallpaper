# Design Document — Multi-Monitor Redesign

## Overview

SakuraWallpaper's current multi-monitor architecture has accumulated several structural problems: settings are split across flat global `UserDefaults` keys and per-screen dictionaries, `screensChanged()` relies on a fragile multi-step fallback chain, sync behavior is implicit and hard to reason about, and `WallpaperManager` carries a `uiScreenID` property that leaks UI concerns into the playback engine.

This redesign replaces all of that with a single unified per-screen settings model (`Screen_Config` / `Screen_Registry`), explicit user-driven sync via a per-screen checkbox (`isSynced`), and a predictable connect/disconnect lifecycle. The result is a system where every screen's full configuration lives in one place, sync group membership is a first-class persisted field, and `WallpaperManager` is free of UI-layer state.

The migration is clean-slate: on first launch after the upgrade, all legacy `UserDefaults` keys are deleted and each connected screen is provisioned fresh according to the user's chosen `New_Screen_Policy`.

---

## Architecture

### Layered Dependency Graph (after redesign)

```
AppDelegate
  │  owns
  ├──► WallpaperManager          (playback engine; no UI state)
  │      │  owns N
  │      └──► ScreenPlayer       (per-screen AVPlayer/NSWindow; unchanged)
  │      │  reads/writes
  │      └──► SettingsManager    (single source of truth)
  │
  └──► MainWindowController      (UI layer)
         │  reads/writes
         └──► SettingsManager
         │  calls (screen-parameterized)
         └──► WallpaperManager
```

Key changes from the current architecture:
- `WallpaperManager` no longer holds `uiScreenID`. All public query methods accept a `Screen_Identifier` or `NSScreen` parameter.
- `SettingsManager` exposes `screenConfig(for:)` / `setScreenConfig(_:for:)` as the sole per-screen read/write interface. All legacy flat global properties (`folderPath`, `isFolderMode`, `rotationIntervalMinutes`, etc.) are removed.
- `Screen_Registry` is a single JSON blob stored under one `UserDefaults` key, replacing the three separate dictionaries (`screenWallpapers`, `screenFolderConfigs`, and the flat global keys).

### Sync Group Architecture

The `Sync_Group` is not a separate data structure — it is the set of screens whose `Screen_Config.isSynced == true`. `WallpaperManager` maintains a single shared `Timer` for all synced screens and per-screen independent `Timer` instances for unsynced screens.

```
Sync_Group (isSynced = true)          Independent screens (isSynced = false)
┌─────────────────────────────┐       ┌──────────────┐  ┌──────────────┐
│  Screen A   Screen B        │       │   Screen C   │  │   Screen D   │
│  ┌───────┐  ┌───────┐       │       │  ┌────────┐  │  │  ┌────────┐  │
│  │config │  │config │       │       │  │config  │  │  │  │config  │  │
│  │(same) │  │(same) │       │       │  │(own)   │  │  │  │(own)   │  │
│  └───────┘  └───────┘       │       │  └────────┘  │  │  └────────┘  │
│       ↑          ↑          │       │      ↑        │  │      ↑       │
│       └──────────┘          │       │   own timer   │  │   own timer  │
│       shared timer tick     │       └──────────────┘  └──────────────┘
└─────────────────────────────┘
```

---

## Components and Interfaces

### SettingsManager (refactored)

The `SettingsManager` is the only component that touches `UserDefaults`. After the redesign it exposes:

**New keys (added):**
```swift
private let screenRegistryKey = "sakurawallpaper_screen_registry"   // JSON-encoded [String: Screen_Config]
private let newScreenPolicyKey = "sakurawallpaper_new_screen_policy" // New_Screen_Policy raw value
private let newScreenMirrorTargetKey = "sakurawallpaper_new_screen_mirror_target_id"
```

**Legacy keys (deleted on clean-slate init, never written again):**
```
sakurawallpaper_folder_path
sakurawallpaper_wallpaper_path
sakurawallpaper_screen_folder_configs
sakurawallpaper_screen_wallpapers
sakurawallpaper_is_folder_mode
sakurawallpaper_rotation_interval_minutes
sakurawallpaper_is_shuffle_mode
sakurawallpaper_is_rotation_enabled
sakurawallpaper_include_subfolders
sakurawallpaper_new_screen_inheritance_mode
sakurawallpaper_new_screen_inheritance_screen_id
```

**New public API:**
```swift
// Per-screen config
func screenConfig(for screenID: String) -> Screen_Config
func setScreenConfig(_ config: Screen_Config, for screenID: String)

// New screen policy
var newScreenPolicy: New_Screen_Policy { get set }
var newScreenMirrorTargetID: String? { get set }

// Clean-slate initialization (called once at launch)
func runCleanSlateInitIfNeeded()
```

**Retained (unchanged):**
```swift
var launchAtLogin: Bool
var pauseWhenInvisible: Bool
var syncDesktopWallpaper: Bool
var onboardingCompleted: Bool
var wallpaperHistory: [String]
var language: String
static func screenIdentifier(_ screen: NSScreen) -> String
static func screenIdentifier(deviceDescription:name:) -> String
```

**Removed entirely:**
```swift
// All of these are deleted:
var wallpaperPath: String?
var isFolderMode: Bool
var folderPath: String?
var rotationIntervalMinutes: Int
var isShuffleMode: Bool
var isRotationEnabled: Bool
var includeSubfolders: Bool
var newScreenInheritanceMode: NewScreenInheritanceMode
var newScreenInheritanceScreenId: String?
var screenWallpapers: [String: String]
var screenFolderConfigs: [String: ScreenFolderConfig]
func folderConfig(for:) -> ScreenFolderConfig?
func setFolderConfig(_:for:)
func clearFolderConfig(for:)
func clearAllFolderConfigs()
func wallpaperPath(for:) -> String?
func setWallpaper(path:for:)
func wallpaperURL(for:) -> URL?
func clearScreenWallpapers()
var hasScreenWallpapers: Bool
var hasExistingSetup: Bool
```

### WallpaperManager (refactored)

**Removed:**
```swift
private var uiScreenID: String?
func setUIScreen(_ screen: NSScreen?)
var playlist: [URL]                    // replaced by playlist(for:)
var currentPlaylistIndex: Int          // replaced by currentPlaylistIndex(for:)
var currentFile: URL?                  // replaced by currentFile(for:)
func setFolder(url: URL)               // no-screen-param overload removed
func selectPlaylistItem(at index: Int) // no-screen-param overload removed
```

**New public API:**
```swift
// Screen-parameterized queries
func playlist(for screenID: String) -> [URL]
func currentPlaylistIndex(for screenID: String) -> Int
func currentFile(for screenID: String) -> URL?

// Sync group management
func setSynced(_ synced: Bool, for screen: NSScreen)

// Screen-parameterized mutations (existing, retained)
func setFolder(url: URL, for screen: NSScreen, config: Screen_Config)
func setWallpaper(url: URL, for screen: NSScreen)
func selectPlaylistItem(at index: Int, for screen: NSScreen)
func nextWallpaper(for screen: NSScreen)
func stopWallpaper(for screen: NSScreen)

// Parameterless nextWallpaper advances ALL screens with an active playlist
func nextWallpaper()
```

**Sync group coordinator (internal):**
```swift
private var syncGroupTimer: Timer?                        // shared tick for all isSynced screens
private var independentTimersByScreen: [String: Timer]    // one per isSynced=false screen
private var syncGroupPlaylistIndex: Int                   // current index shared by all synced screens
```

**Simplified `screensChanged()` logic:**
```
1. Compute removed IDs = existing player keys − current NSScreen IDs
2. For each removed ID: cleanup player, remove all runtime state, do NOT touch Screen_Registry
3. If UI-selected screen was removed: post screenListDidChangeNotification
4. For each new NSScreen not in players:
   a. Read Screen_Config from SettingsManager (returns Default_Config if absent)
   b. If config has no prior registry entry → apply New_Screen_Policy (provision)
   c. If config has a prior registry entry → restore exactly
   d. Build playlist if folderPath is valid; start appropriate timer
5. Resize any existing player whose window frame ≠ screen.frame
```

### MainWindowController (updated)

**Removed:**
- `wallpaperManager.setUIScreen(selectedScreen)` calls — no longer needed
- All reads of `SettingsManager.shared.folderConfig(for:)`, `isRotationEnabled`, `isShuffleMode`, etc. — replaced by `SettingsManager.shared.screenConfig(for:)`

**Added:**
- `syncCheckbox: NSButton` — per-screen sync toggle, shown in the screen selector row
- `syncCheckbox` action calls `wallpaperManager.setSynced(_:for:)`
- All `updateUI()` reads go through `SettingsManager.shared.screenConfig(for: selectedScreenID)`
- Screen picker passes `NSScreen` directly to all `WallpaperManager` calls

**`applyToAllScreens()` updated:**
```swift
// New implementation: always iterates NSScreen.screens explicitly
for screen in NSScreen.screens {
    wallpaperManager.setFolder(url: folderURL, for: screen, config: config)
}
```

### AppDelegate (updated)

The `applicationDidFinishLaunching` restoration block is replaced by a single call:
```swift
SettingsManager.shared.runCleanSlateInitIfNeeded()
wallpaperManager.restoreAllScreens()   // reads Screen_Registry, provisions each connected screen
```

The legacy multi-step fallback loop (screenFolderConfigs → screenWallpapers → globalURL → globalFolderURL) is deleted entirely.

---

## Data Models

### `Screen_Config`

```swift
struct Screen_Config: Codable, Equatable {
    var folderPath: String?
    var wallpaperPath: String?
    var rotationIntervalMinutes: Int
    var isShuffleMode: Bool
    var isRotationEnabled: Bool
    var includeSubfolders: Bool
    var isFolderMode: Bool
    var isSynced: Bool

    static let `default` = Screen_Config(
        folderPath: nil,
        wallpaperPath: nil,
        rotationIntervalMinutes: 15,
        isShuffleMode: false,
        isRotationEnabled: true,
        includeSubfolders: false,
        isFolderMode: false,
        isSynced: true
    )
}
```

`Screen_Config` is `Codable` with `CodingKeys` that map to stable JSON key names. All fields use `decodeIfPresent` with `Screen_Config.default` field values as fallbacks, so records written by older versions of the app decode correctly when new fields are added.

### `Screen_Registry`

```swift
typealias Screen_Registry = [String: Screen_Config]
```

Stored as a single JSON blob under `sakurawallpaper_screen_registry`. The key is a `Screen_Identifier` string (`"screen_<CGDirectDisplayID>"` or the deterministic fallback).

### `New_Screen_Policy`

```swift
enum New_Screen_Policy: String, Codable {
    case inheritSyncGroup
    case blank
    case mirrorSpecificScreen
}
```

Stored as a raw string under `sakurawallpaper_new_screen_policy`. Default value when absent: `.inheritSyncGroup`.

### `ScreenFolderConfig` (removed)

The existing `ScreenFolderConfig` struct is deleted. Its fields are absorbed into `Screen_Config`.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

The testable core (`SakuraWallpaperCore` SPM target) includes `SettingsManager`, `MediaType`, and `PlaylistBuilder`. `WallpaperManager` and `ScreenPlayer` are AppKit-dependent and excluded from the SPM target; their behaviors are verified through manual integration testing. The properties below are scoped to the testable core.

### Property 1: Screen_Config round-trip

*For any* valid `Screen_Config` value, encoding it into the `Screen_Registry` and then decoding it back SHALL produce a `Screen_Config` that is equal to the original across all fields (`folderPath`, `wallpaperPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled`, `includeSubfolders`, `isFolderMode`, `isSynced`).

**Validates: Requirements 9.2, 9.3, 5.6**

### Property 2: Screen_Registry keyed round-trip

*For any* `Screen_Identifier` string and any valid `Screen_Config`, calling `setScreenConfig(_:for:)` followed by `screenConfig(for:)` with the same identifier SHALL return a `Screen_Config` equal to the one that was stored.

**Validates: Requirements 1.2, 9.1, 9.2**

### Property 3: setScreenConfig does not write legacy global keys

*For any* valid `Screen_Config`, after calling `setScreenConfig(_:for:)`, all legacy global `UserDefaults` keys (`sakurawallpaper_folder_path`, `sakurawallpaper_wallpaper_path`, `sakurawallpaper_screen_folder_configs`, `sakurawallpaper_screen_wallpapers`, `sakurawallpaper_is_folder_mode`, `sakurawallpaper_rotation_interval_minutes`, `sakurawallpaper_is_shuffle_mode`, `sakurawallpaper_is_rotation_enabled`, `sakurawallpaper_include_subfolders`) SHALL remain absent from `UserDefaults`.

**Validates: Requirements 1.4, 8.4**

### Property 4: Sync group config invariant

*For any* `Screen_Registry` in which two or more screens have `isSynced = true`, all synced screens SHALL have identical values for `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, and `isRotationEnabled` after any sync-propagating write operation.

**Validates: Requirements 5.1, 5.5**

---

## Error Handling

### Missing or malformed `Screen_Registry` JSON

`SettingsManager.screenConfig(for:)` wraps the `JSONDecoder` call in a `do/catch`. On any decode failure (missing key, malformed JSON, type mismatch), it returns `Screen_Config.default` and logs the error. It never throws to callers.

### Missing `folderPath` on disk

`WallpaperManager` checks `FileManager.default.fileExists(atPath:)` before building a playlist. If the path is absent, the screen's `ScreenPlayer` is left in a stopped state and `screenListDidChangeNotification` is posted so the UI can update.

### Missing `wallpaperPath` on disk

Same pattern: existence check before creating a `ScreenPlayer`. Stopped state + notification on failure.

### `New_Screen_Policy.mirrorSpecificScreen` with unavailable target

If `newScreenMirrorTargetID` refers to a screen that is not currently connected or has no `Screen_Registry` entry, `WallpaperManager` falls back to `inheritSyncGroup` behavior (Requirements 2.6). This fallback is silent — no alert is shown to the user (Requirement 2.9).

### Clean-slate initialization guard

`runCleanSlateInitIfNeeded()` checks for the presence of `sakurawallpaper_screen_registry` before doing anything. If the key already exists, the method returns immediately without modifying any data (Requirement 10.4). This prevents accidental data loss on subsequent launches.

### `Screen_Config` field forward-compatibility

`Screen_Config` uses `decodeIfPresent` for all fields with `Screen_Config.default` values as fallbacks. A record written by an older version of the app that lacks the `isSynced` field will decode with `isSynced = true` (the default), matching the intent of Requirement 9.5.

---

## Testing Strategy

### Unit Tests (XCTest via SPM — `SakuraWallpaperCoreTests`)

Unit tests target the `SakuraWallpaperCore` library, which includes `SettingsManager`, `MediaType`, and `PlaylistBuilder`. All `SettingsManager` tests use an injected `UserDefaults` suite (unique `suiteName` per test, torn down in `tearDown()`).

**`ScreenConfigTests.swift`** — example-based tests:
- `testDefaultConfigFieldValues` — verify `Screen_Config.default` has the exact field values specified in Requirement 1.6
- `testScreenConfigAllFieldsAccessible` — construct a `Screen_Config` with all fields set to non-default values, verify each field is readable (Requirement 1.1)
- `testMissingFieldsDecodedAsDefaults` — write JSON with `isSynced` absent, decode, verify `isSynced == true` (Requirement 9.5)
- `testMalformedJSONReturnsDefault` — write garbage bytes to the registry key, call `screenConfig(for:)`, verify no crash and default returned (Requirement 9.4)
- `testCleanSlateDeletesLegacyKeys` — set all legacy keys, run `runCleanSlateInitIfNeeded()`, verify all legacy keys absent (Requirement 10.1)
- `testCleanSlateCreatesEmptyRegistry` — run clean-slate init, verify unified key exists and decodes as empty dict (Requirement 10.2)
- `testCleanSlateSkippedWhenRegistryPresent` — pre-populate registry, run init, verify data unchanged (Requirement 10.4)
- `testOnboardingKeyNotDeletedByCleanSlate` — set `onboardingCompleted = true`, run clean-slate init, verify it is still `true` (Requirement 12.8)
- `testNewScreenPolicyDefaultIsInheritSyncGroup` — read policy on fresh `SettingsManager`, verify `.inheritSyncGroup` (Requirement 11.3)

**Property-based tests** — using [swift-gen](https://github.com/pointfreeco/swift-gen) or a hand-rolled generator loop (no third-party dependencies allowed; use a deterministic pseudo-random generator seeded from `XCTest`'s `randomSeed`):

Since the project has no third-party dependencies, property tests are implemented as parameterized loops over a representative generated input space (minimum 100 iterations), seeded for reproducibility. Each test is tagged with a comment referencing its design property.

**`ScreenConfigPropertyTests.swift`**:
- `testScreenConfigRoundTrip` — **Feature: multi-monitor-redesign, Property 1: Screen_Config round-trip** — generate 100+ random `Screen_Config` values, store each in a fresh registry, decode, assert equality
- `testScreenRegistryKeyedRoundTrip` — **Feature: multi-monitor-redesign, Property 2: Screen_Registry keyed round-trip** — generate 100+ (identifier, config) pairs, call `setScreenConfig`, call `screenConfig(for:)`, assert equality
- `testSetScreenConfigDoesNotWriteLegacyKeys` — **Feature: multi-monitor-redesign, Property 3: setScreenConfig does not write legacy global keys** — generate 100+ random `Screen_Config` values, call `setScreenConfig`, assert all legacy keys absent
- `testSyncGroupConfigInvariant` — **Feature: multi-monitor-redesign, Property 4: Sync group config invariant** — generate 100+ registries with 2–5 synced screens, apply a propagating write, assert all synced screens share the same `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled`

### Integration / Manual Tests

The following behaviors require a running macOS environment with real `NSScreen` instances and are verified manually or via a regression checklist:

- Screen connect: new screen provisioned per `New_Screen_Policy` (Requirements 2.1–2.10)
- Screen reconnect: saved config restored exactly (Requirements 3.1–3.5)
- Screen disconnect: clean teardown, no other screens affected (Requirements 4.1–4.5)
- Sync group timer coordination: all synced screens advance simultaneously (Requirements 5.3, 5.4)
- Independent rotation: unsynced screens rotate independently (Requirements 6.1–6.6)
- `uiScreenID` removal: `WallpaperManager` compiles without `uiScreenID` (Requirement 7.1)
- Onboarding flow: correct `setFolder`/`setWallpaper` calls on primary screen (Requirements 12.1–12.7)

### Regression Checklist

The existing `docs/RegressionChecklist.md` should be updated to include:
- [ ] Connect a second monitor → verify provisioned per policy
- [ ] Disconnect a monitor → verify remaining screens unaffected
- [ ] Check sync checkbox → verify both screens show same wallpaper
- [ ] Uncheck sync checkbox → verify screens rotate independently
- [ ] Change folder on synced screen → verify all synced screens update
- [ ] Restart app → verify all screen configs restored from registry
- [ ] Upgrade from legacy version → verify clean-slate init runs, onboarding not re-shown

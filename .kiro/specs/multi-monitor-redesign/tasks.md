# Implementation Plan: Multi-Monitor Redesign

## Overview

Replace the split global-key + per-screen-dict storage model with a unified `Screen_Config` / `Screen_Registry` architecture. The migration is clean-slate: legacy `UserDefaults` keys are deleted on first launch, and every screen is provisioned fresh. The work is ordered so that the pure-logic data layer is complete and tested before any AppKit-dependent code is touched.

New pure-logic files (`Screen_Config.swift`, `ScreenConfigTests.swift`, `ScreenConfigPropertyTests.swift`) must be added to `Package.swift` sources and to the `build.sh` compile order (before `WallpaperManager.swift`). New AppKit-dependent files must be added to the `exclude` list in `Package.swift`.

## Tasks

- [x] 1. Define `Screen_Config`, `Screen_Registry`, and `New_Screen_Policy` data models
  - Create `Screen_Config.swift` at the workspace root (pure Swift, no AppKit import)
  - Define `Screen_Config` as a `Codable, Equatable` struct with fields: `folderPath: String?`, `wallpaperPath: String?`, `rotationIntervalMinutes: Int`, `isShuffleMode: Bool`, `isRotationEnabled: Bool`, `includeSubfolders: Bool`, `isFolderMode: Bool`, `isSynced: Bool`
  - Add `static let default` with values: `rotationIntervalMinutes = 15`, `isRotationEnabled = true`, `isShuffleMode = false`, `includeSubfolders = false`, `isFolderMode = false`, `folderPath = nil`, `wallpaperPath = nil`, `isSynced = true`
  - Implement `CodingKeys` with stable JSON key names; use `decodeIfPresent` with `Screen_Config.default` field values as fallbacks for all fields so records from older app versions decode without crashing
  - Define `typealias Screen_Registry = [String: Screen_Config]`
  - Define `New_Screen_Policy: String, Codable` enum with cases `inheritSyncGroup`, `blank`, `mirrorSpecificScreen`
  - Delete the `ScreenFolderConfig` struct from `SettingsManager.swift` (it is fully replaced by `Screen_Config`)
  - Add `Screen_Config.swift` to `build.sh` before `SettingsManager.swift` and to `Package.swift` `sources` array
  - _Requirements: 1.1, 1.2, 1.6, 9.3, 9.5, 11.2_

- [x] 2. Refactor `SettingsManager` — new per-screen API and clean-slate init
  - [x] 2.1 Add new `UserDefaults` keys and remove legacy key constants
    - Add private key constants: `screenRegistryKey = "sakurawallpaper_screen_registry"`, `newScreenPolicyKey = "sakurawallpaper_new_screen_policy"`, `newScreenMirrorTargetKey = "sakurawallpaper_new_screen_mirror_target_id"`
    - Remove private key constants for all legacy keys listed in the design (`wallpaperKey`, `isFolderModeKey`, `folderPathKey`, `rotationIntervalMinutesKey`, `isShuffleModeKey`, `isRotationEnabledKey`, `includeSubfoldersKey`, `screenFolderConfigsKey`, `newScreenInheritanceModeKey`, `newScreenInheritanceScreenIdKey`, `screenWallpapersKey`)
    - _Requirements: 1.3, 1.4, 8.4_

  - [x] 2.2 Implement `screenConfig(for:)` and `setScreenConfig(_:for:)`
    - Implement `func screenConfig(for screenID: String) -> Screen_Config`: decode the JSON blob from `screenRegistryKey`; on any decode failure return `Screen_Config.default` and log the error; never throw
    - Implement `func setScreenConfig(_ config: Screen_Config, for screenID: String)`: read the current registry, update the entry for `screenID`, re-encode as JSON, and write back under `screenRegistryKey` only — do not write any flat global keys
    - _Requirements: 1.3, 1.4, 9.1, 9.2, 9.4_

  - [x] 2.3 Implement `newScreenPolicy` and `newScreenMirrorTargetID` properties
    - Add `var newScreenPolicy: New_Screen_Policy` computed property backed by `newScreenPolicyKey`; return `.inheritSyncGroup` when the key is absent
    - Add `var newScreenMirrorTargetID: String?` computed property backed by `newScreenMirrorTargetKey`
    - Remove `newScreenInheritanceMode` and `newScreenInheritanceScreenId` properties
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

  - [x] 2.4 Remove all legacy global property accessors
    - Delete the following computed properties and their backing logic from `SettingsManager`: `wallpaperPath` (the setter/getter pair that writes `wallpaperKey`), `isFolderMode`, `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled`, `includeSubfolders`, `screenWallpapers`, `wallpaperURL`, `hasScreenWallpapers`, `hasExistingSetup`
    - Delete the following methods: `wallpaperPath(for:)`, `setWallpaper(path:for:)`, `wallpaperURL(for:)`, `clearScreenWallpapers()`, `screenFolderConfigs`, `folderConfig(for:)`, `setFolderConfig(_:for:)`, `clearFolderConfig(for:)`, `clearAllFolderConfigs()`
    - Delete the `NewScreenInheritanceMode` enum
    - Retain: `launchAtLogin`, `pauseWhenInvisible`, `syncDesktopWallpaper`, `onboardingCompleted`, `wallpaperHistory`, `language`, `screenIdentifier(_:)`, `screenIdentifier(deviceDescription:name:)`
    - Note: `wallpaperHistory` and its `addToHistory` helper are retained; the `wallpaperPath` setter's `addToHistory` call must be moved to call sites that still need history tracking
    - _Requirements: 1.5, 7.1_

  - [x] 2.5 Implement `runCleanSlateInitIfNeeded()`
    - Check for presence of `screenRegistryKey` in `UserDefaults`; if already present, return immediately without modifying any data
    - If absent: delete all legacy keys listed in Requirement 10.1 using `defaults.removeObject(forKey:)` for each; do not delete `onboardingCompleted`, `launchAtLogin`, `pauseWhenInvisible`, `syncDesktopWallpaper`, `historyKey`, or `languageKey`
    - Write an empty `Screen_Registry` (`[:]`) encoded as JSON under `screenRegistryKey`
    - _Requirements: 10.1, 10.2, 10.4, 12.8_

- [x] 3. Write unit tests for `SettingsManager` new API (`ScreenConfigTests.swift`)
  - Create `Tests/SakuraWallpaperCoreTests/ScreenConfigTests.swift`
  - Use the same `setUp`/`tearDown` pattern as `SettingsManagerTests.swift`: unique `suiteName`, injected `UserDefaults`, torn down after each test
  - `testDefaultConfigFieldValues` — construct `Screen_Config.default`, assert each field matches Requirement 1.6 exactly
  - `testScreenConfigAllFieldsAccessible` — construct a `Screen_Config` with all fields set to non-default values, assert each field is readable
  - `testMissingFieldsDecodedAsDefaults` — write JSON with `isSynced` key absent, call `screenConfig(for:)`, assert `isSynced == true`
  - `testMalformedJSONReturnsDefault` — write garbage bytes to `screenRegistryKey`, call `screenConfig(for:)`, assert no crash and result equals `Screen_Config.default`
  - `testCleanSlateDeletesLegacyKeys` — set all legacy keys listed in Requirement 10.1, call `runCleanSlateInitIfNeeded()`, assert each legacy key is absent from `UserDefaults`
  - `testCleanSlateCreatesEmptyRegistry` — call `runCleanSlateInitIfNeeded()` on a fresh suite, assert `screenRegistryKey` exists and decodes as an empty dictionary
  - `testCleanSlateSkippedWhenRegistryPresent` — pre-populate `screenRegistryKey` with a known config, call `runCleanSlateInitIfNeeded()`, assert the registry data is unchanged
  - `testOnboardingKeyNotDeletedByCleanSlate` — set `onboardingCompleted = true`, call `runCleanSlateInitIfNeeded()`, assert `onboardingCompleted` is still `true`
  - `testNewScreenPolicyDefaultIsInheritSyncGroup` — read `newScreenPolicy` on a fresh `SettingsManager`, assert `.inheritSyncGroup`
  - `testSetScreenConfigDoesNotWriteLegacyGlobalKeys` — call `setScreenConfig(_:for:)` with a fully-populated config, assert all legacy key strings are absent from `UserDefaults`
  - _Requirements: 1.3, 1.4, 1.6, 9.1, 9.2, 9.4, 9.5, 10.1, 10.2, 10.4, 11.3, 12.8_

- [x] 4. Write property-based tests for `SettingsManager` (`ScreenConfigPropertyTests.swift`)
  - Create `Tests/SakuraWallpaperCoreTests/ScreenConfigPropertyTests.swift`
  - Implement a deterministic pseudo-random `Screen_Config` generator seeded from a fixed integer (no third-party dependencies); generate at least 100 distinct values per test by varying all fields systematically
  - [x] 4.1 Write property test for Screen_Config round-trip (Property 1)
    - **Property 1: Screen_Config round-trip**
    - For each generated `Screen_Config`: encode it into a fresh `Screen_Registry` JSON blob, decode it back, assert the decoded value equals the original across all 8 fields
    - Tag with comment: `// Feature: multi-monitor-redesign, Property 1: Screen_Config round-trip`
    - **Validates: Requirements 9.2, 9.3, 5.6**
  - [x] 4.2 Write property test for Screen_Registry keyed round-trip (Property 2)
    - **Property 2: Screen_Registry keyed round-trip**
    - For each generated `(screenID, Screen_Config)` pair: call `setScreenConfig(_:for:)`, then `screenConfig(for:)` with the same ID, assert equality
    - Use a fresh injected `UserDefaults` suite per iteration (or reset between iterations)
    - Tag with comment: `// Feature: multi-monitor-redesign, Property 2: Screen_Registry keyed round-trip`
    - **Validates: Requirements 1.2, 9.1, 9.2**
  - [x] 4.3 Write property test for no legacy key writes (Property 3)
    - **Property 3: setScreenConfig does not write legacy global keys**
    - For each generated `Screen_Config`: call `setScreenConfig(_:for:)`, then assert that each of the 9 legacy key strings listed in the design is absent from `UserDefaults`
    - Tag with comment: `// Feature: multi-monitor-redesign, Property 3: setScreenConfig does not write legacy global keys`
    - **Validates: Requirements 1.4, 8.4**
  - [x] 4.4 Write property test for sync group config invariant (Property 4)
    - **Property 4: Sync group config invariant**
    - Generate registries with 2–5 screens all having `isSynced = true`; simulate a propagating write (update `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled` on one screen and copy to all others); assert all synced screens share identical values for those four fields
    - Tag with comment: `// Feature: multi-monitor-redesign, Property 4: Sync group config invariant`
    - **Validates: Requirements 5.1, 5.5**

- [x] 5. Checkpoint — verify data layer compiles and all tests pass
  - Run `swift build` and confirm `SakuraWallpaperCore` builds without errors
  - Run `swift test` and confirm all tests in `SakuraWallpaperCoreTests` pass, including the new `ScreenConfigTests` and `ScreenConfigPropertyTests`
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Refactor `WallpaperManager` — remove `uiScreenID` and add screen-parameterized API
  - [x] 6.1 Remove `uiScreenID` and all methods that depend on it
    - Delete the `private var uiScreenID: String?` property
    - Delete `func setUIScreen(_ screen: NSScreen?)` and its body
    - Delete the parameterless `var playlist: [URL]`, `var currentPlaylistIndex: Int`, `var currentFile: URL?` computed properties (and their `uiOrFirstPlaylistScreenID()` helper if present)
    - Delete the parameterless `func setFolder(url: URL)` overload
    - Delete the parameterless `func selectPlaylistItem(at index: Int)` overload
    - Update `deinit` to remove any `stopRotationTimer()` call that relied on `uiScreenID`
    - _Requirements: 7.1, 7.4, 8.2_

  - [x] 6.2 Add screen-parameterized query methods
    - Implement `func playlist(for screenID: String) -> [URL]` — returns `playlistsByScreen[screenID] ?? []`
    - Implement `func currentPlaylistIndex(for screenID: String) -> Int` — returns `playlistIndexesByScreen[screenID] ?? 0`
    - Implement `func currentFile(for screenID: String) -> URL?` — returns `currentFiles[screenID]`
    - Update `func nextWallpaper()` (parameterless) to iterate `playlistsByScreen.keys` and advance all screens that have a non-empty playlist, without referencing `uiScreenID`
    - _Requirements: 7.2, 7.3, 7.5_

  - [x] 6.3 Add sync group timer coordination
    - Add `private var syncGroupTimer: Timer?` and `private var independentTimersByScreen: [String: Timer]` (rename existing `rotationTimersByScreen` to `independentTimersByScreen`)
    - Add `private var syncGroupPlaylistIndex: Int = 0`
    - Implement `func setSynced(_ synced: Bool, for screen: NSScreen)`:
      - If `synced = true`: set `isSynced = true` on the screen's `Screen_Config`, copy the current sync-group config to this screen (if any synced screen exists), align its playlist index to `syncGroupPlaylistIndex`, persist via `setScreenConfig`, stop the screen's independent timer, and ensure `syncGroupTimer` is running
      - If `synced = false`: set `isSynced = false`, persist via `setScreenConfig`, detach from `syncGroupTimer`, start an independent timer for this screen using its own `rotationIntervalMinutes`
    - Update the shared `syncGroupTimer` tick to advance `syncGroupPlaylistIndex` and call `nextWallpaper(forScreenID:)` for every screen whose `Screen_Config.isSynced == true`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.1, 6.6_

  - [x] 6.4 Rewrite `screensChanged()` using the new `Screen_Registry` API
    - Replace the existing multi-step fallback chain with the simplified logic from the design:
      1. Compute removed IDs = existing player keys − current `NSScreen` IDs
      2. For each removed ID: cleanup player, remove all runtime state (`playlistsByScreen`, `playlistIndexesByScreen`, independent timer, `pausedScreens`, transient snapshot); do NOT touch `Screen_Registry`
      3. If the removed ID was the previously UI-selected screen: post `screenListDidChangeNotification`
      4. For each new `NSScreen` not in `players`:
         - Read `Screen_Config` from `SettingsManager.shared.screenConfig(for:)`
         - If no prior registry entry exists (registry returns `Screen_Config.default` and key is absent): apply `New_Screen_Policy` to provision the screen (see Requirement 2)
         - If a prior registry entry exists: restore exactly (see Requirement 3)
         - Build playlist if `folderPath` is valid; start appropriate timer (sync group or independent)
      5. Resize any existing player whose `window.frame ≠ screen.frame`
    - Delete `inheritanceSourceScreen(excluding:)`, `primaryScreenForInheritance(excluding:)`, `syncPlaylistIndex(for:screenID:folderPath:)`, and `hasExistingConfig(for:)` helpers (replaced by registry lookup)
    - _Requirements: 2.1–2.10, 3.1–3.5, 4.1–4.5_

  - [x] 6.5 Rewrite `setFolder(url:for:config:)` to use `Screen_Config` and propagate sync
    - Change the `config` parameter type from `ScreenFolderConfig` to `Screen_Config`
    - After building the playlist, call `SettingsManager.shared.setScreenConfig(updatedConfig, for: id)` — do not write any flat global keys
    - If the screen's `isSynced == true`, propagate `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled` to all other synced screens by calling `setScreenConfig` for each and rebuilding their playlists
    - _Requirements: 5.5, 8.1, 8.3, 8.4_

  - [x] 6.6 Update `setWallpaper(url:for:)` and `stopWallpaper(for:)` to use `Screen_Config`
    - In `setWallpaper(url:for:)`: replace `SettingsManager.shared.setWallpaper(path:for:)` and `clearFolderConfig(for:)` calls with a `setScreenConfig` call that sets `wallpaperPath` and clears `folderPath`/`isFolderMode` on the screen's config
    - In `stopWallpaper(for:)` (if it exists) or the stop path in `stopAll()`: update to clear the screen's `Screen_Config` fields via `setScreenConfig` rather than legacy methods
    - _Requirements: 1.3, 1.4_

  - [x] 6.7 Add `restoreAllScreens()` method
    - Implement `func restoreAllScreens()`: iterate `NSScreen.screens`, read each screen's `Screen_Config` from `SettingsManager.shared.screenConfig(for:)`, and restore playback (build playlist if `folderPath` valid, set wallpaper if `wallpaperPath` valid, leave stopped otherwise)
    - This replaces the multi-step fallback loop in `AppDelegate.applicationDidFinishLaunching`
    - _Requirements: 3.1, 3.4, 10.3_

- [x] 7. Update `AppDelegate` — replace restoration loop with clean-slate init
  - In `applicationDidFinishLaunching`: replace the entire `screenFolderConfigs` / `screenWallpapers` / `globalURL` / `globalFolderURL` restoration block with two calls: `SettingsManager.shared.runCleanSlateInitIfNeeded()` then `wallpaperManager.restoreAllScreens()`
  - Remove all references to deleted `SettingsManager` properties (`screenFolderConfigs`, `wallpaperURL`, `isFolderMode`, `folderPath`, `clearScreenWallpapers`, `clearAllFolderConfigs`, `isRotationEnabled`, `isShuffleMode`)
  - Update `stopWallpaper()` `@objc` method: replace legacy `SettingsManager` calls (`wallpaperPath = nil`, `clearScreenWallpapers()`, `isFolderMode = false`, `folderPath = nil`, `clearAllFolderConfigs()`) with a loop that calls `setScreenConfig(Screen_Config.default, for: id)` for each connected screen
  - Update `switchToRecent(_:)`: replace `wallpaperManager.setFolder(url:)` (parameterless) with a loop calling `wallpaperManager.setFolder(url:for:config:)` per screen; replace legacy `SettingsManager` property writes with `setScreenConfig` calls
  - Update `updateAutoPauseItem()` status bar label: replace reads of `SettingsManager.shared.isFolderMode`, `screenFolderConfigs`, `folderPath`, `isShuffleMode`, `isRotationEnabled` with reads from `SettingsManager.shared.screenConfig(for:)` for the first active screen
  - _Requirements: 7.1, 10.1, 10.2, 10.3_

- [x] 8. Update `MainWindowController` — remove `setUIScreen`, add sync checkbox, update all UI reads
  - [x] 8.1 Remove `setUIScreen` calls and update screen selection
    - Delete `wallpaperManager.setUIScreen(selectedScreen)` from `setupUI()` and `screenSelectionChanged(_:)`
    - Update `screenSelectionChanged(_:)` to store `selectedScreen` and call `updateUI()` directly (no `setUIScreen` needed)
    - _Requirements: 7.1, 7.2_

  - [x] 8.2 Add `syncCheckbox` to the screen selector row
    - Add `private var syncCheckbox: NSButton` as a checkbox with title `"ui.syncScreens".localized`
    - Position it in `createScreenSelector()` to the right of `screenPopUp` (adjust `applyAllButton` frame accordingly)
    - Wire its action to `@objc private func syncCheckboxChanged(_ sender: NSButton)` which calls `wallpaperManager.setSynced(sender.state == .on, for: selectedScreen!)`
    - In `updateUI()`, set `syncCheckbox.state` from `SettingsManager.shared.screenConfig(for: selectedScreenID).isSynced`
    - _Requirements: 5.1, 5.2_

  - [x] 8.3 Replace all per-screen `SettingsManager` reads in `updateUI()` with `screenConfig(for:)`
    - Compute `let selectedScreenID = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""`
    - Compute `let config = SettingsManager.shared.screenConfig(for: selectedScreenID)`
    - Replace all reads of `SettingsManager.shared.isRotationEnabled`, `isShuffleMode`, `includeSubfolders`, `rotationIntervalMinutes`, `isFolderMode`, `folderPath` with `config.isRotationEnabled`, `config.isShuffleMode`, etc.
    - Replace `wallpaperManager.playlist` / `wallpaperManager.currentPlaylistIndex` / `wallpaperManager.currentFile` with `wallpaperManager.playlist(for: selectedScreenID)` / `wallpaperManager.currentPlaylistIndex(for: selectedScreenID)` / `wallpaperManager.currentFile(for: selectedScreenID)`
    - _Requirements: 7.2, 7.3, 1.3_

  - [x] 8.4 Update settings action handlers to write via `setScreenConfig`
    - Update `rotationSwitchChanged`, `shuffleSwitchChanged`, `includeSubfoldersChanged`, `intervalFieldChanged`, `intervalStepperChanged` to read the current `Screen_Config` for `selectedScreen`, mutate the relevant field, and call `wallpaperManager.setFolder(url:for:config:)` or `SettingsManager.shared.setScreenConfig(_:for:)` as appropriate
    - Remove the `inheritSourcePopUp` / `inheritSourceLabel` controls and `updateInheritSourceMenu()` / `inheritSourceChanged()` — replaced by `New_Screen_Policy` UI (see task 8.5)
    - _Requirements: 1.3, 5.5, 6.2, 6.3_

  - [x] 8.5 Replace `inheritSourcePopUp` with `New_Screen_Policy` picker
    - Add a `newScreenPolicyPopUp: NSPopUpButton` in the settings area (same vertical position as the removed `inheritSourcePopUp`)
    - Populate with three items: `"ui.newScreenPolicy.inheritSyncGroup".localized`, `"ui.newScreenPolicy.blank".localized`, `"ui.newScreenPolicy.mirrorSpecificScreen".localized`
    - When `mirrorSpecificScreen` is selected, show a companion `mirrorTargetPopUp: NSPopUpButton` populated from all known `Screen_Identifier` entries in the `Screen_Registry`
    - Wire actions to read/write `SettingsManager.shared.newScreenPolicy` and `SettingsManager.shared.newScreenMirrorTargetID`
    - In `updateUI()`, sync both controls to current `SettingsManager` values
    - _Requirements: 11.6, 11.7, 11.8, 11.9_

  - [x] 8.6 Update `applyToAllScreens()` to use the new API
    - Replace the existing implementation with: read `config = SettingsManager.shared.screenConfig(for: selectedScreenID)`; if `config.isFolderMode` and `config.folderPath` is valid, call `wallpaperManager.setFolder(url:for:config:)` once per screen in `NSScreen.screens`; otherwise if `currentFile(for: selectedScreenID)` is non-nil, call `wallpaperManager.setWallpaper(url:for:)` once per screen
    - Remove all references to `wallpaperManager.currentPlaylistIndex` (parameterless) and `wallpaperManager.setFolder(url:)` (parameterless)
    - _Requirements: 8.5_

  - [x] 8.7 Update onboarding to use screen-parameterized API
    - In `runOnboardingIfNeeded()` and the onboarding completion handler: replace `wallpaperManager.setFolder(url:)` with `wallpaperManager.setFolder(url:for:config:)` targeting the primary screen
    - Replace `wallpaperManager.setWallpaper(url:)` (if a parameterless overload was used) with `wallpaperManager.setWallpaper(url:for:)` targeting the primary screen
    - _Requirements: 12.1, 12.2, 12.3_

- [x] 9. Checkpoint — build the full app and verify compilation
  - Run `./build.sh` and confirm the app compiles without errors or warnings
  - Run `swift test` and confirm all unit and property tests still pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Add localization strings for new UI elements
  - Add the following keys to `Resources/en.lproj/Localizable.strings`:
    - `"ui.syncScreens" = "Sync";` — label for the per-screen sync checkbox
    - `"ui.syncScreens.tooltip" = "When checked, this screen shares its wallpaper, folder, and rotation settings with all other synced screens.";`
    - `"ui.newScreenPolicy" = "New Screen Policy";`
    - `"ui.newScreenPolicy.inheritSyncGroup" = "Inherit Sync Group";`
    - `"ui.newScreenPolicy.blank" = "Start Blank";`
    - `"ui.newScreenPolicy.mirrorSpecificScreen" = "Mirror Specific Screen";`
    - `"ui.newScreenPolicy.mirrorTarget" = "Mirror Source";`
    - `"ui.newScreenPolicy.tooltip" = "Controls what happens when a new monitor is connected.";`
  - Add the corresponding Simplified Chinese translations to `Resources/zh-Hans.lproj/Localizable.strings`:
    - `"ui.syncScreens" = "同步";`
    - `"ui.syncScreens.tooltip" = "勾选后，此屏幕将与所有已同步屏幕共享壁纸、文件夹和轮播设置。";`
    - `"ui.newScreenPolicy" = "新屏策略";`
    - `"ui.newScreenPolicy.inheritSyncGroup" = "继承同步组";`
    - `"ui.newScreenPolicy.blank" = "空白启动";`
    - `"ui.newScreenPolicy.mirrorSpecificScreen" = "镜像指定屏幕";`
    - `"ui.newScreenPolicy.mirrorTarget" = "镜像来源";`
    - `"ui.newScreenPolicy.tooltip" = "控制接入新显示器时的行为。";`
  - Remove the now-unused keys `"ui.newScreenInherit"`, `"ui.newScreenInherit.tooltip"`, and `"ui.inheritPrimaryScreen"` from both `.lproj` files
  - _Requirements: 11.6, 11.7, 11.9_

- [x] 11. Final checkpoint — full build, test suite, and smoke test
  - Run `./build.sh` and confirm the app builds cleanly
  - Run `swift test` and confirm all tests pass
  - Open `build/SakuraWallpaper.app` and verify: the screen selector shows the sync checkbox, the new screen policy picker is present, and the app launches without crashing
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- `Screen_Config.swift` must appear in `build.sh` before `SettingsManager.swift` and in `Package.swift` `sources`; it must NOT appear in the `exclude` list
- `WallpaperManager.swift`, `AppDelegate.swift`, and `MainWindowController.swift` are AppKit-dependent and must remain in the `exclude` list in `Package.swift`
- All new `SettingsManager` tests use an injected `UserDefaults` suite — never `UserDefaults.standard`
- Property tests use a deterministic pseudo-random generator (no third-party libraries); seed from a fixed integer for reproducibility
- The `ScreenFolderConfig` struct is deleted entirely; any remaining references after task 2 are compile errors that must be resolved before proceeding to task 6
- The `uiScreenID` property is deleted entirely; any remaining references after task 6.1 are compile errors that must be resolved before proceeding to task 7

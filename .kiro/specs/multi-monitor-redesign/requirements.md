# Requirements Document

## Introduction

This feature redesigns the multi-monitor wallpaper management system in SakuraWallpaper. The current architecture has a split storage model (global keys + per-screen dicts), a fragile multi-step fallback chain in `screensChanged()`, implicit sync behavior, and UI concerns leaking into the playback engine. The redesign replaces all of this with a unified per-screen settings model, explicit user-driven sync, and a predictable monitor connect/disconnect lifecycle.

## Glossary

- **Screen_Config**: A self-contained record of all wallpaper settings for a single physical display. Replaces the current split between global keys and `ScreenFolderConfig`. Includes an `isSynced: Bool` field indicating whether the screen is a member of the `Sync_Group`.
- **Screen_Registry**: The persistent store that maps screen identifiers to `Screen_Config` records. Replaces `screenWallpapers` + `screenFolderConfigs` + the flat global keys. Also persists `Sync_Group` membership via the `isSynced` field on each `Screen_Config`.
- **Screen_Identifier**: A stable string key derived from `CGDirectDisplayID` (or a deterministic fallback) that uniquely identifies a physical display across reconnects.
- **WallpaperManager**: The central playback engine that owns one `ScreenPlayer` per connected display.
- **SettingsManager**: The `UserDefaults` wrapper and single source of truth for all persisted preferences.
- **ScreenPlayer**: The per-screen `AVPlayer`/`NSWindow` that renders the wallpaper behind desktop icons.
- **Playlist**: The ordered list of media files built from a folder for a given screen.
- **Rotation**: Automatic advancement through a `Playlist` at a configured time interval.
- **Sync_Group**: The set of screens whose `isSynced` field is `true`. All screens in the `Sync_Group` share the same `folderPath`, playlist index, and rotation timer tick. A setting change (folder, interval, shuffle, rotation enabled) on any `Sync_Group` member is immediately propagated to all other members.
- **Default_Config**: The `Screen_Config` applied to a screen that has no saved record in the `Screen_Registry`. Contains sensible defaults (rotation enabled, 15-minute interval, shuffle off, no folder, `isSynced = true`).
- **PlaylistBuilder**: The pure, side-effect-free module that scans a folder and returns an ordered list of media file URLs.
- **New_Screen_Policy**: A global app preference controlling what happens when a screen with no `Screen_Registry` entry is connected. One of: `inheritSyncGroup`, `blank`, `mirrorSpecificScreen`.

---

## Requirements

### Requirement 1: Unified Per-Screen Settings Model

**User Story:** As a developer maintaining SakuraWallpaper, I want each screen's settings stored in a single unified record, so that global and per-screen state can never diverge.

#### Acceptance Criteria

1. THE `Screen_Config` SHALL contain all settings for one screen: `folderPath`, `wallpaperPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled`, `includeSubfolders`, `isFolderMode`, and `isSynced`.
2. THE `Screen_Registry` SHALL store `Screen_Config` records keyed by `Screen_Identifier`.
3. THE `SettingsManager` SHALL expose `screenConfig(for:)` and `setScreenConfig(_:for:)` as the sole read/write interface for per-screen settings.
4. WHEN `setScreenConfig(_:for:)` is called, THE `SettingsManager` SHALL persist only the per-screen record and SHALL NOT write any flat global wallpaper or folder keys.
5. THE `SettingsManager` SHALL NOT expose `isFolderMode`, `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled`, or `includeSubfolders` as top-level global properties after the migration.
6. WHEN a `Screen_Config` is read for a `Screen_Identifier` that has no saved record, THE `SettingsManager` SHALL return a `Default_Config` with `rotationIntervalMinutes = 15`, `isRotationEnabled = true`, `isShuffleMode = false`, `includeSubfolders = false`, `isFolderMode = false`, `folderPath = nil`, `wallpaperPath = nil`, and `isSynced = true`.

---

### Requirement 2: Screen Connect — New Screen Provisioning

**User Story:** As a user, I want a newly connected monitor to be set up according to my chosen `New_Screen_Policy` preference, so that every new display is configured the way I expect without manual intervention.

#### Acceptance Criteria

1. WHEN `NSApplication.didChangeScreenParametersNotification` fires and a new `Screen_Identifier` is detected that has no entry in the `Screen_Registry`, THE `WallpaperManager` SHALL provision the new screen according to the current value of `New_Screen_Policy` stored in `SettingsManager`.
2. WHEN `New_Screen_Policy` is `inheritSyncGroup` and the `Sync_Group` contains at least one synced screen, THE `WallpaperManager` SHALL copy the current `Sync_Group`'s `Screen_Config` to the new screen and set `isSynced = true` on the new screen's `Screen_Config`.
3. WHEN `New_Screen_Policy` is `inheritSyncGroup` and the `Sync_Group` is empty (no screens have `isSynced = true`), THE `WallpaperManager` SHALL assign a `Default_Config` to the new screen with `isSynced = false`.
4. WHEN `New_Screen_Policy` is `blank`, THE `WallpaperManager` SHALL assign a `Default_Config` to the new screen with `isSynced = false`, leave the new screen's `ScreenPlayer` in a stopped state, and SHALL post `screenListDidChangeNotification`.
5. WHEN `New_Screen_Policy` is `mirrorSpecificScreen` and the `Screen_Identifier` stored in `newScreenMirrorTargetID` is currently connected and has an entry in the `Screen_Registry`, THE `WallpaperManager` SHALL copy that target screen's `Screen_Config` to the new screen and set `isSynced = false` on the new screen's `Screen_Config`.
6. WHEN `New_Screen_Policy` is `mirrorSpecificScreen` and the target `Screen_Identifier` stored in `newScreenMirrorTargetID` is not currently connected or has no entry in the `Screen_Registry`, THE `WallpaperManager` SHALL fall back to `inheritSyncGroup` behavior as defined in acceptance criteria 2 and 3.
7. WHEN a new screen is provisioned and the resulting `Screen_Config` contains a valid `folderPath`, THE `WallpaperManager` SHALL build a `Playlist` for the new screen, set its playlist index to match the current `Sync_Group` index if `isSynced = true`, and start its rotation timer.
8. WHEN a new screen is provisioned and the resulting `Screen_Config` contains no valid `folderPath` and no valid `wallpaperPath`, THE `WallpaperManager` SHALL leave the new screen's `ScreenPlayer` in a stopped state and SHALL post `screenListDidChangeNotification`.
9. THE `WallpaperManager` SHALL NOT display any prompt or dialog to the user when provisioning a new screen.
10. THE `WallpaperManager` SHALL persist the new screen's `Screen_Config` in the `Screen_Registry` immediately after provisioning.

---

### Requirement 3: Screen Reconnect — Saved Config Restoration

**User Story:** As a user, I want my wallpaper settings to be restored exactly as I left them when I reconnect a monitor, so that I don't have to reconfigure displays I've used before.

#### Acceptance Criteria

1. WHEN `NSApplication.didChangeScreenParametersNotification` fires and a `Screen_Identifier` is detected that already has an entry in the `Screen_Registry`, THE `WallpaperManager` SHALL restore that screen's `Screen_Config` exactly, without inheriting from any other screen.
2. WHEN a reconnected screen's saved `folderPath` no longer exists on disk, THE `WallpaperManager` SHALL stop playback for that screen and SHALL post `screenListDidChangeNotification`.
3. WHEN a reconnected screen's saved `wallpaperPath` no longer exists on disk, THE `WallpaperManager` SHALL stop playback for that screen and SHALL post `screenListDidChangeNotification`.
4. WHEN a reconnected screen's saved `folderPath` exists on disk, THE `WallpaperManager` SHALL rebuild the `Playlist` and resume `Rotation` at the previously saved playlist index.
5. THE `WallpaperManager` SHALL NOT execute any inheritance or fallback logic when a screen with a saved `Screen_Config` reconnects.

---

### Requirement 4: Screen Disconnect — Clean Teardown

**User Story:** As a developer, I want disconnected screens to be torn down cleanly without affecting other screens, so that removing a monitor never corrupts the state of remaining displays.

#### Acceptance Criteria

1. WHEN `NSApplication.didChangeScreenParametersNotification` fires and a `Screen_Identifier` is no longer present in `NSScreen.screens`, THE `WallpaperManager` SHALL stop and deallocate the `ScreenPlayer` for that screen.
2. WHEN a screen is disconnected, THE `WallpaperManager` SHALL remove all in-memory runtime state for that screen (playlist, playlist index, rotation timer, paused state, transient desktop snapshot).
3. WHEN a screen is disconnected, THE `WallpaperManager` SHALL NOT remove the screen's `Screen_Config` from the `Screen_Registry`, so it can be restored on reconnect.
4. WHEN the UI-selected screen is disconnected, THE `WallpaperManager` SHALL update `uiScreenID` to the first remaining connected screen and SHALL post `screenListDidChangeNotification`.
5. WHEN a screen is disconnected, THE `WallpaperManager` SHALL NOT modify the `Screen_Config` or runtime state of any other connected screen.

---

### Requirement 5: Sync Group — Checkbox-Driven Screen Synchronization

**User Story:** As a user, I want to control which screens are synchronized via a per-screen checkbox, so that I can keep selected displays in lockstep while leaving others fully independent.

#### Acceptance Criteria

1. WHEN the user checks the sync checkbox for a screen, THE `WallpaperManager` SHALL set `isSynced = true` on that screen's `Screen_Config`, copy the current `Screen_Config` from any existing `Sync_Group` member to that screen, align its playlist index to the current `Sync_Group` index, and persist the updated `Screen_Config` in the `Screen_Registry`.
2. WHEN the user unchecks the sync checkbox for a screen, THE `WallpaperManager` SHALL set `isSynced = false` on that screen's `Screen_Config`, detach that screen's rotation timer from the `Sync_Group`, and persist the updated `Screen_Config` in the `Screen_Registry`, leaving all other `Sync_Group` members unaffected.
3. WHILE a screen's `isSynced` is `true`, THE `WallpaperManager` SHALL advance all `Sync_Group` members to the same playlist index simultaneously when any member's rotation timer fires.
4. WHILE a screen's `isSynced` is `true`, THE `WallpaperManager` SHALL use a single shared rotation timer tick for all `Sync_Group` members so that rotation advances are coordinated.
5. WHEN the user changes `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, or `isRotationEnabled` on any screen whose `isSynced` is `true`, THE `WallpaperManager` SHALL apply the same change to every other screen whose `isSynced` is `true` and persist the updated `Screen_Config` for each affected screen in the `Screen_Registry`.
6. THE `Screen_Registry` SHALL persist the `isSynced` field for every screen so that `Sync_Group` membership survives app restarts and reconnects.
7. WHEN a screen whose `isSynced` is `true` disconnects, THE `WallpaperManager` SHALL continue `Sync_Group` rotation for all remaining `Sync_Group` members without interruption.
8. WHEN a screen reconnects and its saved `Screen_Config` has `isSynced = true`, THE `WallpaperManager` SHALL re-add that screen to the `Sync_Group`, copy the current `Sync_Group` `Screen_Config` to it, and align its playlist index to the current `Sync_Group` index.
9. WHILE a screen's `isSynced` is `false`, THE `WallpaperManager` SHALL NOT propagate any setting changes from that screen to other screens, and SHALL NOT apply `Sync_Group` setting changes to that screen.

---

### Requirement 6: Independent Per-Screen Rotation

**User Story:** As a user, I want each screen that is not in the sync group to rotate independently, so that changing the interval or shuffle mode on one independent screen does not affect other screens.

#### Acceptance Criteria

1. THE `WallpaperManager` SHALL maintain a separate rotation timer for each connected screen whose `isSynced` is `false`.
2. WHEN `rotationIntervalMinutes` is updated for a screen whose `isSynced` is `false`, THE `WallpaperManager` SHALL restart only that screen's rotation timer with the new interval.
3. WHEN `isShuffleMode` is toggled for a screen whose `isSynced` is `false`, THE `WallpaperManager` SHALL rebuild only that screen's `Playlist` order.
4. WHEN `isRotationEnabled` is set to `false` for a screen whose `isSynced` is `false`, THE `WallpaperManager` SHALL stop only that screen's rotation timer without affecting other screens.
5. WHEN `isRotationEnabled` is set to `true` for a screen whose `isSynced` is `false`, THE `WallpaperManager` SHALL start that screen's rotation timer using the interval stored in that screen's `Screen_Config`.
6. THE `WallpaperManager` SHALL NOT share rotation timer state between screens whose `isSynced` is `false`.

---

### Requirement 7: Removal of UI Concern from Playback Engine

**User Story:** As a developer, I want the playback engine to be free of UI-layer concerns, so that `WallpaperManager` is easier to reason about and test.

#### Acceptance Criteria

1. THE `WallpaperManager` SHALL NOT store a `uiScreenID` property or any other reference to which screen the UI is currently displaying.
2. WHEN `MainWindowController` needs the playlist or current file for a specific screen, THE `MainWindowController` SHALL pass the `Screen_Identifier` or `NSScreen` directly to `WallpaperManager` query methods.
3. THE `WallpaperManager` SHALL expose `playlist(for:)`, `currentPlaylistIndex(for:)`, and `currentFile(for:)` methods that accept a `Screen_Identifier` parameter.
4. THE `WallpaperManager` SHALL NOT expose parameterless `playlist`, `currentPlaylistIndex`, or `currentFile` properties that implicitly depend on a UI-selected screen.
5. WHEN `nextWallpaper()` is called without a screen parameter, THE `WallpaperManager` SHALL advance the playlist on all screens that have an active `Playlist`.

---

### Requirement 8: Unified `setFolder` API

**User Story:** As a developer, I want a single `setFolder` entry point that always requires a screen parameter, so that callers cannot accidentally apply a folder to all screens when they intend to target one.

#### Acceptance Criteria

1. THE `WallpaperManager` SHALL expose `setFolder(url:for:config:)` as the only method for assigning a folder to a screen.
2. THE `WallpaperManager` SHALL NOT expose a `setFolder(url:)` method that applies a folder to all screens without an explicit screen parameter.
3. WHEN `setFolder(url:for:config:)` is called, THE `WallpaperManager` SHALL update only the specified screen's `Screen_Config` in the `Screen_Registry`.
4. WHEN `setFolder(url:for:config:)` is called, THE `WallpaperManager` SHALL NOT write any flat global settings keys in `SettingsManager`.
5. WHEN the user wants to apply a folder to all screens, THE `MainWindowController` SHALL call `setFolder(url:for:config:)` once per screen, iterating over `NSScreen.screens`.

---

### Requirement 9: Settings Persistence Round-Trip

**User Story:** As a developer, I want the `Screen_Registry` to serialize and deserialize correctly, so that settings survive app restarts and OS updates without data loss.

#### Acceptance Criteria

1. THE `SettingsManager` SHALL encode the `Screen_Registry` as JSON using `JSONEncoder` and store it under a single `UserDefaults` key.
2. WHEN the `Screen_Registry` is decoded, THE `SettingsManager` SHALL produce `Screen_Config` values that are equal to the originals for all fields.
3. FOR ALL valid `Screen_Config` values, encoding then decoding SHALL produce an equivalent `Screen_Config` (round-trip property).
4. WHEN the stored JSON is missing or malformed, THE `SettingsManager` SHALL return an empty `Screen_Registry` without throwing or crashing.
5. WHEN a `Screen_Config` field is absent from stored JSON (e.g., a field added in a future version), THE `SettingsManager` SHALL substitute the `Default_Config` value for that field (e.g., `isSynced = true` for a record that predates the sync group feature).

---

### Requirement 10: Clean-Slate Initialization

**User Story:** As a user upgrading from the current version, I want the app to start fresh with an empty configuration, so that the new unified settings model is never contaminated by legacy data.

#### Acceptance Criteria

1. WHEN the app launches and the `Screen_Registry` unified `UserDefaults` key is absent, THE `SettingsManager` SHALL delete all of the following legacy keys: `sakurawallpaper_folder_path`, `sakurawallpaper_wallpaper_path`, `sakurawallpaper_screen_folder_configs`, `sakurawallpaper_screen_wallpapers`, `sakurawallpaper_is_folder_mode`, `sakurawallpaper_rotation_interval_minutes`, `sakurawallpaper_is_shuffle_mode`, `sakurawallpaper_is_rotation_enabled`, `sakurawallpaper_include_subfolders`, `sakurawallpaper_new_screen_inheritance_mode`, and `sakurawallpaper_new_screen_inheritance_screen_id`.
2. WHEN the clean-slate initialization runs, THE `SettingsManager` SHALL initialize an empty `Screen_Registry` and persist it under the unified key.
3. WHEN the clean-slate initialization runs, THE `WallpaperManager` SHALL apply the current `New_Screen_Policy` to each currently connected screen, provisioning each one as if it were a brand-new screen with no prior `Screen_Registry` entry.
4. WHEN the `Screen_Registry` unified key is already present at launch, THE `SettingsManager` SHALL NOT run the clean-slate initialization and SHALL NOT delete any keys.

---

### Requirement 11: New Screen Policy Setting

**User Story:** As a user, I want to choose what happens when a new monitor is connected, so that I can match my workflow without reconfiguring every time.

#### Acceptance Criteria

1. THE `SettingsManager` SHALL store `New_Screen_Policy` as a global app-level preference under a dedicated `UserDefaults` key, independent of any per-screen `Screen_Config`.
2. THE `New_Screen_Policy` setting SHALL support exactly three values: `inheritSyncGroup`, `blank`, and `mirrorSpecificScreen`.
3. WHEN `New_Screen_Policy` has never been set, THE `SettingsManager` SHALL return `inheritSyncGroup` as the default value.
4. WHEN `New_Screen_Policy` is `mirrorSpecificScreen`, THE `SettingsManager` SHALL store a companion `newScreenMirrorTargetID: String?` preference containing the `Screen_Identifier` of the target screen to mirror.
5. WHEN `New_Screen_Policy` is not `mirrorSpecificScreen`, THE `SettingsManager` SHALL treat `newScreenMirrorTargetID` as unused and SHALL NOT apply it during new screen provisioning.
6. THE settings UI SHALL allow the user to select any of the three `New_Screen_Policy` values.
7. WHEN the user selects `mirrorSpecificScreen` in the settings UI, THE settings UI SHALL display a picker populated with all known `Screen_Identifier` entries from the `Screen_Registry`, allowing the user to designate the mirror target.
8. WHEN the user selects a mirror target in the settings UI, THE `SettingsManager` SHALL persist the chosen `Screen_Identifier` as `newScreenMirrorTargetID`.
9. THE `New_Screen_Policy` setting SHALL be accessible from the app's preferences UI.

---

### Requirement 12: First-Launch Onboarding

**User Story:** As a new user, I want to be guided through initial setup when I first open the app, so that I can get a wallpaper playing without having to discover the UI myself.

#### Acceptance Criteria

1. WHEN the app launches and `onboardingCompleted` is `false` and the `Screen_Registry` is empty, THE `MainWindowController` SHALL present the existing 3-step onboarding flow (pick file/folder → rotation interval → launch at login).
2. WHEN the user selects a folder during onboarding, THE `MainWindowController` SHALL apply the chosen folder and rotation interval to the primary screen's `Screen_Config` via `WallpaperManager.setFolder(url:for:config:)`.
3. WHEN the user selects a single file during onboarding, THE `MainWindowController` SHALL apply the chosen file to the primary screen's `Screen_Config` via `WallpaperManager.setWallpaper(url:for:)`.
4. WHEN the onboarding result is applied to the primary screen and that screen has `isSynced = true`, THE `WallpaperManager` SHALL propagate the config to all other connected screens in the `Sync_Group` per Requirement 5.
5. WHEN the user skips the file/folder step during onboarding, THE `MainWindowController` SHALL complete the remaining steps and set `onboardingCompleted = true` without applying any wallpaper, leaving all screens in a stopped state.
6. WHEN the onboarding flow completes (regardless of whether a wallpaper was chosen), THE `MainWindowController` SHALL set `onboardingCompleted = true`.
7. WHEN the app launches and `onboardingCompleted` is `true`, THE `MainWindowController` SHALL NOT show the onboarding flow regardless of the state of the `Screen_Registry`.
8. THE `onboardingCompleted` key SHALL NOT be deleted by the clean-slate initialization defined in Requirement 10, so that existing users upgrading to the new version are not shown onboarding again.

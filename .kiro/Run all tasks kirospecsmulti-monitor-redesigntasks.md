# Run all tasks: .kiro/specs/multi-monitor-redesign/tasks.md

Exported: 4/17/2026, 4:29:19 PM

## Steering Documents

**Workspace:**
- product.md
- structure.md
- tech.md

---

**User:**

Run all tasks

---

**Assistant:**

I'll start running all the tasks for the multi-monitor redesign spec. Let me first read the current state of the codebase to understand what we're working with.

Now let me queue all the tasks and start executing them sequentially.

Now let's start executing. Task 1 first:

### Sub-Agent: Spec Task Execution

**Explanation:** Delegating Task 1 to create the Screen_Config data model file and update build configuration.

**Prompt:**

Execute Task 1 from the multi-monitor-redesign spec.

**Spec path**: `.kiro/specs/multi-monitor-redesign/`

**Task**: Define `Screen_Config`, `Screen_Registry`, and `New_Screen_Policy` data models

**Full task details**:
- Create `Screen_Config.swift` at the workspace root (pure Swift, no AppKit import)
- Define `Screen_Config` as a `Codable, Equatable` struct with fields: `folderPath: String?`, `wallpaperPath: String?`, `rotationIntervalMinutes: Int`, `isShuffleMode: Bool`, `isRotationEnabled: Bool`, `includeSubfolders: Bool`, `isFolderMode: Bool`, `isSynced: Bool`
- Add `static let default` with values: `rotationIntervalMinutes = 15`, `isRotationEnabled = true`, `isShuffleMode = false`, `includeSubfolders = false`, `isFolderMode = false`, `folderPath = nil`, `wallpaperPath = nil`, `isSynced = true`
- Implement `CodingKeys` with stable JSON key names; use `decodeIfPresent` with `Screen_Config.default` field values as fallbacks for all fields so records from older app versions decode without crashing
- Define `typealias Screen_Registry = [String: Screen_Config]`
- Define `New_Screen_Policy: String, Codable` enum with cases `inheritSyncGroup`, `blank`, `mirrorSpecificScreen`
- Delete the `ScreenFolderConfig` struct from `SettingsManager.swift` (it is fully replaced by `Screen_Config`)
- Add `Screen_Config.swift` to `build.sh` before `SettingsManager.swift` and to `Package.swift` `sources` array

**Important notes**:
- `Screen_Config.swift` must be pure Swift with NO AppKit import (it goes in the testable SPM core)
- The `CodingKeys` must use stable JSON key names (e.g., snake_case strings)
- All fields must use `decodeIfPresent` with fallback to `Screen_Config.default` values
- In `build.sh`, insert `Screen_Config.swift \` before `SettingsManager.swift \`
- In `Package.swift`, add `"Screen_Config.swift"` to the `sources` array before `"SettingsManager.swift"`
- Do NOT add `Screen_Config.swift` to the `exclude` list in `Package.swift`
- After making changes, run `swift build` to verify compilation

**Current `SettingsManager.swift`** has `ScreenFolderConfig` at the top — remove that struct entirely.

**Current `build.sh`** compile order starts with `SettingsManager.swift` — insert `Screen_Config.swift \` before it.

**Current `Package.swift`** sources array is `["SettingsManager.swift", "MediaType.swift", "PlaylistBuilder.swift"]` — add `"Screen_Config.swift"` before `"SettingsManager.swift"`.


**Response:**

Task 1 is complete. Here's what was done:

**Created `Screen_Config.swift`** (pure Swift, no AppKit import):
- `Screen_Config: Codable, Equatable` struct with all 8 required fields
- `static let default` with the specified default values
- `CodingKeys` with stable snake_case JSON key names
- Custom `init(from:)` using `decodeIfPresent` with `Screen_Config.default` fallbacks for all fields (forward-compatible decoding)
- `typealias Screen_Registry = [String: Screen_Config]`
- `New_Screen_Policy: String, Codable` enum with `inheritSyncGroup`, `blank`, `mirrorSpecificScreen` cases

**Updated `SettingsManager.swift`**:
- Removed `ScreenFolderConfig` struct entirely
- Removed the methods that depended on it (`screenFolderConfigs`, `folderConfig(for:)`, `setFolderConfig(_:for:)`, `clearFolderConfig(for:)`, `clearAllFolderConfigs()`) and updated `hasExistingSetup` accordingly
- Removed the now-unused `screenFolderConfigsKey` constant

**Updated `build.sh`**: Added `Screen_Config.swift \` before `SettingsManager.swift \`

**Updated `Package.swift`**: Added `"Screen_Config.swift"` to the `sources` array before `"SettingsManager.swift"`

**Updated test files** (`UIFunctionalityPreservationTests.swift`, `UIFunctionalityBugConditionTests.swift`): Replaced all `ScreenFolderConfig` references with `Screen_Config` equivalents using direct registry JSON encoding/decoding.

**Verification**: `swift build` passes cleanly. `swift test` shows 28/29 tests passing — the 1 failure (`testSyncAllScreensPreservesManualWallpaperSelection`) is a pre-existing intentional bug-demonstration test that was designed to fail on unfixed code (unchanged behavior from before Task 1).

Task 1 complete. Moving to Task 2.

### Sub-Agent: Spec Task Execution

**Explanation:** Delegating Tasks 2.1 through 2.5 to fully refactor SettingsManager with the new per-screen API.

**Prompt:**

Execute Tasks 2.1 through 2.5 from the multi-monitor-redesign spec. These all modify `SettingsManager.swift`.

**Spec path**: `.kiro/specs/multi-monitor-redesign/`

**Tasks to execute**:

### Task 2.1 — Add new `UserDefaults` keys and remove legacy key constants
- Add private key constants:
  - `screenRegistryKey = "sakurawallpaper_screen_registry"`
  - `newScreenPolicyKey = "sakurawallpaper_new_screen_policy"`
  - `newScreenMirrorTargetKey = "sakurawallpaper_new_screen_mirror_target_id"`
- Remove ALL of these private key constants (they are legacy):
  - `wallpaperKey`
  - `isFolderModeKey`
  - `folderPathKey`
  - `rotationIntervalMinutesKey`
  - `isShuffleModeKey`
  - `isRotationEnabledKey`
  - `includeSubfoldersKey`
  - `screenWallpapersKey`
  - `newScreenInheritanceModeKey`
  - `newScreenInheritanceScreenIdKey`
  - (Note: keep `launchKey`, `pauseWhenInvisibleKey`, `historyKey`, `languageKey`, `onboardingCompletedKey`, `syncDesktopWallpaperKey`)

### Task 2.2 — Implement `screenConfig(for:)` and `setScreenConfig(_:for:)`
- Implement `func screenConfig(for screenID: String) -> Screen_Config`:
  - Read data from `defaults.data(forKey: screenRegistryKey)`
  - Decode as `Screen_Registry` (i.e., `[String: Screen_Config]`) using `JSONDecoder`
  - Return `registry[screenID] ?? Screen_Config.default`
  - On any decode failure: log the error and return `Screen_Config.default`; never throw
- Implement `func setScreenConfig(_ config: Screen_Config, for screenID: String)`:
  - Read current registry from `screenRegistryKey` (decode or use empty dict on failure)
  - Update `registry[screenID] = config`
  - Re-encode as JSON using `JSONEncoder`
  - Write back under `screenRegistryKey` ONLY — do NOT write any flat global keys

### Task 2.3 — Implement `newScreenPolicy` and `newScreenMirrorTargetID` properties
- Add `var newScreenPolicy: New_Screen_Policy` computed property:
  - getter: read raw string from `newScreenPolicyKey`, decode as `New_Screen_Policy`, return `.inheritSyncGroup` if absent/invalid
  - setter: write raw value to `newScreenPolicyKey`
- Add `var newScreenMirrorTargetID: String?` computed property:
  - getter: `defaults.string(forKey: newScreenMirrorTargetKey)`
  - setter: `defaults.set(newValue, forKey: newScreenMirrorTargetKey)`
- Remove `newScreenInheritanceMode` property and `NewScreenInheritanceMode` enum
- Remove `newScreenInheritanceScreenId` property

### Task 2.4 — Remove all legacy global property accessors
Delete ALL of the following from `SettingsManager`:
- `wallpaperPath` computed property (getter + setter)
- `isFolderMode` computed property
- `folderPath` computed property
- `rotationIntervalMinutes` computed property
- `isShuffleMode` computed property
- `isRotationEnabled` computed property
- `includeSubfolders` computed property
- `screenWallpapers` computed property
- `wallpaperURL` computed property (the one using `wallpaperPath`)
- `hasScreenWallpapers` computed property
- `hasExistingSetup` computed property
- `func wallpaperPath(for screen: NSScreen) -> String?`
- `func setWallpaper(path: String?, for screen: NSScreen)`
- `func wallpaperURL(for screen: NSScreen) -> URL?`
- `func clearScreenWallpapers()`

RETAIN these (do NOT delete):
- `launchAtLogin`
- `pauseWhenInvisible`
- `syncDesktopWallpaper`
- `onboardingCompleted`
- `wallpaperHistory`
- `language`
- `static func screenIdentifier(_ screen: NSScreen) -> String`
- `static func screenIdentifier(deviceDescription:name:) -> String`
- `private func addToHistory(_ path: String)`
- `private func updateLoginItem(enabled: Bool)`

### Task 2.5 — Implement `runCleanSlateInitIfNeeded()`
Add this method to `SettingsManager`:
```swift
func runCleanSlateInitIfNeeded() {
    // Guard: if registry already exists, do nothing
    guard defaults.object(forKey: screenRegistryKey) == nil else { return }
    
    // Delete all legacy keys
    let legacyKeys = [
        "sakurawallpaper_folder_path",
        "sakurawallpaper_wallpaper_path",
        "sakurawallpaper_screen_folder_configs",
        "sakurawallpaper_screen_wallpapers",
        "sakurawallpaper_is_folder_mode",
        "sakurawallpaper_rotation_interval_minutes",
        "sakurawallpaper_is_shuffle_mode",
        "sakurawallpaper_is_rotation_enabled",
        "sakurawallpaper_include_subfolders",
        "sakurawallpaper_new_screen_inheritance_mode",
        "sakurawallpaper_new_screen_inheritance_screen_id"
    ]
    for key in legacyKeys {
        defaults.removeObject(forKey: key)
    }
    
    // Initialize empty registry
    let emptyRegistry: Screen_Registry = [:]
    if let data = try? JSONEncoder().encode(emptyRegistry) {
        defaults.set(data, forKey: screenRegistryKey)
    }
}
```

**After all changes, run `swift build` to verify the SPM target compiles. Fix any compile errors.**

**Important**: The `SettingsManager` still imports `Cocoa` because `NSScreen` is used in `screenIdentifier(_:)`. That's fine — keep the import.

**Note on test files**: After removing legacy properties, some existing test files may reference them. Check `Tests/SakuraWallpaperCoreTests/SettingsManagerTests.swift` and update any references to removed properties to use the new `screenConfig(for:)` / `setScreenConfig(_:for:)` API. Also check `UIFunctionalityPreservationTests.swift` and `UIFunctionalityBugConditionTests.swift` for any references to removed properties.


**Response:**

Tasks 2.1–2.5 are complete. Here's a summary of what was done:

**SettingsManager.swift** — fully rewritten:
- **Task 2.1**: Removed all 10 legacy key constants (`wallpaperKey`, `isFolderModeKey`, `folderPathKey`, `rotationIntervalMinutesKey`, `isShuffleModeKey`, `isRotationEnabledKey`, `includeSubfoldersKey`, `screenWallpapersKey`, `newScreenInheritanceModeKey`, `newScreenInheritanceScreenIdKey`). Added 3 new keys: `screenRegistryKey`, `newScreenPolicyKey`, `newScreenMirrorTargetKey`. Retained `launchKey`, `pauseWhenInvisibleKey`, `historyKey`, `languageKey`, `onboardingCompletedKey`, `syncDesktopWallpaperKey`.
- **Task 2.2**: Implemented `screenConfig(for:)` and `setScreenConfig(_:for:)` using JSON encode/decode of `Screen_Registry`. Decode failures return `Screen_Config.default` with a log message.
- **Task 2.3**: Added `newScreenPolicy: New_Screen_Policy` (defaults to `.inheritSyncGroup`) and `newScreenMirrorTargetID: String?`. Removed `NewScreenInheritanceMode` enum, `newScreenInheritanceMode`, and `newScreenInheritanceScreenId`.
- **Task 2.4**: Removed all legacy computed properties and methods: `wallpaperPath`, `isFolderMode`, `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled`, `includeSubfolders`, `screenWallpapers`, `wallpaperURL`, `hasScreenWallpapers`, `hasExistingSetup`, `wallpaperPath(for:)`, `setWallpaper(path:for:)`, `wallpaperURL(for:)`, `clearScreenWallpapers()`. Note: `addToHistory` was changed from `private` to `internal` so call sites can use it.
- **Task 2.5**: Implemented `runCleanSlateInitIfNeeded()` exactly as specified.

**Test files updated** to remove all references to deleted properties:
- `SettingsManagerTests.swift`: replaced `wallpaperPath`-based history test with `addToHistory()`, replaced `includeSubfolders` test with `screenConfig`/`setScreenConfig` tests.
- `UIFunctionalityPreservationTests.swift`: rewrote all tests to use the new `screenConfig`/`setScreenConfig` API instead of legacy flat properties.
- `UIFunctionalityBugConditionTests.swift`: replaced `screenWallpapers` dict access with `screenConfig`/`setScreenConfig` calls.

**Build result**: `swift build` — clean (0 errors, 0 warnings).  
**Test result**: 29/30 pass. The 1 failure (`testSyncAllScreensPreservesManualWallpaperSelection`) is an intentional bug-demonstration test that was already failing before these changes — its final assertion deliberately asserts that unfixed behavior equals fixed behavior to prove the bug exists.

Tasks 2.1–2.5 complete. Marking them done and moving to Task 3.

Now Task 3 — unit tests:

### Sub-Agent: Spec Task Execution

**Explanation:** Delegating Task 3 to create ScreenConfigTests.swift with all required unit tests.

**Prompt:**

Execute Task 3 from the multi-monitor-redesign spec.

**Spec path**: `.kiro/specs/multi-monitor-redesign/`

**Task**: Write unit tests for `SettingsManager` new API (`ScreenConfigTests.swift`)

Create `Tests/SakuraWallpaperCoreTests/ScreenConfigTests.swift` with the following tests. Use the same `setUp`/`tearDown` pattern as `SettingsManagerTests.swift`: unique `suiteName`, injected `UserDefaults`, torn down after each test.

**Required tests** (implement ALL of these):

1. `testDefaultConfigFieldValues` — construct `Screen_Config.default`, assert each field matches exactly:
   - `rotationIntervalMinutes == 15`
   - `isRotationEnabled == true`
   - `isShuffleMode == false`
   - `includeSubfolders == false`
   - `isFolderMode == false`
   - `folderPath == nil`
   - `wallpaperPath == nil`
   - `isSynced == true`

2. `testScreenConfigAllFieldsAccessible` — construct a `Screen_Config` with ALL fields set to non-default values, assert each field is readable:
   - `folderPath = "/tmp/test"`
   - `wallpaperPath = "/tmp/test.jpg"`
   - `rotationIntervalMinutes = 30`
   - `isShuffleMode = true`
   - `isRotationEnabled = false`
   - `includeSubfolders = true`
   - `isFolderMode = true`
   - `isSynced = false`

3. `testMissingFieldsDecodedAsDefaults` — write JSON with `is_synced` key absent, call `screenConfig(for:)`, assert `isSynced == true` (the default). Do this by manually constructing a JSON string that has all fields EXCEPT `is_synced`, encoding it as Data, writing it to `screenRegistryKey` as a registry JSON blob, then calling `screenConfig(for:)`.

4. `testMalformedJSONReturnsDefault` — write garbage bytes (e.g., `Data("not valid json".utf8)`) to `screenRegistryKey`, call `screenConfig(for:)`, assert no crash and result equals `Screen_Config.default`.

5. `testCleanSlateDeletesLegacyKeys` — set ALL of these legacy keys in `UserDefaults`:
   - `"sakurawallpaper_folder_path"` = `"/tmp/folder"`
   - `"sakurawallpaper_wallpaper_path"` = `"/tmp/wallpaper.jpg"`
   - `"sakurawallpaper_screen_folder_configs"` = `Data()`
   - `"sakurawallpaper_screen_wallpapers"` = `["key": "value"]`
   - `"sakurawallpaper_is_folder_mode"` = `true`
   - `"sakurawallpaper_rotation_interval_minutes"` = `30`
   - `"sakurawallpaper_is_shuffle_mode"` = `true`
   - `"sakurawallpaper_is_rotation_enabled"` = `false`
   - `"sakurawallpaper_include_subfolders"` = `true`
   - `"sakurawallpaper_new_screen_inheritance_mode"` = `"primaryScreen"`
   - `"sakurawallpaper_new_screen_inheritance_screen_id"` = `"screen_1"`
   Then call `settings.runCleanSlateInitIfNeeded()`, then assert each of those 11 keys is absent from `defaults.object(forKey:)`.

6. `testCleanSlateCreatesEmptyRegistry` — call `runCleanSlateInitIfNeeded()` on a fresh suite, assert `defaults.data(forKey: "sakurawallpaper_screen_registry")` is non-nil and decodes as an empty `[String: Screen_Config]` dictionary.

7. `testCleanSlateSkippedWhenRegistryPresent` — pre-populate `"sakurawallpaper_screen_registry"` with a known config (encode a registry with one entry), call `runCleanSlateInitIfNeeded()`, assert the registry data is unchanged (same bytes or same decoded value).

8. `testOnboardingKeyNotDeletedByCleanSlate` — set `settings.onboardingCompleted = true`, call `runCleanSlateInitIfNeeded()`, assert `settings.onboardingCompleted == true`.

9. `testNewScreenPolicyDefaultIsInheritSyncGroup` — read `settings.newScreenPolicy` on a fresh `SettingsManager` (no prior value set), assert it equals `.inheritSyncGroup`.

10. `testSetScreenConfigDoesNotWriteLegacyGlobalKeys` — call `settings.setScreenConfig(config, for: "screen_1")` with a fully-populated config (all non-nil/non-default values), then assert ALL of these legacy key strings are absent from `UserDefaults`:
    - `"sakurawallpaper_folder_path"`
    - `"sakurawallpaper_wallpaper_path"`
    - `"sakurawallpaper_screen_folder_configs"`
    - `"sakurawallpaper_screen_wallpapers"`
    - `"sakurawallpaper_is_folder_mode"`
    - `"sakurawallpaper_rotation_interval_minutes"`
    - `"sakurawallpaper_is_shuffle_mode"`
    - `"sakurawallpaper_is_rotation_enabled"`
    - `"sakurawallpaper_include_subfolders"`

**Important notes**:
- The `screenRegistryKey` is `"sakurawallpaper_screen_registry"` — you'll need to use this string directly in tests since it's private in `SettingsManager`
- For `testMissingFieldsDecodedAsDefaults`: construct a JSON string like `{"screen_1":{"folder_path":null,"wallpaper_path":null,"rotation_interval_minutes":15,"is_shuffle_mode":false,"is_rotation_enabled":true,"include_subfolders":false,"is_folder_mode":false}}` (no `is_synced` key), wrap it as the registry JSON, write to `"sakurawallpaper_screen_registry"`, then call `settings.screenConfig(for: "screen_1")`
- After creating the file, run `swift test` to verify all new tests pass

**File to create**: `Tests/SakuraWallpaperCoreTests/ScreenConfigTests.swift`


**Response:**

Task 3 is complete. Created `Tests/SakuraWallpaperCoreTests/ScreenConfigTests.swift` with all 10 required tests.

All 10 new tests pass:
- `testDefaultConfigFieldValues`
- `testScreenConfigAllFieldsAccessible`
- `testMissingFieldsDecodedAsDefaults`
- `testMalformedJSONReturnsDefault`
- `testCleanSlateDeletesLegacyKeys`
- `testCleanSlateCreatesEmptyRegistry`
- `testCleanSlateSkippedWhenRegistryPresent`
- `testOnboardingKeyNotDeletedByCleanSlate`
- `testNewScreenPolicyDefaultIsInheritSyncGroup`
- `testSetScreenConfigDoesNotWriteLegacyGlobalKeys`

The one failing test in the suite (`UIFunctionalityBugConditionTests.testSyncAllScreensPreservesManualWallpaperSelection`) is a pre-existing intentional bug-condition test from a prior spec — it's expected to fail on unfixed code and is unrelated to this task.

Task 3 complete. Moving to Task 4 — property-based tests.

### Sub-Agent: Spec Task Execution

**Explanation:** Delegating Tasks 4.1-4.4 to create ScreenConfigPropertyTests.swift with all four property-based tests.

**Prompt:**

Execute Tasks 4.1–4.4 from the multi-monitor-redesign spec.

**Spec path**: `.kiro/specs/multi-monitor-redesign/`

**Task**: Create `Tests/SakuraWallpaperCoreTests/ScreenConfigPropertyTests.swift` with 4 property-based tests.

**Key requirements**:
- No third-party dependencies — implement a deterministic pseudo-random `Screen_Config` generator seeded from a fixed integer
- Generate at least 100 distinct values per test by varying all fields systematically
- Each test tagged with the specified comment

**Generator design** (implement this in the file):
```swift
/// Deterministic pseudo-random generator seeded from a fixed integer.
/// Uses a simple LCG (linear congruential generator) for reproducibility.
struct DeterministicRNG {
    private var state: UInt64
    
    init(seed: UInt64 = 42) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // LCG parameters from Knuth
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    mutating func nextBool() -> Bool {
        return next() % 2 == 0
    }
    
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
    
    mutating func nextOptionalString(from options: [String?]) -> String? {
        let idx = Int(next() % UInt64(options.count))
        return options[idx]
    }
}
```

**Config generator function**:
```swift
func makeConfig(rng: inout DeterministicRNG) -> Screen_Config {
    let folderOptions: [String?] = [nil, "/tmp/folder1", "/tmp/folder2", "/tmp/wallpapers", "/Users/test/Pictures"]
    let wallpaperOptions: [String?] = [nil, "/tmp/a.jpg", "/tmp/b.mp4", "/tmp/c.png", "/tmp/d.gif"]
    let intervals = [1, 5, 10, 15, 20, 30, 60, 120, 240, 1440]
    
    return Screen_Config(
        folderPath: rng.nextOptionalString(from: folderOptions),
        wallpaperPath: rng.nextOptionalString(from: wallpaperOptions),
        rotationIntervalMinutes: intervals[rng.nextInt(in: 0...intervals.count-1)],
        isShuffleMode: rng.nextBool(),
        isRotationEnabled: rng.nextBool(),
        includeSubfolders: rng.nextBool(),
        isFolderMode: rng.nextBool(),
        isSynced: rng.nextBool()
    )
}
```

**Test 4.1 — Property 1: Screen_Config round-trip**:
```swift
// Feature: multi-monitor-redesign, Property 1: Screen_Config round-trip
func testScreenConfigRoundTrip() {
    var rng = DeterministicRNG(seed: 42)
    let screenRegistryKey = "sakurawallpaper_screen_registry"
    
    for i in 0..<100 {
        let original = makeConfig(rng: &rng)
        let screenID = "screen_\(i)"
        
        // Encode into a fresh registry JSON blob
        let registry: Screen_Registry = [screenID: original]
        guard let data = try? JSONEncoder().encode(registry) else {
            XCTFail("Failed to encode registry at iteration \(i)")
            continue
        }
        
        // Decode back
        guard let decoded = try? JSONDecoder().decode(Screen_Registry.self, from: data),
              let decodedConfig = decoded[screenID] else {
            XCTFail("Failed to decode registry at iteration \(i)")
            continue
        }
        
        XCTAssertEqual(decodedConfig, original, "Round-trip failed at iteration \(i): \(original) != \(decodedConfig)")
    }
}
```

**Test 4.2 — Property 2: Screen_Registry keyed round-trip**:
Use a fresh `UserDefaults` suite per test (the class-level `setUp`/`tearDown` handles this). For each iteration, use the same `settings` instance but with a unique screen ID per iteration (so they don't overwrite each other — or reset between iterations by re-creating the settings manager).

Actually, for simplicity: use a single `settings` instance and unique screen IDs per iteration (e.g., `"screen_\(i)"`). This tests that multiple entries coexist correctly.

```swift
// Feature: multi-monitor-redesign, Property 2: Screen_Registry keyed round-trip
func testScreenRegistryKeyedRoundTrip() {
    var rng = DeterministicRNG(seed: 137)
    
    for i in 0..<100 {
        let screenID = "screen_\(i)"
        let original = makeConfig(rng: &rng)
        
        settings.setScreenConfig(original, for: screenID)
        let retrieved = settings.screenConfig(for: screenID)
        
        XCTAssertEqual(retrieved, original, "Keyed round-trip failed at iteration \(i) for screenID '\(screenID)'")
    }
}
```

**Test 4.3 — Property 3: setScreenConfig does not write legacy global keys**:
```swift
// Feature: multi-monitor-redesign, Property 3: setScreenConfig does not write legacy global keys
func testSetScreenConfigDoesNotWriteLegacyKeys() {
    var rng = DeterministicRNG(seed: 999)
    let legacyKeys = [
        "sakurawallpaper_folder_path",
        "sakurawallpaper_wallpaper_path",
        "sakurawallpaper_screen_folder_configs",
        "sakurawallpaper_screen_wallpapers",
        "sakurawallpaper_is_folder_mode",
        "sakurawallpaper_rotation_interval_minutes",
        "sakurawallpaper_is_shuffle_mode",
        "sakurawallpaper_is_rotation_enabled",
        "sakurawallpaper_include_subfolders"
    ]
    
    for i in 0..<100 {
        let config = makeConfig(rng: &rng)
        settings.setScreenConfig(config, for: "screen_\(i)")
        
        for key in legacyKeys {
            XCTAssertNil(defaults.object(forKey: key),
                "Legacy key '\(key)' should not be written at iteration \(i)")
        }
    }
}
```

**Test 4.4 — Property 4: Sync group config invariant**:
```swift
// Feature: multi-monitor-redesign, Property 4: Sync group config invariant
func testSyncGroupConfigInvariant() {
    var rng = DeterministicRNG(seed: 2024)
    
    for iteration in 0..<100 {
        // Generate 2–5 screens all with isSynced = true
        let screenCount = rng.nextInt(in: 2...5)
        let screenIDs = (0..<screenCount).map { "sync_screen_\(iteration)_\($0)" }
        
        // Generate a base config for the sync group
        var baseConfig = makeConfig(rng: &rng)
        baseConfig.isSynced = true
        
        // Store base config for all screens
        for screenID in screenIDs {
            settings.setScreenConfig(baseConfig, for: screenID)
        }
        
        // Simulate a propagating write: update folderPath, rotationIntervalMinutes,
        // isShuffleMode, isRotationEnabled on one screen and copy to all others
        let newFolderPath: String? = rng.nextBool() ? "/tmp/updated_\(iteration)" : nil
        let newInterval = [5, 10, 15, 30, 60][rng.nextInt(in: 0...4)]
        let newShuffle = rng.nextBool()
        let newRotation = rng.nextBool()
        
        // Apply propagating write to all synced screens
        for screenID in screenIDs {
            var config = settings.screenConfig(for: screenID)
            config.folderPath = newFolderPath
            config.rotationIntervalMinutes = newInterval
            config.isShuffleMode = newShuffle
            config.isRotationEnabled = newRotation
            settings.setScreenConfig(config, for: screenID)
        }
        
        // Assert all synced screens share identical values for the four propagated fields
        for screenID in screenIDs {
            let config = settings.screenConfig(for: screenID)
            XCTAssertEqual(config.folderPath, newFolderPath,
                "Iteration \(iteration): screen '\(screenID)' folderPath should match sync group")
            XCTAssertEqual(config.rotationIntervalMinutes, newInterval,
                "Iteration \(iteration): screen '\(screenID)' rotationIntervalMinutes should match sync group")
            XCTAssertEqual(config.isShuffleMode, newShuffle,
                "Iteration \(iteration): screen '\(screenID)' isShuffleMode should match sync group")
            XCTAssertEqual(config.isRotationEnabled, newRotation,
                "Iteration \(iteration): screen '\(screenID)' isRotationEnabled should match sync group")
        }
    }
}
```

**File structure**: The file should have:
1. `import XCTest` and `@testable import SakuraWallpaperCore`
2. `DeterministicRNG` struct
3. `makeConfig(rng:)` free function (or private method)
4. `ScreenConfigPropertyTests: XCTestCase` class with `setUp`/`tearDown` (same pattern as `ScreenConfigTests.swift`) and the 4 test methods

**After creating the file, run `swift test` to verify all 4 new property tests pass.**

**File to create**: `Tests/SakuraWallpaperCoreTests/ScreenConfigPropertyTests.swift`


**Response:**

Tasks 4.1–4.4 are complete. Created `Tests/SakuraWallpaperCoreTests/ScreenConfigPropertyTests.swift` with:

- `DeterministicRNG` struct (LCG seeded from a fixed integer, no third-party deps)
- `makeConfig(rng:)` free function generating varied `Screen_Config` values
- `ScreenConfigPropertyTests: XCTestCase` with the same `setUp`/`tearDown` isolation pattern as `ScreenConfigTests.swift`
- 4 property tests, each running 100 iterations:
  - **4.1** `testScreenConfigRoundTrip` — JSON encode→decode round-trip (seed 42)
  - **4.2** `testScreenRegistryKeyedRoundTrip` — `setScreenConfig`/`screenConfig` keyed round-trip (seed 137)
  - **4.3** `testSetScreenConfigDoesNotWriteLegacyKeys` — asserts 9 legacy keys stay absent (seed 999)
  - **4.4** `testSyncGroupConfigInvariant` — 2–5 synced screens, propagating write, field equality (seed 2024)

All 4 tests pass: `Executed 4 tests, with 0 failures (0 unexpected) in 1.067 seconds`.

Now Task 5 — checkpoint:

44 tests run, 43 pass. The 1 failure is `testSyncAllScreensPreservesManualWallpaperSelection` — this is an intentional bug-demonstration test from a prior spec that deliberately asserts unfixed behavior equals fixed behavior to prove a bug exists. It's expected to fail on unfixed code and is unrelated to the multi-monitor redesign work. The data layer checkpoint passes cleanly.

Now Task 6 — refactoring `WallpaperManager`. Let me read the current file first.

I have enough context. Let me now read the rest of WallpaperManager and MainWindowController to get the complete picture before delegating.

Now I have the complete picture. Let me delegate the full WallpaperManager refactor (tasks 6.1–6.7) to the subagent.

### Sub-Agent: Spec Task Execution

**Explanation:** Delegating Tasks 6.1-6.7 to fully refactor WallpaperManager.

**Prompt:**

Execute Tasks 6.1 through 6.7 from the multi-monitor-redesign spec. All changes are in `WallpaperManager.swift`.

**Spec path**: `.kiro/specs/multi-monitor-redesign/`

This is a large refactor. Read the full current `WallpaperManager.swift` carefully before making changes.

---

### Task 6.1 — Remove `uiScreenID` and all methods that depend on it

Delete:
- `private var uiScreenID: String?` property
- `func setUIScreen(_ screen: NSScreen?)` method
- `var playlist: [URL]` computed property (the parameterless one using `uiOrFirstPlaylistScreenID()`)
- `var currentPlaylistIndex: Int` computed property (parameterless)
- `var currentFile: URL?` computed property (parameterless)
- `private func uiOrFirstPlaylistScreenID() -> String?` helper
- `func setFolder(url: URL)` — the parameterless overload that iterates all screens
- `func selectPlaylistItem(at index: Int)` — the parameterless overload (keep the `for screen: NSScreen` version)
- In `deinit`: remove `stopRotationTimer()` call if it relied on `uiScreenID` (keep the per-screen timer cleanup)
- In `startRotationTimer()` (the parameterless one): remove the `uiScreenID` branch; just iterate `NSScreen.screens`

Also remove the `var playlistItemCount: Int` computed property (it used `playlist` which is being removed).

---

### Task 6.2 — Add screen-parameterized query methods

Add these public methods:
```swift
func playlist(for screenID: String) -> [URL] {
    return playlistsByScreen[screenID] ?? []
}

func currentPlaylistIndex(for screenID: String) -> Int {
    return playlistIndexesByScreen[screenID] ?? 0
}

func currentFile(for screenID: String) -> URL? {
    return currentFiles[screenID]
}
```

Update `func nextWallpaper()` (parameterless) to iterate `playlistsByScreen.keys` and advance all screens that have a non-empty playlist, WITHOUT referencing `uiScreenID`:
```swift
@objc func nextWallpaper() {
    for id in playlistsByScreen.keys {
        nextWallpaper(forScreenID: id)
    }
}
```

---

### Task 6.3 — Add sync group timer coordination

Rename `rotationTimersByScreen` to `independentTimersByScreen` throughout the file.

Add these private properties:
```swift
private var syncGroupTimer: Timer?
private var syncGroupPlaylistIndex: Int = 0
```

Add this public method:
```swift
func setSynced(_ synced: Bool, for screen: NSScreen) {
    let id = SettingsManager.screenIdentifier(screen)
    var config = SettingsManager.shared.screenConfig(for: id)
    
    if synced {
        config.isSynced = true
        // Copy config from an existing synced screen if one exists
        let syncedScreenIDs = NSScreen.screens
            .map { SettingsManager.screenIdentifier($0) }
            .filter { SettingsManager.shared.screenConfig(for: $0).isSynced && $0 != id }
        if let sourceID = syncedScreenIDs.first {
            let sourceConfig = SettingsManager.shared.screenConfig(for: sourceID)
            config.folderPath = sourceConfig.folderPath
            config.rotationIntervalMinutes = sourceConfig.rotationIntervalMinutes
            config.isShuffleMode = sourceConfig.isShuffleMode
            config.isRotationEnabled = sourceConfig.isRotationEnabled
        }
        // Align playlist index to sync group
        if let folderPath = config.folderPath,
           FileManager.default.fileExists(atPath: folderPath) {
            let folderURL = URL(fileURLWithPath: folderPath)
            if let files = try? PlaylistBuilder.collectMediaFiles(in: folderURL, includeSubfolders: config.includeSubfolders) {
                playlistsByScreen[id] = files
                let alignedIndex = min(syncGroupPlaylistIndex, max(0, files.count - 1))
                playlistIndexesByScreen[id] = alignedIndex
                if let file = files.isEmpty ? nil : files[alignedIndex] {
                    currentFiles[id] = file
                    createOrUpdatePlayer(for: screen, url: file)
                }
            }
        }
        SettingsManager.shared.setScreenConfig(config, for: id)
        // Stop independent timer, ensure sync group timer is running
        stopIndependentTimer(forScreenID: id)
        startSyncGroupTimerIfNeeded()
    } else {
        config.isSynced = false
        SettingsManager.shared.setScreenConfig(config, for: id)
        // Start independent timer for this screen
        startIndependentTimer(forScreenID: id)
        // Stop sync group timer if no more synced screens
        let remainingSynced = NSScreen.screens
            .map { SettingsManager.screenIdentifier($0) }
            .filter { SettingsManager.shared.screenConfig(for: $0).isSynced }
        if remainingSynced.isEmpty {
            stopSyncGroupTimer()
        }
    }
}
```

Add these private helpers:
```swift
private func startSyncGroupTimerIfNeeded() {
    guard syncGroupTimer == nil else { return }
    // Find interval from any synced screen
    let syncedIDs = NSScreen.screens
        .map { SettingsManager.screenIdentifier($0) }
        .filter { SettingsManager.shared.screenConfig(for: $0).isSynced }
    guard let firstID = syncedIDs.first else { return }
    let config = SettingsManager.shared.screenConfig(for: firstID)
    guard config.isRotationEnabled else { return }
    let interval = TimeInterval(max(1, config.rotationIntervalMinutes) * 60)
    syncGroupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        self?.advanceSyncGroup()
    }
}

private func stopSyncGroupTimer() {
    syncGroupTimer?.invalidate()
    syncGroupTimer = nil
}

private func advanceSyncGroup() {
    syncGroupPlaylistIndex += 1
    let syncedScreens = NSScreen.screens.filter {
        SettingsManager.shared.screenConfig(for: SettingsManager.screenIdentifier($0)).isSynced
    }
    for screen in syncedScreens {
        let id = SettingsManager.screenIdentifier(screen)
        nextWallpaper(forScreenID: id)
        syncGroupPlaylistIndex = playlistIndexesByScreen[id] ?? syncGroupPlaylistIndex
    }
}

private func startIndependentTimer(forScreenID id: String) {
    stopIndependentTimer(forScreenID: id)
    guard let list = playlistsByScreen[id], list.count > 1 else { return }
    let config = SettingsManager.shared.screenConfig(for: id)
    guard config.isRotationEnabled else { return }
    let interval = TimeInterval(max(1, config.rotationIntervalMinutes) * 60)
    independentTimersByScreen[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        self?.nextWallpaper(forScreenID: id)
    }
}

private func stopIndependentTimer(forScreenID id: String) {
    independentTimersByScreen[id]?.invalidate()
    independentTimersByScreen.removeValue(forKey: id)
}
```

Update `deinit` to also call `stopSyncGroupTimer()`.

---

### Task 6.4 — Rewrite `screensChanged()` using the new `Screen_Registry` API

Replace the entire `screensChanged()` method body with this simplified logic:

```swift
@objc private func screensChanged() {
    let currentScreenIds = Set(NSScreen.screens.map { SettingsManager.screenIdentifier($0) })
    let existingIds = Set(players.keys)
    let removedIds = existingIds.subtracting(currentScreenIds)

    // Step 1 & 2: Tear down removed screens
    for removedId in removedIds {
        players[removedId]?.cleanup()
        players.removeValue(forKey: removedId)
        currentFiles.removeValue(forKey: removedId)
        playlistsByScreen.removeValue(forKey: removedId)
        playlistIndexesByScreen.removeValue(forKey: removedId)
        stopIndependentTimer(forScreenID: removedId)
        pausedScreens.remove(removedId)
        clearTransientDesktopSnapshot(for: removedId)
        // If this was the last synced screen, stop sync group timer
        let remainingSynced = NSScreen.screens
            .map { SettingsManager.screenIdentifier($0) }
            .filter { SettingsManager.shared.screenConfig(for: $0).isSynced }
        if remainingSynced.isEmpty {
            stopSyncGroupTimer()
        }
    }

    // Step 3: Post notification if any screen was removed
    if !removedIds.isEmpty {
        NotificationCenter.default.post(name: WallpaperManager.screenListDidChangeNotification, object: nil)
    }

    // Step 4: Provision new screens
    for screen in NSScreen.screens {
        let id = SettingsManager.screenIdentifier(screen)
        if players[id] != nil { continue }

        // Check if this screen has a prior registry entry
        let hasRegistryEntry = hasScreenRegistryEntry(for: id)
        let config: Screen_Config

        if hasRegistryEntry {
            // Restore exactly from registry
            config = SettingsManager.shared.screenConfig(for: id)
        } else {
            // Apply New_Screen_Policy
            config = provisionNewScreen(id: id, screen: screen)
        }

        // Build playlist or set wallpaper based on config
        if let folderPath = config.folderPath,
           FileManager.default.fileExists(atPath: folderPath) {
            let folderURL = URL(fileURLWithPath: folderPath)
            setFolder(url: folderURL, for: screen, config: config)
        } else if let wallpaperPath = config.wallpaperPath,
                  FileManager.default.fileExists(atPath: wallpaperPath) {
            let wallpaperURL = URL(fileURLWithPath: wallpaperPath)
            setWallpaper(url: wallpaperURL, for: screen)
        }
        // else: leave stopped
    }

    if isPaused {
        pauseAll()
    } else {
        showAll()
    }

    // Step 5: Resize existing players whose frame changed
    for screen in NSScreen.screens {
        let id = SettingsManager.screenIdentifier(screen)
        guard let player = players[id] else { continue }
        if player.window?.frame != screen.frame {
            player.resize(to: screen)
        }
    }
}

private func hasScreenRegistryEntry(for screenID: String) -> Bool {
    // A screen has a registry entry if its config differs from the default
    // OR if the registry key exists with an entry for this screen.
    // We check by reading the raw registry data.
    guard let data = UserDefaults.standard.data(forKey: "sakurawallpaper_screen_registry"),
          let registry = try? JSONDecoder().decode(Screen_Registry.self, from: data) else {
        return false
    }
    return registry[screenID] != nil
}

private func provisionNewScreen(id: String, screen: NSScreen) -> Screen_Config {
    let policy = SettingsManager.shared.newScreenPolicy
    var config: Screen_Config

    switch policy {
    case .inheritSyncGroup:
        let syncedIDs = NSScreen.screens
            .map { SettingsManager.screenIdentifier($0) }
            .filter { $0 != id && SettingsManager.shared.screenConfig(for: $0).isSynced }
        if let sourceID = syncedIDs.first {
            config = SettingsManager.shared.screenConfig(for: sourceID)
            config.isSynced = true
        } else {
            config = Screen_Config.default
            config.isSynced = false
        }

    case .blank:
        config = Screen_Config.default
        config.isSynced = false

    case .mirrorSpecificScreen:
        if let targetID = SettingsManager.shared.newScreenMirrorTargetID,
           targetID != id,
           NSScreen.screens.contains(where: { SettingsManager.screenIdentifier($0) == targetID }) {
            config = SettingsManager.shared.screenConfig(for: targetID)
            config.isSynced = false
        } else {
            // Fall back to inheritSyncGroup
            let syncedIDs = NSScreen.screens
                .map { SettingsManager.screenIdentifier($0) }
                .filter { $0 != id && SettingsManager.shared.screenConfig(for: $0).isSynced }
            if let sourceID = syncedIDs.first {
                config = SettingsManager.shared.screenConfig(for: sourceID)
                config.isSynced = true
            } else {
                config = Screen_Config.default
                config.isSynced = false
            }
        }
    }

    SettingsManager.shared.setScreenConfig(config, for: id)
    return config
}
```

Delete these now-unused helpers:
- `syncPlaylistIndex(for:screenID:folderPath:)`
- `inheritanceSourceScreen(excluding:)`
- `primaryScreenForInheritance(excluding:)`
- `hasExistingConfig(for:)`

---

### Task 6.5 — Rewrite `setFolder(url:for:config:)` to use `Screen_Config` and propagate sync

Replace the `setFolder(url:for:config:)` method signature and body:

```swift
func setFolder(url: URL, for screen: NSScreen, config: Screen_Config) {
    let id = SettingsManager.screenIdentifier(screen)
    let token = PerformanceMonitor.shared.begin("playlist.build")

    do {
        let files = try PlaylistBuilder.collectMediaFiles(in: url, includeSubfolders: config.includeSubfolders)
        playlistsByScreen[id] = files
        playlistIndexesByScreen[id] = 0
        PerformanceMonitor.shared.end(token, extra: "screen=\(id) count=\(files.count) recursive=\(config.includeSubfolders)")

        var updatedConfig = config
        updatedConfig.folderPath = url.path
        updatedConfig.isFolderMode = true
        SettingsManager.shared.setScreenConfig(updatedConfig, for: id)
        SettingsManager.shared.addToHistory(url.path)

        // Propagate to all other synced screens if this screen is synced
        if updatedConfig.isSynced {
            let syncedScreens = NSScreen.screens.filter {
                let sid = SettingsManager.screenIdentifier($0)
                return sid != id && SettingsManager.shared.screenConfig(for: sid).isSynced
            }
            for syncedScreen in syncedScreens {
                let sid = SettingsManager.screenIdentifier(syncedScreen)
                var syncedConfig = SettingsManager.shared.screenConfig(for: sid)
                syncedConfig.folderPath = updatedConfig.folderPath
                syncedConfig.rotationIntervalMinutes = updatedConfig.rotationIntervalMinutes
                syncedConfig.isShuffleMode = updatedConfig.isShuffleMode
                syncedConfig.isRotationEnabled = updatedConfig.isRotationEnabled
                SettingsManager.shared.setScreenConfig(syncedConfig, for: sid)
                // Rebuild playlist for synced screen
                if let syncedFiles = try? PlaylistBuilder.collectMediaFiles(in: url, includeSubfolders: syncedConfig.includeSubfolders) {
                    playlistsByScreen[sid] = syncedFiles
                    playlistIndexesByScreen[sid] = 0
                    if let firstURL = syncedFiles.first {
                        currentFiles[sid] = firstURL
                        createOrUpdatePlayer(for: syncedScreen, url: firstURL)
                    }
                }
            }
        }

        if let firstURL = files.first {
            currentFiles[id] = firstURL
            createOrUpdatePlayer(for: screen, url: firstURL)
            syncCurrentWallpaperToSystemDesktop(for: screen)
            if isPaused || isPausedInternally {
                players[id]?.pausePlayback()
                players[id]?.window?.orderOut(nil)
            }
        } else {
            stopWallpaper(for: screen)
        }

        startKeepVisibleTimer()
        // Start appropriate timer
        if updatedConfig.isSynced {
            startSyncGroupTimerIfNeeded()
        } else {
            startIndependentTimer(forScreenID: id)
        }
        NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
    } catch {
        PerformanceMonitor.shared.end(token, extra: "screen=\(id) failed=\(error.localizedDescription)")
        print("Failed to read directory: \(error)")
    }
}
```

Also update `startRotationTimer(forScreenID:)` to use `SettingsManager.shared.screenConfig(for: id)` instead of `folderConfig(forScreenID:)`.

Update `nextWallpaper(forScreenID:)` to use `SettingsManager.shared.screenConfig(for: id)` instead of `folderConfig(forScreenID:)`.

Delete the `private func folderConfig(forScreenID:)` helper (it used the old API).

---

### Task 6.6 — Update `setWallpaper(url:for:)` and `stopWallpaper(for:)` to use `Screen_Config`

Replace `setWallpaper(url:for:)`:
```swift
func setWallpaper(url: URL, for screen: NSScreen) {
    let id = SettingsManager.screenIdentifier(screen)
    stopIndependentTimer(forScreenID: id)
    playlistsByScreen.removeValue(forKey: id)
    playlistIndexesByScreen.removeValue(forKey: id)

    players[id]?.cleanup()
    players.removeValue(forKey: id)

    var config = SettingsManager.shared.screenConfig(for: id)
    config.wallpaperPath = url.path
    config.folderPath = nil
    config.isFolderMode = false
    SettingsManager.shared.setScreenConfig(config, for: id)
    SettingsManager.shared.addToHistory(url.path)
    currentFiles[id] = url

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        guard let self else { return }
        self.createOrUpdatePlayer(for: screen, url: url)
        self.syncCurrentWallpaperToSystemDesktop(for: screen)
        if self.isPaused {
            self.players[id]?.pausePlayback()
            self.players[id]?.window?.orderOut(nil)
        }
        self.startKeepVisibleTimer()
    }
}
```

Replace `stopWallpaper(for:)`:
```swift
func stopWallpaper(for screen: NSScreen) {
    let id = SettingsManager.screenIdentifier(screen)
    players[id]?.cleanup()
    players.removeValue(forKey: id)
    currentFiles.removeValue(forKey: id)
    pausedScreens.remove(id)
    playlistsByScreen.removeValue(forKey: id)
    playlistIndexesByScreen.removeValue(forKey: id)
    stopIndependentTimer(forScreenID: id)
    clearTransientDesktopSnapshot(for: id)
    SettingsManager.shared.setScreenConfig(Screen_Config.default, for: id)
    // Restore original system desktop wallpaper for this screen
    restoreOriginalDesktop(for: screen, screenID: id)
    originalDesktopURLsByScreen.removeValue(forKey: id)
    if players.isEmpty { stopKeepVisibleTimer() }
}
```

Also update `setWallpaper(url:)` (the all-screens version) to remove legacy `SettingsManager` calls:
```swift
func setWallpaper(url: URL) {
    let screens = NSScreen.screens
    stopAll()
    for screen in screens {
        let id = SettingsManager.screenIdentifier(screen)
        var config = Screen_Config.default
        config.wallpaperPath = url.path
        config.isFolderMode = false
        SettingsManager.shared.setScreenConfig(config, for: id)
        currentFiles[id] = url
    }
    SettingsManager.shared.addToHistory(url.path)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.createAllPlayers(for: screens)
        self?.startKeepVisibleTimer()
    }
}
```

Also update `urlForScreen(_:)` to use the new API:
```swift
private func urlForScreen(_ screen: NSScreen) -> URL? {
    let id = SettingsManager.screenIdentifier(screen)
    if let currentURL = currentFiles[id], FileManager.default.fileExists(atPath: currentURL.path) {
        return currentURL
    }
    let config = SettingsManager.shared.screenConfig(for: id)
    if let path = config.wallpaperPath {
        return URL(fileURLWithPath: path)
    }
    return nil
}
```

---

### Task 6.7 — Add `restoreAllScreens()` method

Add this public method:
```swift
func restoreAllScreens() {
    for screen in NSScreen.screens {
        let id = SettingsManager.screenIdentifier(screen)
        let config = SettingsManager.shared.screenConfig(for: id)

        if let folderPath = config.folderPath,
           FileManager.default.fileExists(atPath: folderPath) {
            let folderURL = URL(fileURLWithPath: folderPath)
            setFolder(url: folderURL, for: screen, config: config)
        } else if let wallpaperPath = config.wallpaperPath,
                  FileManager.default.fileExists(atPath: wallpaperPath) {
            let wallpaperURL = URL(fileURLWithPath: wallpaperPath)
            setWallpaper(url: wallpaperURL, for: screen)
        }
        // else: leave stopped
    }
}
```

---

### Additional cleanup

After all the above changes, also update `startRotationTimer(forScreenID:)` to use `SettingsManager.shared.screenConfig(for: id)`:
```swift
private func startRotationTimer(forScreenID id: String) {
    stopIndependentTimer(forScreenID: id)
    guard let list = playlistsByScreen[id], list.count > 1 else { return }
    let config = SettingsManager.shared.screenConfig(for: id)
    guard config.isRotationEnabled else { return }
    let interval = TimeInterval(max(1, config.rotationIntervalMinutes) * 60)
    independentTimersByScreen[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        self?.nextWallpaper(forScreenID: id)
    }
}
```

Update `nextWallpaper(forScreenID:)` to use `SettingsManager.shared.screenConfig(for: id)`:
```swift
private func nextWallpaper(forScreenID id: String) {
    guard let list = playlistsByScreen[id], !list.isEmpty else { return }
    let config = SettingsManager.shared.screenConfig(for: id)
    guard config.isRotationEnabled else { return }

    let token = PerformanceMonitor.shared.begin("wallpaper.switch")
    let currentIndex = playlistIndexesByScreen[id] ?? 0
    let nextIndex = PlaylistBuilder.nextIndex(
        currentIndex: currentIndex,
        itemCount: list.count,
        shuffle: config.isShuffleMode
    )
    playlistIndexesByScreen[id] = nextIndex

    let nextURL = list[nextIndex]
    currentFiles[id] = nextURL
    if let player = players[id] {
        player.updateMedia(url: nextURL)
        if isPaused || isPausedInternally {
            player.pausePlayback()
        }
    }
    if let screen = screen(forScreenID: id) {
        syncCurrentWallpaperToSystemDesktop(for: screen)
    }
    PerformanceMonitor.shared.end(token, extra: "screen=\(id) file=\(nextURL.lastPathComponent)")
    NotificationCenter.default.post(name: WallpaperManager.didRotateNotification, object: nil)
}
```

Also update `stopAll()` to remove legacy `SettingsManager` calls and add `stopSyncGroupTimer()`:
```swift
func stopAll() {
    isPaused = false
    isPausedInternally = false
    stopKeepVisibleTimer()
    stopSyncGroupTimer()
    for (_, timer) in independentTimersByScreen { timer.invalidate() }
    independentTimersByScreen.removeAll()
    players.values.forEach { $0.cleanup() }
    players.removeAll()
    currentFiles.removeAll()
    pausedScreens.removeAll()
    playlistsByScreen.removeAll()
    playlistIndexesByScreen.removeAll()
    clearAllTransientDesktopSnapshots()
    // Restore original system desktop wallpapers for all screens
    for screen in NSScreen.screens {
        let id = SettingsManager.screenIdentifier(screen)
        restoreOriginalDesktop(for: screen, screenID: id)
    }
    originalDesktopURLsByScreen.removeAll()
}
```

Also update `startRotationTimer()` (the parameterless version) to not reference `uiScreenID`:
```swift
func startRotationTimer() {
    for screen in NSScreen.screens {
        let id = SettingsManager.screenIdentifier(screen)
        let config = SettingsManager.shared.screenConfig(for: id)
        if config.isSynced {
            startSyncGroupTimerIfNeeded()
        } else {
            startIndependentTimer(forScreenID: id)
        }
    }
}
```

---

**After all changes, verify the app compiles with `./build.sh`**. Fix any compile errors. The key things to watch for:
1. Any remaining references to `ScreenFolderConfig` — replace with `Screen_Config`
2. Any remaining references to `rotationTimersByScreen` — replace with `independentTimersByScreen`
3. Any remaining references to `uiScreenID` — remove
4. Any remaining references to deleted `SettingsManager` methods (`folderConfig(for:)`, `setFolderConfig`, `clearFolderConfig`, `wallpaperPath(for:)`, `setWallpaper(path:for:)`, `clearScreenWallpapers`, `clearAllFolderConfigs`, `isFolderMode`, `folderPath`, `rotationIntervalMinutes`, `isShuffleMode`, `isRotationEnabled`, `includeSubfolders`, `wallpaperPath`, `wallpaperURL`, `screenFolderConfigs`, `hasExistingSetup`, `newScreenInheritanceMode`, `newScreenInheritanceScreenId`) — these are all deleted from SettingsManager

Note: `AppDelegate.swift` and `MainWindowController.swift` will have compile errors after this change — that's expected and will be fixed in Tasks 7 and 8. Focus on making `WallpaperManager.swift` itself correct.

Run `./build.sh` to check for errors. The build will fail due to AppDelegate/MainWindowController references to deleted APIs — that's OK for now. What matters is that WallpaperManager.swift itself has no errors (you can verify by checking if the errors are only in AppDelegate.swift and MainWindowController.swift).


**Response:**

Tasks 6.1 through 6.7 are complete. Here's a summary of what was done to `WallpaperManager.swift`:

**Task 6.1** — Removed `uiScreenID`, `setUIScreen` (replaced with no-op stub for call-site compatibility until Tasks 7 & 8), parameterless `playlist`/`currentPlaylistIndex`/`currentFile` computed properties, `playlistItemCount`, `uiOrFirstPlaylistScreenID()`, parameterless `setFolder(url:)`, parameterless `selectPlaylistItem(at:)`. Renamed `rotationTimersByScreen` → `independentTimersByScreen`. Fixed `deinit` to use `stopSyncGroupTimer()` + iterate `independentTimersByScreen`.

**Task 6.2** — Added `playlist(for:)`, `currentPlaylistIndex(for:)`, `currentFile(for:)`. Updated parameterless `nextWallpaper()` to iterate `playlistsByScreen.keys` without `uiScreenID`.

**Task 6.3** — Added `syncGroupTimer`, `syncGroupPlaylistIndex` properties. Added `setSynced(_:for:)`, `startSyncGroupTimerIfNeeded()`, `stopSyncGroupTimer()`, `advanceSyncGroup()`, `startIndependentTimer(forScreenID:)`, `stopIndependentTimer(forScreenID:)`. Updated `deinit` to call `stopSyncGroupTimer()`.

**Task 6.4** — Rewrote `screensChanged()` using `Screen_Registry` API with `hasScreenRegistryEntry(for:)` and `provisionNewScreen(id:screen:)`. Deleted `syncPlaylistIndex(for:screenID:folderPath:)`, `inheritanceSourceScreen(excluding:)`, `primaryScreenForInheritance(excluding:)`, `hasExistingConfig(for:)`.

**Task 6.5** — Rewrote `setFolder(url:for:config:)` to accept `Screen_Config`, use `setScreenConfig`, propagate to synced screens, and start the appropriate timer (sync group or independent). Deleted `folderConfig(forScreenID:)`.

**Task 6.6** — Replaced `setWallpaper(url:)` (all-screens), `setWallpaper(url:for:)`, and `stopWallpaper(for:)` to use `Screen_Config` API. Updated `urlForScreen(_:)` to use `screenConfig(for:)`. Updated `stopAll()` to use `stopSyncGroupTimer()` + `independentTimersByScreen`. Updated `startRotationTimer(forScreenID:)` and `nextWallpaper(forScreenID:)` to use `SettingsManager.shared.screenConfig(for:)`.

**Task 6.7** — Added `restoreAllScreens()` method.

**Build status**: `WallpaperManager.swift` compiles with zero errors (one pre-existing deprecation warning for `copyCGImage`). All remaining build errors are in `AppDelegate.swift` and `MainWindowController.swift` as expected — those will be fixed in Tasks 7 and 8. All 43 pure-logic tests pass; the 1 failing test (`UIFunctionalityBugConditionTests.testSyncAllScreensPreservesManualWallpaperSelection`) is a pre-existing bug condition exploration test that was already failing before these changes.

Tasks 6.1–6.7 complete. Marking them done.

Now Task 7 — update AppDelegate:

### Sub-Agent: Spec Task Execution

**Explanation:** Delegating Task 7 to update AppDelegate to use the new clean-slate init and remove all legacy SettingsManager references.

**Prompt:**

Execute Task 7 from the multi-monitor-redesign spec.

**Spec path**: `.kiro/specs/multi-monitor-redesign/`

**Task**: Update `AppDelegate` — replace restoration loop with clean-slate init

Read the full current `AppDelegate.swift` before making changes.

**Changes required**:

### 1. Replace `applicationDidFinishLaunching` restoration block

Replace the entire restoration block (everything from `let screenFolderConfigs = ...` through `mainWindow.runOnboardingIfNeeded()`) with:
```swift
SettingsManager.shared.runCleanSlateInitIfNeeded()
wallpaperManager.restoreAllScreens()
mainWindow.runOnboardingIfNeeded()
```

### 2. Update `stopWallpaper()` @objc method

Replace the body of `@objc func stopWallpaper()` with:
```swift
@objc func stopWallpaper() {
    wallpaperManager.stopAll()
    for screen in NSScreen.screens {
        let id = SettingsManager.screenIdentifier(screen)
        SettingsManager.shared.setScreenConfig(Screen_Config.default, for: id)
    }
    mainWindow.updateUI()
    rebuildRecentMenu()
}
```

### 3. Update `switchToRecent(_:)` method

Replace the body of `@objc func switchToRecent(_ sender: NSMenuItem)` with:
```swift
@objc func switchToRecent(_ sender: NSMenuItem) {
    guard let path = sender.representedObject as? String else { return }
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return }
    let url = URL(fileURLWithPath: path)
    
    if isDir.boolValue {
        // Apply folder to all screens
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            var config = SettingsManager.shared.screenConfig(for: id)
            config.folderPath = url.path
            config.isFolderMode = true
            wallpaperManager.setFolder(url: url, for: screen, config: config)
        }
    } else {
        // Apply single wallpaper to all screens
        for screen in NSScreen.screens {
            let id = SettingsManager.screenIdentifier(screen)
            var config = SettingsManager.shared.screenConfig(for: id)
            config.wallpaperPath = url.path
            config.isFolderMode = false
            config.isRotationEnabled = false
            config.isShuffleMode = false
            SettingsManager.shared.setScreenConfig(config, for: id)
        }
        wallpaperManager.setWallpaper(url: url)
    }
    
    mainWindow.updateUI()
    rebuildRecentMenu()
}
```

### 4. Update `rebuildRecentMenu()` to remove legacy SettingsManager references

In `rebuildRecentMenu()`, replace the section that checks `isFolderMode`/`wallpaperPath`/`folderPath` for menu item state with a simpler check using `wallpaperHistory`:
```swift
// Replace the state-checking block:
if SettingsManager.shared.isFolderMode {
    if path == SettingsManager.shared.folderPath {
        item.state = .on
    }
} else {
    if path == SettingsManager.shared.wallpaperPath {
        item.state = .on
    }
}
// With: (just remove the state check entirely, or use a simple active-screen check)
// Check if this path is currently active on any screen
let isActive = NSScreen.screens.contains { screen in
    let id = SettingsManager.screenIdentifier(screen)
    let config = SettingsManager.shared.screenConfig(for: id)
    return config.folderPath == path || config.wallpaperPath == path
}
item.state = isActive ? .on : .off
```

### 5. Update `updateAutoPauseItem()` to remove legacy SettingsManager references

Replace the section that reads `screenFolderConfigs`, `isFolderMode`, `folderPath`, `isShuffleMode`, `isRotationEnabled` with reads from `screenConfig(for:)` for the first active screen:

```swift
private func updateAutoPauseItem() {
    autoPauseItem.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
    if !wallpaperManager.isActive {
        statusMenuItem.title = "menu.status".localized("ui.notSet".localized)
    } else {
        let stateLabel: String
        switch wallpaperManager.playbackStatus {
        case .stopped:
            stateLabel = "ui.notSet".localized
        case .playing:
            stateLabel = "ui.playing".localized
        case .pausedManual:
            stateLabel = "ui.pausedManual".localized
        case .pausedAuto:
            stateLabel = "ui.pausedAuto".localized
        }
        
        // Get config from first active screen
        let firstActiveScreen = NSScreen.screens.first
        let firstID = firstActiveScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
        let config = SettingsManager.shared.screenConfig(for: firstID)
        
        let isRotating = config.isFolderMode && config.isRotationEnabled
        let shuffleIcon = (isRotating && config.isShuffleMode) ? "🔀 " : ""
        
        if isRotating, let folderPath = config.folderPath {
            let folderName = (folderPath as NSString).lastPathComponent
            statusMenuItem.title = "\(shuffleIcon)\("menu.status.rotating".localized(folderName)) (\(stateLabel))"
        } else if let url = firstActiveScreen.flatMap({ wallpaperManager.currentFile(for: SettingsManager.screenIdentifier($0)) }) {
            let fileName = url.lastPathComponent
            statusMenuItem.title = "menu.status.file".localized(fileName) + " (\(stateLabel))"
        } else {
            statusMenuItem.title = "menu.status".localized(stateLabel)
        }
    }
}
```

**After making all changes, run `./build.sh` to check compilation.** Fix any remaining compile errors in `AppDelegate.swift`. The goal is to have AppDelegate compile cleanly. `MainWindowController.swift` may still have errors — that's OK for now (Task 8 handles it).

Note: `wallpaperManager.setUIScreen` calls in `MainWindowController.swift` are still present as a no-op stub in `WallpaperManager` — they'll be removed in Task 8.


**Response:**

Task 7 is complete. All 5 changes were applied to `AppDelegate.swift` and it compiles without errors:

1. **`applicationDidFinishLaunching`** — replaced the entire multi-step restoration loop (`screenFolderConfigs`, `globalURL`, `globalFolderURL`, per-screen fallback chain) with the clean three-liner: `runCleanSlateInitIfNeeded()` → `restoreAllScreens()` → `runOnboardingIfNeeded()`.

2. **`stopWallpaper()`** — replaced legacy `SettingsManager` property writes (`wallpaperPath = nil`, `clearScreenWallpapers()`, `isFolderMode = false`, `folderPath = nil`, `clearAllFolderConfigs()`) with a loop that calls `setScreenConfig(Screen_Config.default, for: id)` for each connected screen.

3. **`switchToRecent(_:)`** — replaced the parameterless `setFolder(url:)` call and legacy property writes with per-screen loops using `setFolder(url:for:config:)` for folders and `setScreenConfig` for single wallpapers.

4. **`rebuildRecentMenu()`** — replaced the `isFolderMode`/`wallpaperPath`/`folderPath` state check with a multi-screen `contains` check against `screenConfig(for:).folderPath` and `.wallpaperPath`.

5. **`updateAutoPauseItem()`** — replaced reads of `screenFolderConfigs`, `isFolderMode`, `folderPath`, `isShuffleMode`, `isRotationEnabled`, and the parameterless `wallpaperManager.currentFile` with reads from `screenConfig(for:)` on the first active screen and `wallpaperManager.currentFile(for:)`.

Build output: `AppDelegate.swift` — zero errors. All remaining errors are in `MainWindowController.swift` (deferred to Task 8), as expected.

Task 7 complete. Moving to Task 8 — the largest UI update.

### Sub-Agent: Spec Task Execution

**Explanation:** Delegating Tasks 8.1-8.7 to fully update MainWindowController: remove setUIScreen, add sync checkbox, replace all legacy SettingsManager reads, update action handlers, replace inheritSourcePopUp with New_Screen_Policy picker, update applyToAllScreens, and update onboarding.

**Prompt:**

Execute Tasks 8.1 through 8.7 from the multi-monitor-redesign spec. All changes are in `MainWindowController.swift`.

**Spec path**: `.kiro/specs/multi-monitor-redesign/`

Read the full current `MainWindowController.swift` before making changes. This is a large refactor.

---

### Task 8.1 — Remove `setUIScreen` calls and update screen selection

- Delete `wallpaperManager.setUIScreen(selectedScreen)` from `setupUI()` (line near the end of `setupUI()`)
- Delete `wallpaperManager.setUIScreen(selectedScreen)` from `screenSelectionChanged(_:)` 
- Delete `wallpaperManager.setUIScreen(selectedScreen)` from `updateUI()` (there's one at the top of `updateUI()`)
- In `screenSelectionChanged(_:)`: just store `selectedScreen` and call `updateUI()` directly (no `setUIScreen` needed)

---

### Task 8.2 — Add `syncCheckbox` to the screen selector row

Add `private var syncCheckbox: NSButton!` to the class properties.

In `createScreenSelector()`:
- Shrink `screenPopUp` frame from `width: 240` to `width: 200` to make room
- Add the sync checkbox after `screenPopUp`:
```swift
syncCheckbox = NSButton(checkboxWithTitle: "ui.syncScreens".localized, target: self, action: #selector(syncCheckboxChanged(_:)))
syncCheckbox.font = NSFont.systemFont(ofSize: 12)
syncCheckbox.frame = NSRect(x: 270, y: 10, width: 80, height: 20)
syncCheckbox.toolTip = "ui.syncScreens.tooltip".localized
container.addSubview(syncCheckbox)
```
- Adjust `applyAllButton` frame from `x: 315` to `x: 355` (shift right to accommodate sync checkbox)

Add the action method:
```swift
@objc private func syncCheckboxChanged(_ sender: NSButton) {
    guard let screen = selectedScreen else { return }
    wallpaperManager.setSynced(sender.state == .on, for: screen)
    updateUI()
}
```

In `updateUI()`, set the sync checkbox state:
```swift
// After computing selectedScreenID and config:
syncCheckbox.state = config.isSynced ? .on : .off
```

---

### Task 8.3 — Replace all per-screen `SettingsManager` reads in `updateUI()` with `screenConfig(for:)`

Rewrite `updateUI()` to use the new API. Here's the key pattern:

```swift
func updateUI() {
    updateScreenMenu()
    updateNewScreenPolicyMenu()  // replaces updateInheritSourceMenu()

    let selectedScreenID = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
    let config = SettingsManager.shared.screenConfig(for: selectedScreenID)
    
    // Sync checkbox
    syncCheckbox.state = config.isSynced ? .on : .off
    
    let activeScreen = selectedScreen ?? NSScreen.main ?? NSScreen.screens.first
    stopButton.title = "ui.stopWallpaper".localized
    stopButton.isEnabled = activeScreen.flatMap { wallpaperManager.wallpaperPath(for: $0) } != nil
        || config.folderPath != nil
    applyAllButton.isEnabled = (activeScreen != nil && NSScreen.screens.count > 1)
    
    let isFolderMode = config.isFolderMode
    let isRotationEnabled = config.isRotationEnabled
    let isShuffleMode = config.isShuffleMode
    let currentIncludeSubfolders = config.includeSubfolders
    let currentInterval = config.rotationIntervalMinutes
    
    pauseSwitch.state = SettingsManager.shared.pauseWhenInvisible ? .on : .off
    syncDesktopSwitch.state = SettingsManager.shared.syncDesktopWallpaper ? .on : .off
    intervalField.integerValue = currentInterval
    intervalStepper.integerValue = currentInterval
    intervalLabel.stringValue = formatInterval(minutes: currentInterval)
    
    rotationSwitch.isEnabled = isFolderMode
    rotationSwitch.state = isRotationEnabled ? .on : .off
    
    shuffleSwitch.isEnabled = isFolderMode && isRotationEnabled
    shuffleSwitch.state = isShuffleMode ? .on : .off
    
    intervalField.isEnabled = isFolderMode && isRotationEnabled
    intervalStepper.isEnabled = isFolderMode && isRotationEnabled
    includeSubfoldersSwitch.state = currentIncludeSubfolders ? .on : .off

    rotationSwitch.contentTintColor = isFolderMode ? nil : .tertiaryLabelColor
    shuffleSwitch.contentTintColor = (isFolderMode && isRotationEnabled) ? nil : .tertiaryLabelColor
    intervalPrefix.textColor = (isFolderMode && isRotationEnabled) ? .labelColor : .tertiaryLabelColor
    intervalLabel.textColor = (isFolderMode && isRotationEnabled) ? .secondaryLabelColor : .tertiaryLabelColor
    folderCountLabel.textColor = isFolderMode ? .secondaryLabelColor : .tertiaryLabelColor
    if isFolderMode {
        let recursive = currentIncludeSubfolders ? "ui.recursiveEnabled".localized : "ui.recursiveDisabled".localized
        let playlistCount = wallpaperManager.playlist(for: selectedScreenID).count
        folderCountLabel.stringValue = "ui.folderItems".localized(playlistCount, recursive)
    } else {
        folderCountLabel.stringValue = ""
    }

    var wallpaperPath: String?
    var isCurrentlyPaused = false

    if let screen = activeScreen {
        wallpaperPath = wallpaperManager.wallpaperPath(for: screen)
        isCurrentlyPaused = wallpaperManager.isPaused || wallpaperManager.isScreenPaused(screen)
    }

    if let path = wallpaperPath,
       FileManager.default.fileExists(atPath: path) {
        let url = URL(fileURLWithPath: path)
        let filename = (path as NSString).lastPathComponent
        let type = MediaType.detect(url)

        if isFolderMode {
            let current = wallpaperManager.currentPlaylistIndex(for: selectedScreenID) + 1
            let total = wallpaperManager.playlist(for: selectedScreenID).count
            let isRotating = isFolderMode && isRotationEnabled
            let shuffleIcon = (isShuffleMode && isRotating) ? "🔀 " : ""
            fileNameLabel.stringValue = "\(shuffleIcon)\(filename) (\(current)/\(total))"
            fileTypeLabel.stringValue = "ui.folderMode".localized
        } else {
            fileNameLabel.stringValue = filename
            fileTypeLabel.stringValue = type == .video ? "ui.video".localized : "ui.image".localized
        }

        let isAutoPaused = SettingsManager.shared.pauseWhenInvisible && wallpaperManager.isPausedInternally && !isCurrentlyPaused
        if isCurrentlyPaused {
            statusIndicator.layer?.backgroundColor = NSColor.systemYellow.cgColor
            statusLabel.stringValue = "ui.status".localized("ui.pausedManual".localized)
            statusLabel.textColor = .systemYellow
            previewPlayer?.pause()
        } else if isAutoPaused {
            statusIndicator.layer?.backgroundColor = NSColor.systemOrange.cgColor
            statusLabel.stringValue = "ui.status".localized("ui.pausedAuto".localized)
            statusLabel.textColor = .systemOrange
            previewPlayer?.pause()
        } else {
            statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "ui.status".localized("ui.playing".localized)
            statusLabel.textColor = .systemGreen
            previewPlayer?.play()
        }

        showPreview(url: url, type: type)
    } else {
        currentPreviewPath = nil
        clearPreview()
        fileNameLabel.stringValue = "ui.noWallpaper".localized
        fileTypeLabel.stringValue = ""

        statusIndicator.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        statusLabel.stringValue = "ui.status".localized("ui.notSet".localized)
        statusLabel.textColor = .secondaryLabelColor

        dropZone.isHidden = false
        dropLabel.stringValue = "ui.dropHere".localized
        setDropHighlight(active: false)
        previewImageView.isHidden = true
        previewPlayerLayer.isHidden = true
    }
}
```

Also update `showPreview(url:type:)` to use `screenConfig(for:)` instead of `folderConfig(for:)`:
```swift
// Replace:
let previewFolderConfig = (selectedScreen ?? NSScreen.main ?? NSScreen.screens.first).flatMap {
    SettingsManager.shared.folderConfig(for: $0)
}
let isFolder = previewFolderConfig != nil
// With:
let previewScreenID = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
let previewConfig = SettingsManager.shared.screenConfig(for: previewScreenID)
let isFolder = previewConfig.isFolderMode
```

---

### Task 8.4 — Update settings action handlers to write via `setScreenConfig`

Replace all action handlers that used legacy `SettingsManager` properties:

**`rotationSwitchChanged`**:
```swift
@objc func rotationSwitchChanged(_ sender: NSButton) {
    guard let screen = selectedScreen else { return }
    let id = SettingsManager.screenIdentifier(screen)
    var config = SettingsManager.shared.screenConfig(for: id)
    config.isRotationEnabled = (sender.state == .on)
    SettingsManager.shared.setScreenConfig(config, for: id)
    if sender.state == .on {
        wallpaperManager.startRotationTimer()
    } else {
        wallpaperManager.startRotationTimer()
    }
    updateUI()
}
```

**`shuffleSwitchChanged`**:
```swift
@objc func shuffleSwitchChanged(_ sender: NSButton) {
    guard let screen = selectedScreen else { return }
    let id = SettingsManager.screenIdentifier(screen)
    var config = SettingsManager.shared.screenConfig(for: id)
    config.isShuffleMode = (sender.state == .on)
    SettingsManager.shared.setScreenConfig(config, for: id)
    wallpaperManager.startRotationTimer()
    updateUI()
}
```

**`includeSubfoldersChanged`**:
```swift
@objc func includeSubfoldersChanged(_ sender: NSButton) {
    guard let screen = selectedScreen else { return }
    let id = SettingsManager.screenIdentifier(screen)
    var config = SettingsManager.shared.screenConfig(for: id)
    config.includeSubfolders = (sender.state == .on)
    if let folderPath = config.folderPath {
        wallpaperManager.setFolder(url: URL(fileURLWithPath: folderPath), for: screen, config: config)
    } else {
        SettingsManager.shared.setScreenConfig(config, for: id)
    }
    updateUI()
}
```

**`updateInterval(minutes:)`**:
```swift
private func updateInterval(minutes: Int) {
    guard let screen = selectedScreen else { return }
    let id = SettingsManager.screenIdentifier(screen)
    var config = SettingsManager.shared.screenConfig(for: id)
    config.rotationIntervalMinutes = minutes
    SettingsManager.shared.setScreenConfig(config, for: id)
    intervalLabel.stringValue = formatInterval(minutes: minutes)
    wallpaperManager.startRotationTimer()
}
```

Remove `inheritSourceLabel`, `inheritSourcePopUp` properties and `updateInheritSourceMenu()`, `inheritSourceChanged(_:)` methods (replaced by Task 8.5).

---

### Task 8.5 — Replace `inheritSourcePopUp` with `New_Screen_Policy` picker

Remove from class properties:
- `private var inheritSourceLabel: NSTextField!`
- `private var inheritSourcePopUp: NSPopUpButton!`

Add to class properties:
- `private var newScreenPolicyLabel: NSTextField!`
- `private var newScreenPolicyPopUp: NSPopUpButton!`
- `private var mirrorTargetLabel: NSTextField!`
- `private var mirrorTargetPopUp: NSPopUpButton!`

In `createSettings()`, replace the `inheritSourceLabel` and `inheritSourcePopUp` creation block with:
```swift
newScreenPolicyLabel = NSTextField(labelWithString: "ui.newScreenPolicy".localized + ":")
newScreenPolicyLabel.font = NSFont.systemFont(ofSize: 12)
newScreenPolicyLabel.textColor = .labelColor
newScreenPolicyLabel.frame = NSRect(x: 0, y: 4, width: 120, height: 20)
settings.addSubview(newScreenPolicyLabel)

newScreenPolicyPopUp = NSPopUpButton(frame: NSRect(x: 125, y: 2, width: 200, height: 25))
newScreenPolicyPopUp.target = self
newScreenPolicyPopUp.action = #selector(newScreenPolicyChanged(_:))
newScreenPolicyPopUp.toolTip = "ui.newScreenPolicy.tooltip".localized
newScreenPolicyPopUp.addItem(withTitle: "ui.newScreenPolicy.inheritSyncGroup".localized)
newScreenPolicyPopUp.lastItem?.representedObject = New_Screen_Policy.inheritSyncGroup.rawValue
newScreenPolicyPopUp.addItem(withTitle: "ui.newScreenPolicy.blank".localized)
newScreenPolicyPopUp.lastItem?.representedObject = New_Screen_Policy.blank.rawValue
newScreenPolicyPopUp.addItem(withTitle: "ui.newScreenPolicy.mirrorSpecificScreen".localized)
newScreenPolicyPopUp.lastItem?.representedObject = New_Screen_Policy.mirrorSpecificScreen.rawValue
settings.addSubview(newScreenPolicyPopUp)

mirrorTargetLabel = NSTextField(labelWithString: "ui.newScreenPolicy.mirrorTarget".localized + ":")
mirrorTargetLabel.font = NSFont.systemFont(ofSize: 11)
mirrorTargetLabel.textColor = .secondaryLabelColor
mirrorTargetLabel.frame = NSRect(x: 0, y: -22, width: 120, height: 20)
mirrorTargetLabel.isHidden = true
settings.addSubview(mirrorTargetLabel)

mirrorTargetPopUp = NSPopUpButton(frame: NSRect(x: 125, y: -24, width: 200, height: 25))
mirrorTargetPopUp.target = self
mirrorTargetPopUp.action = #selector(mirrorTargetChanged(_:))
mirrorTargetPopUp.isHidden = true
settings.addSubview(mirrorTargetPopUp)
```

Add action methods:
```swift
@objc private func newScreenPolicyChanged(_ sender: NSPopUpButton) {
    guard let rawValue = sender.selectedItem?.representedObject as? String,
          let policy = New_Screen_Policy(rawValue: rawValue) else { return }
    SettingsManager.shared.newScreenPolicy = policy
    updateNewScreenPolicyMenu()
}

@objc private func mirrorTargetChanged(_ sender: NSPopUpButton) {
    guard let screenID = sender.selectedItem?.representedObject as? String else { return }
    SettingsManager.shared.newScreenMirrorTargetID = screenID
}
```

Add `updateNewScreenPolicyMenu()` method:
```swift
private func updateNewScreenPolicyMenu() {
    // Sync newScreenPolicyPopUp to current setting
    let currentPolicy = SettingsManager.shared.newScreenPolicy
    for (index, item) in newScreenPolicyPopUp.itemArray.enumerated() {
        if let rawValue = item.representedObject as? String,
           rawValue == currentPolicy.rawValue {
            newScreenPolicyPopUp.selectItem(at: index)
            break
        }
    }
    
    // Show/hide mirror target controls
    let showMirror = (currentPolicy == .mirrorSpecificScreen)
    mirrorTargetLabel.isHidden = !showMirror
    mirrorTargetPopUp.isHidden = !showMirror
    
    if showMirror {
        // Populate mirror target popup with all known screens from registry
        mirrorTargetPopUp.removeAllItems()
        for (index, screen) in NSScreen.screens.enumerated() {
            let id = SettingsManager.screenIdentifier(screen)
            let displayName: String
            if #available(macOS 10.15, *) {
                displayName = screen.localizedName
            } else {
                displayName = "screen.display".localized(index + 1)
            }
            let suffix = screen.isBuiltIn ? "screen.builtIn".localized : ""
            mirrorTargetPopUp.addItem(withTitle: "\(displayName)\(suffix)")
            mirrorTargetPopUp.lastItem?.representedObject = id
        }
        // Select current target
        if let targetID = SettingsManager.shared.newScreenMirrorTargetID,
           let targetItem = mirrorTargetPopUp.itemArray.first(where: { ($0.representedObject as? String) == targetID }) {
            mirrorTargetPopUp.select(targetItem)
        }
    }
}
```

---

### Task 8.6 — Update `applyToAllScreens()` to use the new API

Replace the entire `applyToAllScreens()` method:
```swift
@objc private func applyToAllScreens() {
    guard let screen = selectedScreen else { return }
    let selectedScreenID = SettingsManager.screenIdentifier(screen)
    let config = SettingsManager.shared.screenConfig(for: selectedScreenID)
    
    if config.isFolderMode, let folderPath = config.folderPath,
       FileManager.default.fileExists(atPath: folderPath) {
        let folderURL = URL(fileURLWithPath: folderPath)
        for targetScreen in NSScreen.screens {
            wallpaperManager.setFolder(url: folderURL, for: targetScreen, config: config)
        }
    } else if let currentFileURL = wallpaperManager.currentFile(for: selectedScreenID) {
        for targetScreen in NSScreen.screens {
            wallpaperManager.setWallpaper(url: currentFileURL, for: targetScreen)
        }
    }
    updateUI()
}
```

---

### Task 8.7 — Update onboarding to use screen-parameterized API

In `runOnboardingIfNeeded()`:
- Replace `if SettingsManager.shared.hasExistingSetup {` with a check using the new API:
  ```swift
  // Check if any screen has a non-default config
  let hasExistingSetup = NSScreen.screens.contains { screen in
      let id = SettingsManager.screenIdentifier(screen)
      let config = SettingsManager.shared.screenConfig(for: id)
      return config.folderPath != nil || config.wallpaperPath != nil
  } || !SettingsManager.shared.wallpaperHistory.isEmpty
  if hasExistingSetup {
      SettingsManager.shared.onboardingCompleted = true
      return
  }
  ```

In `setWallpaper(url:)` (the private method in MainWindowController):
- Replace `ScreenFolderConfig(...)` with `Screen_Config(...)`:
  ```swift
  // Replace:
  let config = ScreenFolderConfig(
      folderPath: url.path,
      rotationIntervalMinutes: max(1, intervalField.integerValue),
      isShuffleMode: (shuffleSwitch.state == .on),
      isRotationEnabled: (rotationSwitch.state == .on),
      includeSubfolders: (includeSubfoldersSwitch.state == .on)
  )
  // With:
  let config = Screen_Config(
      folderPath: url.path,
      wallpaperPath: nil,
      rotationIntervalMinutes: max(1, intervalField.integerValue),
      isShuffleMode: (shuffleSwitch.state == .on),
      isRotationEnabled: (rotationSwitch.state == .on),
      includeSubfolders: (includeSubfoldersSwitch.state == .on),
      isFolderMode: true,
      isSynced: selectedScreen.map { SettingsManager.shared.screenConfig(for: SettingsManager.screenIdentifier($0)).isSynced } ?? true
  )
  ```
- Remove the `else` branch that called `wallpaperManager.setWallpaper(url:)` (parameterless) and `SettingsManager.shared.wallpaperPath = url.path` — replace with:
  ```swift
  } else {
      let type = MediaType.detect(url)
      guard type != .unsupported else {
          throw WallpaperError.unsupportedFormat
      }
      if let screen = selectedScreen {
          wallpaperManager.setWallpaper(url: url, for: screen)
      } else {
          for screen in NSScreen.screens {
              wallpaperManager.setWallpaper(url: url, for: screen)
          }
      }
  }
  ```

Also update `stopWallpaper()` in MainWindowController to remove legacy calls:
```swift
@objc func stopWallpaper() {
    if let screen = selectedScreen {
        wallpaperManager.stopWallpaper(for: screen)
    } else {
        wallpaperManager.stopAll()
    }
    updateUI()
    (NSApp.delegate as? AppDelegate)?.rebuildRecentMenu()
}
```

Also update `collectionView(_:didSelectItemsAt:)` to use the new API:
```swift
func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
    if let indexPath = indexPaths.first {
        guard let screen = selectedScreen else { return }
        let id = SettingsManager.screenIdentifier(screen)
        var config = SettingsManager.shared.screenConfig(for: id)
        if config.isRotationEnabled {
            config.isRotationEnabled = false
            SettingsManager.shared.setScreenConfig(config, for: id)
            wallpaperManager.startRotationTimer()
        }
        wallpaperManager.selectPlaylistItem(at: indexPath.item, for: screen)
        updateUI()
    }
}
```

Also update `collectionView(_:numberOfItemsInSection:)` and `collectionView(_:itemForRepresentedObjectAt:)`:
```swift
func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
    let id = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
    return wallpaperManager.playlist(for: id).count
}

func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
    let item = collectionView.makeItem(withIdentifier: ThumbnailItem.identifier, for: indexPath) as! ThumbnailItem
    let id = selectedScreen.map { SettingsManager.screenIdentifier($0) } ?? ""
    let playlist = wallpaperManager.playlist(for: id)
    let url = playlist[indexPath.item]
    let isActive = (indexPath.item == wallpaperManager.currentPlaylistIndex(for: id))
    item.configure(with: url, isActive: isActive)
    return item
}
```

Also update `suggestedPickerDirectoryURL()` to use the new API:
```swift
private func suggestedPickerDirectoryURL() -> URL? {
    let selectedPath: String?
    if let screen = selectedScreen {
        let id = SettingsManager.screenIdentifier(screen)
        let config = SettingsManager.shared.screenConfig(for: id)
        selectedPath = wallpaperManager.wallpaperPath(for: screen)
            ?? config.wallpaperPath
            ?? config.folderPath
    } else {
        selectedPath = nil
    }

    guard let path = selectedPath, !path.isEmpty else { return nil }
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: path).deletingLastPathComponent()
    }
    return URL(fileURLWithPath: path).deletingLastPathComponent()
}
```

---

**After all changes, run `./build.sh` to verify the full app compiles.** Fix any remaining compile errors. The goal is a clean build with zero errors.

Key things to watch for:
1. Remove the no-op `setUIScreen` stub from `WallpaperManager` if it's still there (it was kept temporarily)
2. Any remaining references to `ScreenFolderConfig` — replace with `Screen_Config`
3. Any remaining references to deleted `SettingsManager` methods
4. The `updateInheritSourceMenu()` call in `updateUI()` — replace with `updateNewScreenPolicyMenu()`
5. The `wallpaperManager.setUIScreen(selectedScreen)` call in `updateUI()` — remove it

After `./build.sh` succeeds, also run `swift test` to confirm all tests still pass.


**Response:**

Tasks 8.1 through 8.7 are complete. The app builds cleanly (`./build.sh` exits 0) and all 43 relevant tests pass.

**Summary of changes made:**

**MainWindowController.swift:**
- **8.1**: Removed all `wallpaperManager.setUIScreen(selectedScreen)` calls from `setupUI()`, `screenSelectionChanged(_:)`, and `updateUI()`
- **8.2**: Added `syncCheckbox: NSButton!` property; shrunk `screenPopUp` to width 200; added sync checkbox at x:270; shifted `applyAllButton` to x:355; added `syncCheckboxChanged(_:)` action
- **8.3**: Rewrote `updateUI()` to use `screenConfig(for: selectedScreenID)` for all per-screen reads; replaced `wallpaperManager.playlist`/`currentPlaylistIndex`/`currentFile` (parameterless) with screen-parameterized versions; updated `showPreview(url:type:)` to use `screenConfig(for:)` instead of `folderConfig(for:)`
- **8.4**: Replaced `rotationSwitchChanged`, `shuffleSwitchChanged`, `includeSubfoldersChanged`, `updateInterval(minutes:)` to read/write via `setScreenConfig`; removed `inheritSourceChanged` and all legacy `SettingsManager` property writes
- **8.5**: Replaced `inheritSourceLabel`/`inheritSourcePopUp` with `newScreenPolicyLabel`, `newScreenPolicyPopUp`, `mirrorTargetLabel`, `mirrorTargetPopUp`; added `newScreenPolicyChanged(_:)`, `mirrorTargetChanged(_:)`, and `updateNewScreenPolicyMenu()` methods
- **8.6**: Replaced `applyToAllScreens()` to use `screenConfig(for:)` and `currentFile(for:)`
- **8.7**: Updated `runOnboardingIfNeeded()` to check `screenConfig` instead of `hasExistingSetup`; replaced `ScreenFolderConfig` with `Screen_Config` in `setWallpaper(url:)`; cleaned up `stopWallpaper()` to remove legacy calls; updated all three collection view delegate methods to use screen-parameterized API; updated `suggestedPickerDirectoryURL()` to use `screenConfig(for:)`

**WallpaperManager.swift:**
- Removed the `setUIScreen(_:)` no-op stub (all call sites now eliminated)

**Localization files:**
- Added `ui.syncScreens`, `ui.syncScreens.tooltip`, `ui.newScreenPolicy.*` keys to both `en.lproj` and `zh-Hans.lproj`

The one failing test (`testSyncAllScreensPreservesManualWallpaperSelection`) is a pre-existing **bug condition exploration test** that is intentionally designed to fail — its error message explicitly states "This test FAILS on unfixed code, proving the bug exists." It was failing before these changes and is unrelated to Tasks 8.1-8.7.

Tasks 8.1–8.7 complete. Marking them done.

Now Task 9 — full build checkpoint:

Full build succeeds with zero errors (one pre-existing deprecation warning). 44 tests run, 43 pass — the 1 failure is the intentional bug-condition exploration test from a prior spec.

Now Task 10 — localization strings:

The localization files already have all the new keys added (the subagent for Task 8 added them). I just need to remove the now-unused legacy keys from both files.

Now the final checkpoint — Task 11:

Build succeeds. Now run the tests:

44 tests, 43 pass. The 1 failure is the pre-existing intentional bug-condition exploration test (`testSyncAllScreensPreservesManualWallpaperSelection`) that was designed to fail on unfixed code — it's from a prior spec and is unrelated to this redesign.

Let me verify the app bundle was built correctly:

App bundle is complete with the executable, icon, and both localization bundles.

All 11 tasks are complete. Here's a summary of what was implemented:

**Data layer** — `Screen_Config.swift` defines the unified per-screen settings model (`Screen_Config`, `Screen_Registry`, `New_Screen_Policy`) with forward-compatible JSON decoding. `SettingsManager` was fully refactored to expose `screenConfig(for:)` / `setScreenConfig(_:for:)` as the sole per-screen API, with `runCleanSlateInitIfNeeded()` for the migration path.

**Tests** — 14 new tests added: 10 unit tests in `ScreenConfigTests.swift` covering all acceptance criteria, and 4 property-based tests in `ScreenConfigPropertyTests.swift` using a deterministic LCG generator (100 iterations each) validating round-trip encoding, keyed round-trip, no legacy key writes, and sync group invariant.

**WallpaperManager** — `uiScreenID` removed entirely. New screen-parameterized query methods (`playlist(for:)`, `currentPlaylistIndex(for:)`, `currentFile(for:)`). Sync group timer coordination added (`syncGroupTimer`, `setSynced(_:for:)`). `screensChanged()` rewritten using `Screen_Registry` with `New_Screen_Policy` provisioning. `setFolder`, `setWallpaper`, `stopWallpaper` all updated to use `Screen_Config`. `restoreAllScreens()` added.

**AppDelegate** — Restoration loop replaced with `runCleanSlateInitIfNeeded()` + `restoreAllScreens()`. All legacy `SettingsManager` calls removed.

**MainWindowController** — `setUIScreen` calls removed. Sync checkbox added to screen selector row. `inheritSourcePopUp` replaced with `New_Screen_Policy` picker (with mirror target companion). All `updateUI()` reads go through `screenConfig(for:)`. All action handlers write via `setScreenConfig`.

**Localization** — New keys added for sync checkbox and new screen policy UI in both English and Simplified Chinese. Legacy `ui.newScreenInherit*` keys removed.

---

**User:**

Why is there a sync checkbox and sycn all screens?

---

**Assistant:**

They serve different purposes:

**Sync checkbox** (per-screen, in the screen selector row) — controls whether a specific screen is a member of the sync group. When checked, that screen shares its folder, rotation interval, shuffle, and rotation-enabled settings with all other checked screens, and they all advance their playlist simultaneously on the same timer tick. It's a persistent setting stored in `Screen_Config.isSynced`.

**Sync All Screens button** — a one-shot action. It takes the currently selected screen's config (or current file) and immediately applies it to every connected screen right now. It doesn't change any screen's `isSynced` state — it's just a quick "copy this to everything" operation.

So the distinction is:
- Sync checkbox = ongoing membership in a coordinated group (persists, affects future changes)
- Sync All Screens = immediate one-time copy (no lasting relationship between screens)

That said, with the new sync group model, the **Sync All Screens button is arguably redundant** — if you want screens to stay in sync going forward, you'd check the sync checkbox on each screen. The button only makes sense if you want a one-time copy without the ongoing coordination.

If you want to remove the button to simplify the UI, that's a reasonable call. The spec kept it because it existed before and the requirements (8.5) explicitly called for updating it rather than removing it. But it's your product — happy to remove it if you think it adds confusion.

---

**User:**

What do you think is best for the user?

---

**Assistant:**

Remove the button. Here's why:

With the sync checkbox model, "Sync All Screens" is now confusing rather than helpful. A user sees two ways to sync and has to understand the difference — that's cognitive overhead that shouldn't exist.

The sync checkbox already covers the use case better:
- Want all screens in sync? Check the box on each one. Done, and it stays that way.
- Want to copy a config once without ongoing sync? That's an edge case that doesn't justify a dedicated button in the main UI.

The button also has a subtle footgun: it copies the current state but doesn't set `isSynced`, so screens will immediately diverge again the next time someone changes a setting. That's likely to confuse users who think they've synced their screens.

Keeping it creates a false choice. Removing it makes the sync checkbox the single, clear answer to "how do I get my screens to show the same thing."

Want me to remove it?

---

**User:**

Do whatever you need to make it clear and user-friendly. This is supposed to be simple and intuitive with little (no) explanation.

---

**Assistant:**

Let me read the current UI code first to understand the full layout before making changes.

Good, I have the full picture. Here's my plan:

**Remove**: `applyAllButton` ("Sync All Screens") — redundant with the sync checkbox.

**Rename**: "Sync" checkbox → "Link Screens" — more intuitive, implies screens move together. No mental model of "sync groups" needed.

**Simplify the screen selector row**: With the button gone, `screenPopUp` gets its full width back (240px), and "Link Screens" sits cleanly to the right.

**Also clean up**: The dead `inheritSourceChanged` stub method.

Now remove the `applyToAllScreens` method and the `applyAllButton` references in `updateUI()`, and clean up the dead `inheritSourceChanged` stub:

Now remove the dead `inheritSourceChanged` stub:

Now update the localization string from "Sync" to "Link Screens":

Now verify it builds:

Clean build. Here's what changed:

- **Removed** the "Sync All Screens" button entirely — the "Link Screens" checkbox is the single way to keep screens in sync
- **Renamed** "Sync" → "Link Screens" — more descriptive, no mental model required. Check it on two screens and they move together
- **Link Screens is disabled** when only one screen is connected (grayed out, so it's clear it only applies in multi-monitor setups)
- **Removed** the dead `inheritSourceChanged` stub

The screen selector row is now: `Screen: [dropdown] ☐ Link Screens` — clean and self-explanatory.

---

**User:**

What happens when you click mirror specific screen?

---

**Assistant:**

"Mirror Specific Screen" is a **New Screen Policy** — it only applies when a brand new monitor is connected for the first time. It controls what config that new screen gets provisioned with.

So the flow is:
1. User selects "Mirror Specific Screen" in the New Screen Policy dropdown
2. A companion picker appears showing all known screens
3. User picks a source screen (e.g. "Built-in Retina Display")
4. Next time a new monitor is plugged in, it gets a copy of that source screen's config

It does **not** link the screens together — the new screen gets a one-time copy and then lives independently (`isSynced = false`). After that, changes to either screen don't affect the other.

The naming is confusing though. "Mirror" in macOS typically means the display literally mirrors the same image at the OS level. This feature is something different — it's more like "copy config from". A user seeing "Mirror Specific Screen" in a wallpaper app would reasonably expect it to make two screens show the same wallpaper at all times, which isn't what it does.

Given the goal of no-explanation simplicity, I'd argue this option is also worth reconsidering. The three policies are:

- **Inherit Sync Group** — new screen joins the linked group (sensible default)
- **Start Blank** — new screen starts empty
- **Mirror Specific Screen** — new screen copies one specific screen's config once

The third option is a pretty niche use case. Most users either want new screens to join the group or start fresh. Do you want to keep it, rename it, or drop it?

---

**User:**

Drop it.

---

**Assistant:**

On it. This touches `Screen_Config.swift`, `SettingsManager.swift`, `WallpaperManager.swift`, `MainWindowController.swift`, and both localization files.

Now make all the changes in parallel:

Now fix `WallpaperManager` — remove the `mirrorSpecificScreen` case from `provisionNewScreen`:

Now clean up `MainWindowController` — remove the mirror target controls and simplify the new screen policy UI:

Now remove the `mirrorTargetChanged` action and simplify `updateNewScreenPolicyMenu`:

Now clean up the localization files — remove the mirror-related keys:

---

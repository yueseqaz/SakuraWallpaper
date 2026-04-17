import XCTest
@testable import SakuraWallpaperCore

// MARK: - Deterministic Pseudo-Random Generator

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

// MARK: - Config Generator

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

// MARK: - Property Tests

final class ScreenConfigPropertyTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: SettingsManager!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SakuraWallpaperPropertyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settings = SettingsManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        settings = nil
        suiteName = nil
        super.tearDown()
    }

    // Feature: multi-monitor-redesign, Property 1: Screen_Config round-trip
    // Validates: Requirements 9.2, 9.3, 5.6
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
        _ = screenRegistryKey // suppress unused warning
    }

    // Feature: multi-monitor-redesign, Property 2: Screen_Registry keyed round-trip
    // Validates: Requirements 1.2, 9.1, 9.2
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

    // Feature: multi-monitor-redesign, Property 3: setScreenConfig does not write legacy global keys
    // Validates: Requirements 1.4, 8.4
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

    // Feature: multi-monitor-redesign, Property 4: Sync group config invariant
    // Validates: Requirements 5.1, 5.5
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
}

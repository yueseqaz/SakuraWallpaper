import XCTest
@testable import SakuraWallpaperCore

final class ScreenConfigTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: SettingsManager!
    private var suiteName: String!

    private let screenRegistryKey = "sakurawallpaper_screen_registry"

    override func setUp() {
        super.setUp()
        suiteName = "SakuraWallpaperTests.\(UUID().uuidString)"
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

    // MARK: - Test 1: Default config field values

    func testDefaultConfigFieldValues() {
        let config = Screen_Config.default
        XCTAssertEqual(config.rotationIntervalMinutes, 15)
        XCTAssertTrue(config.isRotationEnabled)
        XCTAssertFalse(config.isShuffleMode)
        XCTAssertFalse(config.includeSubfolders)
        XCTAssertFalse(config.isFolderMode)
        XCTAssertNil(config.folderPath)
        XCTAssertNil(config.wallpaperPath)
        XCTAssertTrue(config.isSynced)
    }

    // MARK: - Test 2: All fields accessible with non-default values

    func testScreenConfigAllFieldsAccessible() {
        let config = Screen_Config(
            folderPath: "/tmp/test",
            wallpaperPath: "/tmp/test.jpg",
            rotationIntervalMinutes: 30,
            isShuffleMode: true,
            isRotationEnabled: false,
            includeSubfolders: true,
            isFolderMode: true,
            isSynced: false
        )
        XCTAssertEqual(config.folderPath, "/tmp/test")
        XCTAssertEqual(config.wallpaperPath, "/tmp/test.jpg")
        XCTAssertEqual(config.rotationIntervalMinutes, 30)
        XCTAssertTrue(config.isShuffleMode)
        XCTAssertFalse(config.isRotationEnabled)
        XCTAssertTrue(config.includeSubfolders)
        XCTAssertTrue(config.isFolderMode)
        XCTAssertFalse(config.isSynced)
    }

    // MARK: - Test 3: Missing fields decoded as defaults

    func testMissingFieldsDecodedAsDefaults() {
        // JSON with all fields EXCEPT is_synced
        let jsonString = """
        {
            "screen_1": {
                "folder_path": null,
                "wallpaper_path": null,
                "rotation_interval_minutes": 15,
                "is_shuffle_mode": false,
                "is_rotation_enabled": true,
                "include_subfolders": false,
                "is_folder_mode": false
            }
        }
        """
        let data = Data(jsonString.utf8)
        defaults.set(data, forKey: screenRegistryKey)

        let config = settings.screenConfig(for: "screen_1")
        XCTAssertTrue(config.isSynced, "isSynced should default to true when key is absent from JSON")
    }

    // MARK: - Test 4: Malformed JSON returns default

    func testMalformedJSONReturnsDefault() {
        let garbage = Data("not valid json".utf8)
        defaults.set(garbage, forKey: screenRegistryKey)

        let config = settings.screenConfig(for: "screen_1")
        XCTAssertEqual(config, Screen_Config.default)
    }

    // MARK: - Test 5: Clean slate deletes legacy keys

    func testCleanSlateDeletesLegacyKeys() {
        let legacyKeys: [String: Any] = [
            "sakurawallpaper_folder_path": "/tmp/folder",
            "sakurawallpaper_wallpaper_path": "/tmp/wallpaper.jpg",
            "sakurawallpaper_screen_folder_configs": Data(),
            "sakurawallpaper_screen_wallpapers": ["key": "value"],
            "sakurawallpaper_is_folder_mode": true,
            "sakurawallpaper_rotation_interval_minutes": 30,
            "sakurawallpaper_is_shuffle_mode": true,
            "sakurawallpaper_is_rotation_enabled": false,
            "sakurawallpaper_include_subfolders": true,
            "sakurawallpaper_new_screen_inheritance_mode": "primaryScreen",
            "sakurawallpaper_new_screen_inheritance_screen_id": "screen_1"
        ]

        for (key, value) in legacyKeys {
            defaults.set(value, forKey: key)
        }

        settings.runCleanSlateInitIfNeeded()

        for key in legacyKeys.keys {
            XCTAssertNil(defaults.object(forKey: key), "Expected legacy key '\(key)' to be absent after clean slate")
        }
    }

    // MARK: - Test 6: Clean slate creates empty registry

    func testCleanSlateCreatesEmptyRegistry() {
        settings.runCleanSlateInitIfNeeded()

        guard let data = defaults.data(forKey: screenRegistryKey) else {
            XCTFail("Expected screenRegistryKey to be non-nil after runCleanSlateInitIfNeeded()")
            return
        }

        let registry = try? JSONDecoder().decode(Screen_Registry.self, from: data)
        XCTAssertNotNil(registry, "Registry data should decode as Screen_Registry")
        XCTAssertEqual(registry?.count, 0, "Registry should be empty after clean slate init")
    }

    // MARK: - Test 7: Clean slate skipped when registry present

    func testCleanSlateSkippedWhenRegistryPresent() {
        // Pre-populate registry with a known config
        let knownConfig = Screen_Config(
            folderPath: "/tmp/known",
            wallpaperPath: nil,
            rotationIntervalMinutes: 42,
            isShuffleMode: true,
            isRotationEnabled: true,
            includeSubfolders: false,
            isFolderMode: true,
            isSynced: false
        )
        let registry: Screen_Registry = ["screen_known": knownConfig]
        let originalData = try! JSONEncoder().encode(registry)
        defaults.set(originalData, forKey: screenRegistryKey)

        settings.runCleanSlateInitIfNeeded()

        guard let afterData = defaults.data(forKey: screenRegistryKey) else {
            XCTFail("Registry data should still be present after skipped clean slate")
            return
        }

        let afterRegistry = try? JSONDecoder().decode(Screen_Registry.self, from: afterData)
        XCTAssertEqual(afterRegistry?["screen_known"]?.folderPath, "/tmp/known")
        XCTAssertEqual(afterRegistry?["screen_known"]?.rotationIntervalMinutes, 42)
        XCTAssertEqual(afterRegistry?["screen_known"]?.isShuffleMode, true)
        XCTAssertEqual(afterRegistry?["screen_known"]?.isFolderMode, true)
        XCTAssertEqual(afterRegistry?["screen_known"]?.isSynced, false)
    }

    // MARK: - Test 8: Onboarding key not deleted by clean slate

    func testOnboardingKeyNotDeletedByCleanSlate() {
        settings.onboardingCompleted = true
        settings.runCleanSlateInitIfNeeded()
        XCTAssertTrue(settings.onboardingCompleted)
    }

    // MARK: - Test 9: New screen policy default is inheritSyncGroup

    func testNewScreenPolicyDefaultIsInheritSyncGroup() {
        // Fresh SettingsManager with no prior value set
        XCTAssertEqual(settings.newScreenPolicy, .inheritSyncGroup)
    }

    // MARK: - Test 10: setScreenConfig does not write legacy global keys

    func testSetScreenConfigDoesNotWriteLegacyGlobalKeys() {
        let config = Screen_Config(
            folderPath: "/tmp/test",
            wallpaperPath: "/tmp/test.jpg",
            rotationIntervalMinutes: 30,
            isShuffleMode: true,
            isRotationEnabled: false,
            includeSubfolders: true,
            isFolderMode: true,
            isSynced: false
        )

        settings.setScreenConfig(config, for: "screen_1")

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

        for key in legacyKeys {
            XCTAssertNil(defaults.object(forKey: key), "Expected legacy key '\(key)' to be absent after setScreenConfig")
        }
    }
}

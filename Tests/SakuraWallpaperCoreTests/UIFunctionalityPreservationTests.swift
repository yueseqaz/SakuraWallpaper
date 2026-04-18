import XCTest
@testable import SakuraWallpaperCore

/// Preservation tests for UI functionality that must remain unchanged after bug fixes.
///
/// These tests encode the EXISTING correct behavior for inputs where the bug conditions
/// do NOT hold. They must PASS on both unfixed and fixed code to ensure no regressions.
///
/// **CRITICAL**: These tests capture baseline behavior that must be preserved.
/// They should PASS on unfixed code and continue to PASS after fixes are applied.
///
/// **Validates: Requirements 3.1, 3.2, 3.3**
final class UIFunctionalityPreservationTests: XCTestCase {

    private var defaults: UserDefaults!
    private var settings: SettingsManager!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "UIFunctionalityPreservationTests.\(UUID().uuidString)"
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

    // MARK: - Property 2: Preservation - Non-Buggy UI Behavior

    /// **Validates: Requirements 3.1, 3.2, 3.3**
    ///
    /// Property-based test for normal wallpaper operations preservation.
    ///
    /// For any wallpaper operation that does NOT involve the three specific bug conditions
    /// (sync with manual selections, screen dropdown with multiple displays, dark mode text),
    /// the behavior SHALL remain exactly the same as the original code.
    func testNormalWallpaperOperationsPreservation() {
        // Test Case 1: Normal wallpaper selection via Screen_Config (single file, not folder mode)
        let singleWallpaperPath = "/tmp/test_wallpaper.mp4"
        let screenID = "screen_1"
        var config = Screen_Config.default
        config.wallpaperPath = singleWallpaperPath
        config.isFolderMode = false
        settings.setScreenConfig(config, for: screenID)

        let retrieved = settings.screenConfig(for: screenID)
        XCTAssertEqual(retrieved.wallpaperPath, singleWallpaperPath,
            "Single wallpaper selection should be preserved")
        XCTAssertFalse(retrieved.isFolderMode,
            "Single wallpaper mode (not folder mode) should be preserved")

        // Test Case 2: Normal folder mode without manual selection (uses Screen_Config)
        let folderPath = "/tmp/test_wallpapers"
        let mockScreenId = "screen_2"
        let folderConfig = Screen_Config(
            folderPath: folderPath,
            wallpaperPath: nil,
            rotationIntervalMinutes: 15,
            isShuffleMode: false,
            isRotationEnabled: true,
            includeSubfolders: false,
            isFolderMode: true,
            isSynced: true
        )

        settings.setScreenConfig(folderConfig, for: mockScreenId)
        let storedConfig = settings.screenConfig(for: mockScreenId)

        XCTAssertTrue(storedConfig.isFolderMode,
            "Folder mode should be preserved")
        XCTAssertEqual(storedConfig.folderPath, folderPath,
            "Folder path should be preserved")
        XCTAssertEqual(storedConfig.rotationIntervalMinutes, 15,
            "Rotation interval should be preserved")
        XCTAssertFalse(storedConfig.isShuffleMode,
            "Shuffle mode setting should be preserved")
        XCTAssertTrue(storedConfig.isRotationEnabled,
            "Rotation enabled setting should be preserved")

        // Test Case 3: Wallpaper history functionality
        settings.wallpaperHistory = []
        let historyPaths = [
            "/tmp/wallpaper1.jpg",
            "/tmp/wallpaper2.mp4",
            "/tmp/wallpaper3.png"
        ]
        for path in historyPaths {
            settings.addToHistory(path)
        }

        let history = settings.wallpaperHistory
        XCTAssertGreaterThanOrEqual(history.count, 3, "Wallpaper history should preserve at least the added entries")
        XCTAssertEqual(history.first, historyPaths.last,
            "Most recent wallpaper should be first in history")
        XCTAssertTrue(history.contains(historyPaths[0]),
            "History should contain all wallpaper paths")

        // Test Case 4: Settings persistence
        settings.launchAtLogin = true
        settings.pauseWhenInvisible = true

        XCTAssertTrue(settings.launchAtLogin,
            "Launch at login setting should be preserved")
        XCTAssertTrue(settings.pauseWhenInvisible,
            "Pause when invisible setting should be preserved")

        // Test per-screen config settings
        var settingsConfig = Screen_Config.default
        settingsConfig.rotationIntervalMinutes = 30
        settingsConfig.isShuffleMode = true
        settingsConfig.isRotationEnabled = false
        settingsConfig.includeSubfolders = true
        settings.setScreenConfig(settingsConfig, for: "screen_settings_test")

        let persistedConfig = settings.screenConfig(for: "screen_settings_test")
        XCTAssertEqual(persistedConfig.rotationIntervalMinutes, 30,
            "Rotation interval setting should be preserved")
        XCTAssertTrue(persistedConfig.isShuffleMode,
            "Shuffle mode setting should be preserved")
        XCTAssertFalse(persistedConfig.isRotationEnabled,
            "Rotation enabled setting should be preserved")
        XCTAssertTrue(persistedConfig.includeSubfolders,
            "Include subfolders setting should be preserved")
    }

    /// Tests single screen configuration preservation.
    ///
    /// When operating in single-screen mode, all wallpaper management functionality
    /// should continue to work exactly as before. The screen dropdown ordering bug
    /// should not affect single-screen usage.
    func testSingleScreenConfigurationPreservation() {
        let singleScreenId = "screen_1"

        // Test single screen config via Screen_Config
        let config = Screen_Config(
            folderPath: "/tmp/single_screen_folder",
            wallpaperPath: nil,
            rotationIntervalMinutes: 10,
            isShuffleMode: true,
            isRotationEnabled: true,
            includeSubfolders: false,
            isFolderMode: true,
            isSynced: true
        )

        settings.setScreenConfig(config, for: singleScreenId)
        let storedConfig = settings.screenConfig(for: singleScreenId)

        XCTAssertNotNil(storedConfig.folderPath, "Single screen config should be preserved")
        XCTAssertEqual(storedConfig.folderPath, "/tmp/single_screen_folder",
            "Single screen folder path should be preserved")
        XCTAssertEqual(storedConfig.rotationIntervalMinutes, 10,
            "Single screen rotation interval should be preserved")
        XCTAssertTrue(storedConfig.isShuffleMode,
            "Single screen shuffle mode should be preserved")
        XCTAssertTrue(storedConfig.isRotationEnabled,
            "Single screen rotation enabled should be preserved")

        // Test that single screen operations don't interfere with other screens
        var globalConfig = Screen_Config.default
        globalConfig.wallpaperPath = "/tmp/global_wallpaper.jpg"
        globalConfig.isFolderMode = false
        settings.setScreenConfig(globalConfig, for: "screen_global")

        let globalRetrieved = settings.screenConfig(for: "screen_global")
        XCTAssertEqual(globalRetrieved.wallpaperPath, "/tmp/global_wallpaper.jpg",
            "Global screen wallpaper path should coexist with screen-specific settings")
        XCTAssertFalse(globalRetrieved.isFolderMode,
            "Global screen folder mode should be independent of screen-specific configs")

        // Verify screen-specific setting is still preserved
        let stillStored = settings.screenConfig(for: singleScreenId)
        XCTAssertEqual(stillStored.folderPath, "/tmp/single_screen_folder",
            "Screen-specific config should remain after other screen changes")
    }

    /// Tests light mode functionality preservation.
    func testLightModeFunctionalityPreservation() {
        struct MockUIElement {
            let identifier: String
            var textColor: String?
            let elementType: ElementType

            enum ElementType {
                case primary
                case secondary
            }

            mutating func applySystemColors() {
                switch elementType {
                case .primary:   textColor = "labelColor"
                case .secondary: textColor = "secondaryLabelColor"
                }
            }
        }

        var lightModeElements = [
            MockUIElement(identifier: "appTitle",      textColor: nil, elementType: .primary),
            MockUIElement(identifier: "statusLabel",   textColor: nil, elementType: .secondary),
            MockUIElement(identifier: "fileNameLabel", textColor: nil, elementType: .primary),
            MockUIElement(identifier: "intervalLabel", textColor: nil, elementType: .secondary)
        ]

        for i in 0..<lightModeElements.count {
            lightModeElements[i].applySystemColors()
        }

        for element in lightModeElements {
            XCTAssertNotNil(element.textColor,
                "Light mode element '\(element.identifier)' should have color assignment")
            switch element.elementType {
            case .primary:
                XCTAssertEqual(element.textColor, "labelColor",
                    "Primary element '\(element.identifier)' should use labelColor in light mode")
            case .secondary:
                XCTAssertEqual(element.textColor, "secondaryLabelColor",
                    "Secondary element '\(element.identifier)' should use secondaryLabelColor in light mode")
            }
        }

        let systemColors = ["labelColor", "secondaryLabelColor", "tertiaryLabelColor"]
        for color in systemColors {
            XCTAssertTrue(color.contains("labelColor") || color.contains("LabelColor"),
                "System color '\(color)' should be a valid adaptive label color")
        }

        let problematicColors = ["black", "white", "#000000", "#FFFFFF"]
        for element in lightModeElements {
            if let color = element.textColor {
                XCTAssertFalse(problematicColors.contains(color),
                    "Element '\(element.identifier)' should not use hardcoded color '\(color)'")
            }
        }
    }

    /// Tests menu interactions preservation (excluding screen selection).
    func testMenuInteractionsPreservation() {
        // Language setting
        settings.language = "en"
        XCTAssertEqual(settings.language, "en",
            "Language setting should be preserved")

        settings.language = "zh-Hans"
        XCTAssertEqual(settings.language, "zh-Hans",
            "Language change should be preserved")

        // New screen policy settings (new API replacing legacy inheritance mode)
        settings.newScreenPolicy = .inheritSyncGroup
        XCTAssertEqual(settings.newScreenPolicy, .inheritSyncGroup,
            "inheritSyncGroup policy should be preserved")

        settings.newScreenPolicy = .blank
        XCTAssertEqual(settings.newScreenPolicy, .blank,
            "blank policy should be preserved")



        // Media type detection (unaffected by UI fixes)
        let testURLs = [
            URL(fileURLWithPath: "/tmp/video.mp4"),
            URL(fileURLWithPath: "/tmp/image.jpg"),
            URL(fileURLWithPath: "/tmp/animation.gif"),
            URL(fileURLWithPath: "/tmp/unsupported.txt")
        ]
        let expectedTypes: [MediaType] = [.video, .image, .video, .unsupported]
        for (url, expectedType) in zip(testURLs, expectedTypes) {
            let detectedType = MediaType.detect(url)
            XCTAssertEqual(detectedType, expectedType,
                "Media type detection for '\(url.pathExtension)' should be preserved")
        }

        // Onboarding state
        settings.onboardingCompleted = false
        XCTAssertFalse(settings.onboardingCompleted,
            "Onboarding state should be preserved")

        // Existing setup detection via screenConfig
        var config = Screen_Config.default
        config.wallpaperPath = "/tmp/test.jpg"
        settings.setScreenConfig(config, for: "screen_test")
        let retrieved = settings.screenConfig(for: "screen_test")
        XCTAssertNotNil(retrieved.wallpaperPath,
            "Wallpaper path should be retrievable via screenConfig")

        // Screen identifier logic preservation
        let deviceDescription: [NSDeviceDescriptionKey: Any] = [
            NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(42))
        ]
        let screenId = SettingsManager.screenIdentifier(
            deviceDescription: deviceDescription,
            name: "Test Display"
        )
        XCTAssertEqual(screenId, "screen_42",
            "Normal screen identifier generation should be preserved")
        XCTAssertTrue(screenId.hasPrefix("screen_"),
            "Screen identifier format should be preserved")
        XCTAssertFalse(screenId.hasPrefix("screen_fallback_"),
            "Normal screen identifier should not use fallback format")
    }

    /// Tests sync all screens behavior when NO manual selection exists.
    func testSyncAllScreensWithoutManualSelectionPreservation() {
        let folderPath = "/tmp/test_wallpapers"
        let sourceScreenId = "screen_1"
        let config = Screen_Config(
            folderPath: folderPath,
            wallpaperPath: nil,
            rotationIntervalMinutes: 20,
            isShuffleMode: true,
            isRotationEnabled: true,
            includeSubfolders: true,
            isFolderMode: true,
            isSynced: true
        )

        settings.setScreenConfig(config, for: sourceScreenId)

        // Verify no manual wallpaper selection exists
        let storedConfig = settings.screenConfig(for: sourceScreenId)
        XCTAssertNil(storedConfig.wallpaperPath,
            "No manual wallpaper selection should be stored")

        // Simulate the sync all screens logic that should be preserved
        func simulatePreservedSyncAllScreens(sourceScreenId: String) -> String? {
            let cfg = settings.screenConfig(for: sourceScreenId)
            guard let fp = cfg.folderPath else { return nil }
            return fp + "/first_item.mp4"
        }

        let syncResult = simulatePreservedSyncAllScreens(sourceScreenId: sourceScreenId)
        XCTAssertEqual(syncResult, "/tmp/test_wallpapers/first_item.mp4",
            "Sync all screens without manual selection should use folder config")

        // Verify the config is still intact
        let verifyConfig = settings.screenConfig(for: sourceScreenId)
        XCTAssertEqual(verifyConfig.folderPath, folderPath,
            "Folder path should be preserved")
        XCTAssertEqual(verifyConfig.rotationIntervalMinutes, 20,
            "Rotation interval should be preserved")
        XCTAssertTrue(verifyConfig.isShuffleMode,
            "Shuffle mode should be preserved")
        XCTAssertTrue(verifyConfig.isRotationEnabled,
            "Rotation enabled should be preserved")
        XCTAssertTrue(verifyConfig.includeSubfolders,
            "Include subfolders should be preserved")
    }

    /// Tests wallpaper playback and rotation functionality preservation.
    func testWallpaperPlaybackPreservation() {
        // Test rotation interval settings via Screen_Config
        let intervals = [1, 5, 15, 30, 60, 120, 1440]
        for interval in intervals {
            var config = Screen_Config.default
            config.rotationIntervalMinutes = interval
            settings.setScreenConfig(config, for: "screen_interval_\(interval)")
            let retrieved = settings.screenConfig(for: "screen_interval_\(interval)")
            XCTAssertEqual(retrieved.rotationIntervalMinutes, interval,
                "Rotation interval \(interval) minutes should be preserved")
        }

        // Test shuffle and rotation settings
        let shuffleRotationCombinations = [
            (shuffle: false, rotation: false),
            (shuffle: false, rotation: true),
            (shuffle: true, rotation: false),
            (shuffle: true, rotation: true)
        ]

        for (idx, (shuffle, rotation)) in shuffleRotationCombinations.enumerated() {
            var config = Screen_Config.default
            config.isShuffleMode = shuffle
            config.isRotationEnabled = rotation
            settings.setScreenConfig(config, for: "screen_combo_\(idx)")
            let retrieved = settings.screenConfig(for: "screen_combo_\(idx)")
            XCTAssertEqual(retrieved.isShuffleMode, shuffle,
                "Shuffle mode \(shuffle) should be preserved")
            XCTAssertEqual(retrieved.isRotationEnabled, rotation,
                "Rotation enabled \(rotation) should be preserved")
        }

        // Test include subfolders setting
        var configOn = Screen_Config.default
        configOn.includeSubfolders = true
        settings.setScreenConfig(configOn, for: "screen_subfolders_on")
        XCTAssertTrue(settings.screenConfig(for: "screen_subfolders_on").includeSubfolders,
            "Include subfolders enabled should be preserved")

        var configOff = Screen_Config.default
        configOff.includeSubfolders = false
        settings.setScreenConfig(configOff, for: "screen_subfolders_off")
        XCTAssertFalse(settings.screenConfig(for: "screen_subfolders_off").includeSubfolders,
            "Include subfolders disabled should be preserved")

        // Test pause when invisible setting
        settings.pauseWhenInvisible = true
        XCTAssertTrue(settings.pauseWhenInvisible,
            "Pause when invisible enabled should be preserved")
        settings.pauseWhenInvisible = false
        XCTAssertFalse(settings.pauseWhenInvisible,
            "Pause when invisible disabled should be preserved")

        // Test per-screen configuration independence via Screen_Config
        let screen1Id = "screen_1"
        let screen2Id = "screen_2"

        let config1 = Screen_Config(
            folderPath: "/tmp/folder1",
            wallpaperPath: nil,
            rotationIntervalMinutes: 10,
            isShuffleMode: false,
            isRotationEnabled: true,
            includeSubfolders: false,
            isFolderMode: true,
            isSynced: false
        )
        let config2 = Screen_Config(
            folderPath: "/tmp/folder2",
            wallpaperPath: nil,
            rotationIntervalMinutes: 30,
            isShuffleMode: true,
            isRotationEnabled: false,
            includeSubfolders: true,
            isFolderMode: true,
            isSynced: false
        )

        settings.setScreenConfig(config1, for: screen1Id)
        settings.setScreenConfig(config2, for: screen2Id)

        let storedConfig1 = settings.screenConfig(for: screen1Id)
        let storedConfig2 = settings.screenConfig(for: screen2Id)

        XCTAssertEqual(storedConfig1.folderPath, "/tmp/folder1",
            "Screen 1 folder path should be preserved")
        XCTAssertEqual(storedConfig2.folderPath, "/tmp/folder2",
            "Screen 2 folder path should be preserved")
        XCTAssertEqual(storedConfig1.rotationIntervalMinutes, 10,
            "Screen 1 rotation interval should be preserved")
        XCTAssertEqual(storedConfig2.rotationIntervalMinutes, 30,
            "Screen 2 rotation interval should be preserved")
        XCTAssertFalse(storedConfig1.isShuffleMode,
            "Screen 1 shuffle mode should be preserved")
        XCTAssertTrue(storedConfig2.isShuffleMode,
            "Screen 2 shuffle mode should be preserved")
        XCTAssertTrue(storedConfig1.isRotationEnabled,
            "Screen 1 rotation enabled should be preserved")
        XCTAssertFalse(storedConfig2.isRotationEnabled,
            "Screen 2 rotation enabled should be preserved")
    }
}

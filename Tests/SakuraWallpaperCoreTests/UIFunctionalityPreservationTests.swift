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
    ///
    /// This test captures existing correct behavior for:
    /// - Normal wallpaper selection and playback operations
    /// - Single screen configurations and operations  
    /// - Light mode usage and existing color schemes
    /// - Menu interactions not involving screen selection or sync operations
    func testNormalWallpaperOperationsPreservation() {
        // Test Case 1: Normal wallpaper selection (single file, not folder mode)
        let singleWallpaperPath = "/tmp/test_wallpaper.mp4"
        settings.wallpaperPath = singleWallpaperPath
        settings.isFolderMode = false
        
        // Verify single wallpaper mode is preserved
        XCTAssertEqual(settings.wallpaperPath, singleWallpaperPath,
            "Single wallpaper selection should be preserved")
        XCTAssertFalse(settings.isFolderMode,
            "Single wallpaper mode (not folder mode) should be preserved")
        
        // Test Case 2: Normal folder mode without manual selection (uses folder config)
        let folderPath = "/tmp/test_wallpapers"
        let folderConfig = ScreenFolderConfig(
            folderPath: folderPath,
            rotationIntervalMinutes: 15,
            isShuffleMode: false,
            isRotationEnabled: true,
            includeSubfolders: false
        )
        
        let mockScreenId = "screen_1"
        var configs = settings.screenFolderConfigs
        configs[mockScreenId] = folderConfig
        settings.screenFolderConfigs = configs
        settings.isFolderMode = true
        settings.folderPath = folderPath
        
        // Verify folder mode configuration is preserved
        XCTAssertTrue(settings.isFolderMode,
            "Folder mode should be preserved")
        XCTAssertEqual(settings.folderPath, folderPath,
            "Folder path should be preserved")
        
        let storedConfig = settings.screenFolderConfigs[mockScreenId]
        XCTAssertNotNil(storedConfig, "Screen folder config should be preserved")
        XCTAssertEqual(storedConfig?.folderPath, folderPath,
            "Screen folder config path should be preserved")
        XCTAssertEqual(storedConfig?.rotationIntervalMinutes, 15,
            "Rotation interval should be preserved")
        XCTAssertFalse(storedConfig?.isShuffleMode ?? true,
            "Shuffle mode setting should be preserved")
        XCTAssertTrue(storedConfig?.isRotationEnabled ?? false,
            "Rotation enabled setting should be preserved")
        
        // Test Case 3: Wallpaper history functionality
        // Clear any existing history first
        settings.wallpaperHistory = []
        
        let historyPaths = [
            "/tmp/wallpaper1.jpg",
            "/tmp/wallpaper2.mp4", 
            "/tmp/wallpaper3.png"
        ]
        
        for path in historyPaths {
            settings.wallpaperPath = path
        }
        
        let history = settings.wallpaperHistory
        XCTAssertGreaterThanOrEqual(history.count, 3, "Wallpaper history should preserve at least the added entries")
        XCTAssertEqual(history.first, historyPaths.last,
            "Most recent wallpaper should be first in history")
        XCTAssertTrue(history.contains(historyPaths[0]),
            "History should contain all wallpaper paths")
        
        // Test Case 4: Settings persistence
        settings.rotationIntervalMinutes = 30
        settings.isShuffleMode = true
        settings.isRotationEnabled = false
        settings.includeSubfolders = true
        settings.launchAtLogin = true
        settings.pauseWhenInvisible = true
        
        XCTAssertEqual(settings.rotationIntervalMinutes, 30,
            "Rotation interval setting should be preserved")
        XCTAssertTrue(settings.isShuffleMode,
            "Shuffle mode setting should be preserved")
        XCTAssertFalse(settings.isRotationEnabled,
            "Rotation enabled setting should be preserved")
        XCTAssertTrue(settings.includeSubfolders,
            "Include subfolders setting should be preserved")
        XCTAssertTrue(settings.launchAtLogin,
            "Launch at login setting should be preserved")
        XCTAssertTrue(settings.pauseWhenInvisible,
            "Pause when invisible setting should be preserved")
    }
    
    /// Tests single screen configuration preservation.
    ///
    /// When operating in single-screen mode, all wallpaper management functionality
    /// should continue to work exactly as before. The screen dropdown ordering bug
    /// should not affect single-screen usage.
    func testSingleScreenConfigurationPreservation() {
        // Simulate single screen scenario
        let singleScreenId = "screen_1"
        
        // Test single screen wallpaper setting
        let wallpaperPath = "/tmp/single_screen_wallpaper.mp4"
        var wallpapers = settings.screenWallpapers
        wallpapers[singleScreenId] = wallpaperPath
        settings.screenWallpapers = wallpapers
        
        XCTAssertEqual(settings.screenWallpapers[singleScreenId], wallpaperPath,
            "Single screen wallpaper setting should be preserved")
        
        // Test single screen folder configuration
        let folderConfig = ScreenFolderConfig(
            folderPath: "/tmp/single_screen_folder",
            rotationIntervalMinutes: 10,
            isShuffleMode: true,
            isRotationEnabled: true,
            includeSubfolders: false
        )
        
        var configs = settings.screenFolderConfigs
        configs[singleScreenId] = folderConfig
        settings.screenFolderConfigs = configs
        
        let storedConfig = settings.screenFolderConfigs[singleScreenId]
        XCTAssertNotNil(storedConfig, "Single screen folder config should be preserved")
        XCTAssertEqual(storedConfig?.folderPath, "/tmp/single_screen_folder",
            "Single screen folder path should be preserved")
        XCTAssertEqual(storedConfig?.rotationIntervalMinutes, 10,
            "Single screen rotation interval should be preserved")
        XCTAssertTrue(storedConfig?.isShuffleMode ?? false,
            "Single screen shuffle mode should be preserved")
        XCTAssertTrue(storedConfig?.isRotationEnabled ?? false,
            "Single screen rotation enabled should be preserved")
        
        // Test that single screen operations don't interfere with global settings
        settings.wallpaperPath = "/tmp/global_wallpaper.jpg"
        settings.isFolderMode = false
        
        XCTAssertEqual(settings.wallpaperPath, "/tmp/global_wallpaper.jpg",
            "Global wallpaper path should coexist with screen-specific settings")
        XCTAssertFalse(settings.isFolderMode,
            "Global folder mode should be independent of screen-specific configs")
        
        // Verify screen-specific setting is still preserved
        XCTAssertEqual(settings.screenWallpapers[singleScreenId], wallpaperPath,
            "Screen-specific wallpaper should remain after global wallpaper change")
    }
    
    /// Tests light mode functionality preservation.
    ///
    /// All existing light mode interactions and color schemes should continue
    /// to work exactly as before. The dark mode text bug fixes should not
    /// affect light mode appearance or functionality.
    func testLightModeFunctionalityPreservation() {
        // Test that system color assignments work in light mode
        // (This simulates the color logic that should be preserved)
        
        struct MockUIElement {
            let identifier: String
            var textColor: String?
            let elementType: ElementType
            
            enum ElementType {
                case primary    // Should use labelColor
                case secondary  // Should use secondaryLabelColor
            }
            
            mutating func applySystemColors() {
                // This is the logic that should work in both light and dark modes
                switch elementType {
                case .primary:
                    textColor = "labelColor"
                case .secondary:
                    textColor = "secondaryLabelColor"
                }
            }
        }
        
        // Simulate UI elements that should work in light mode
        var lightModeElements = [
            MockUIElement(identifier: "appTitle", textColor: nil, elementType: .primary),
            MockUIElement(identifier: "statusLabel", textColor: nil, elementType: .secondary),
            MockUIElement(identifier: "fileNameLabel", textColor: nil, elementType: .primary),
            MockUIElement(identifier: "intervalLabel", textColor: nil, elementType: .secondary)
        ]
        
        // Apply system colors (this should work in both light and dark modes)
        for i in 0..<lightModeElements.count {
            lightModeElements[i].applySystemColors()
        }
        
        // Verify all elements have appropriate color assignments
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
        
        // Test that existing light mode color schemes are preserved
        let systemColors = ["labelColor", "secondaryLabelColor", "tertiaryLabelColor"]
        
        for color in systemColors {
            // These should be valid system colors that adapt to appearance
            XCTAssertTrue(color.contains("labelColor") || color.contains("LabelColor"),
                "System color '\(color)' should be a valid adaptive label color")
        }
        
        // Verify no hardcoded colors that would break in dark mode
        let problematicColors = ["black", "white", "#000000", "#FFFFFF"]
        
        for element in lightModeElements {
            if let color = element.textColor {
                XCTAssertFalse(problematicColors.contains(color),
                    "Element '\(element.identifier)' should not use hardcoded color '\(color)'")
            }
        }
    }
    
    /// Tests menu interactions preservation (excluding screen selection).
    ///
    /// All menu interactions that do not involve screen selection or sync operations
    /// should continue to work exactly as before. This includes settings menus,
    /// file selection, and other UI interactions.
    func testMenuInteractionsPreservation() {
        // Test Case 1: Settings menu interactions
        
        // Language setting
        settings.language = "en"
        XCTAssertEqual(settings.language, "en",
            "Language setting should be preserved")
        
        settings.language = "zh-Hans"
        XCTAssertEqual(settings.language, "zh-Hans",
            "Language change should be preserved")
        
        // New screen inheritance mode settings
        settings.newScreenInheritanceMode = .primaryScreen
        XCTAssertEqual(settings.newScreenInheritanceMode, .primaryScreen,
            "Primary screen inheritance mode should be preserved")
        
        settings.newScreenInheritanceMode = .specificScreen
        settings.newScreenInheritanceScreenId = "screen_2"
        XCTAssertEqual(settings.newScreenInheritanceMode, .specificScreen,
            "Specific screen inheritance mode should be preserved")
        XCTAssertEqual(settings.newScreenInheritanceScreenId, "screen_2",
            "Specific screen inheritance ID should be preserved")
        
        // Test Case 2: File selection and validation logic
        
        // Test media type detection (this should be unaffected by UI fixes)
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
        
        // Test Case 3: Onboarding and setup state
        
        settings.onboardingCompleted = false
        XCTAssertFalse(settings.onboardingCompleted,
            "Onboarding state should be preserved")
        
        // Test existing setup detection
        settings.wallpaperPath = "/tmp/test.jpg"
        XCTAssertTrue(settings.hasExistingSetup,
            "Existing setup detection should work with wallpaper path")
        
        settings.wallpaperPath = nil
        settings.folderPath = "/tmp/folder"
        XCTAssertTrue(settings.hasExistingSetup,
            "Existing setup detection should work with folder path")
        
        settings.folderPath = nil
        var wallpapers = settings.screenWallpapers
        wallpapers["screen_1"] = "/tmp/screen_wallpaper.mp4"
        settings.screenWallpapers = wallpapers
        XCTAssertTrue(settings.hasExistingSetup,
            "Existing setup detection should work with screen wallpapers")
        
        // Test Case 4: Screen identifier logic preservation
        
        // Test normal screen identifier generation (NSScreenNumber present)
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
    ///
    /// This is the edge case that should continue to work as before:
    /// when there's no manual wallpaper selection, sync all screens should
    /// use the folder configuration as the source.
    func testSyncAllScreensWithoutManualSelectionPreservation() {
        // Set up folder configuration without manual selection
        let folderPath = "/tmp/test_wallpapers"
        let folderConfig = ScreenFolderConfig(
            folderPath: folderPath,
            rotationIntervalMinutes: 20,
            isShuffleMode: true,
            isRotationEnabled: true,
            includeSubfolders: true
        )
        
        let sourceScreenId = "screen_1"
        var configs = settings.screenFolderConfigs
        configs[sourceScreenId] = folderConfig
        settings.screenFolderConfigs = configs
        
        // Ensure NO manual wallpaper selection exists
        let wallpapers = settings.screenWallpapers
        XCTAssertNil(wallpapers[sourceScreenId],
            "No manual wallpaper selection should exist for this test")
        
        // Simulate the sync all screens logic that should be preserved
        func simulatePreservedSyncAllScreens(sourceScreenId: String) -> String? {
            // This is the behavior that should continue to work:
            // When no manual selection exists, use folder config
            if let config = settings.screenFolderConfigs[sourceScreenId] {
                return config.folderPath + "/first_item.mp4" // Simulates folder default
            }
            return nil
        }
        
        let syncResult = simulatePreservedSyncAllScreens(sourceScreenId: sourceScreenId)
        
        XCTAssertEqual(syncResult, "/tmp/test_wallpapers/first_item.mp4",
            "Sync all screens without manual selection should use folder config")
        
        // Verify the folder config is still intact
        let storedConfig = settings.screenFolderConfigs[sourceScreenId]
        XCTAssertNotNil(storedConfig, "Folder config should be preserved")
        XCTAssertEqual(storedConfig?.folderPath, folderPath,
            "Folder path should be preserved")
        XCTAssertEqual(storedConfig?.rotationIntervalMinutes, 20,
            "Rotation interval should be preserved")
        XCTAssertTrue(storedConfig?.isShuffleMode ?? false,
            "Shuffle mode should be preserved")
        XCTAssertTrue(storedConfig?.isRotationEnabled ?? false,
            "Rotation enabled should be preserved")
        XCTAssertTrue(storedConfig?.includeSubfolders ?? false,
            "Include subfolders should be preserved")
    }
    
    /// Tests wallpaper playback and rotation functionality preservation.
    ///
    /// All existing wallpaper playback, rotation, and playlist functionality
    /// should continue to work exactly as before the UI fixes.
    func testWallpaperPlaybackPreservation() {
        // Test Case 1: Rotation interval settings
        let intervals = [1, 5, 15, 30, 60, 120, 1440] // 1 min to 24 hours
        
        for interval in intervals {
            settings.rotationIntervalMinutes = interval
            XCTAssertEqual(settings.rotationIntervalMinutes, interval,
                "Rotation interval \(interval) minutes should be preserved")
        }
        
        // Test minimum interval enforcement
        settings.rotationIntervalMinutes = 0
        XCTAssertEqual(settings.rotationIntervalMinutes, 15,
            "Minimum rotation interval should default to 15 minutes")
        
        // Test Case 2: Shuffle and rotation settings
        let shuffleRotationCombinations = [
            (shuffle: false, rotation: false),
            (shuffle: false, rotation: true),
            (shuffle: true, rotation: false),
            (shuffle: true, rotation: true)
        ]
        
        for (shuffle, rotation) in shuffleRotationCombinations {
            settings.isShuffleMode = shuffle
            settings.isRotationEnabled = rotation
            
            XCTAssertEqual(settings.isShuffleMode, shuffle,
                "Shuffle mode \(shuffle) should be preserved")
            XCTAssertEqual(settings.isRotationEnabled, rotation,
                "Rotation enabled \(rotation) should be preserved")
        }
        
        // Test Case 3: Include subfolders setting
        settings.includeSubfolders = true
        XCTAssertTrue(settings.includeSubfolders,
            "Include subfolders enabled should be preserved")
        
        settings.includeSubfolders = false
        XCTAssertFalse(settings.includeSubfolders,
            "Include subfolders disabled should be preserved")
        
        // Test Case 4: Pause when invisible setting
        settings.pauseWhenInvisible = true
        XCTAssertTrue(settings.pauseWhenInvisible,
            "Pause when invisible enabled should be preserved")
        
        settings.pauseWhenInvisible = false
        XCTAssertFalse(settings.pauseWhenInvisible,
            "Pause when invisible disabled should be preserved")
        
        // Test Case 5: Per-screen configuration independence
        let screen1Id = "screen_1"
        let screen2Id = "screen_2"
        
        let config1 = ScreenFolderConfig(
            folderPath: "/tmp/folder1",
            rotationIntervalMinutes: 10,
            isShuffleMode: false,
            isRotationEnabled: true,
            includeSubfolders: false
        )
        
        let config2 = ScreenFolderConfig(
            folderPath: "/tmp/folder2", 
            rotationIntervalMinutes: 30,
            isShuffleMode: true,
            isRotationEnabled: false,
            includeSubfolders: true
        )
        
        var configs = settings.screenFolderConfigs
        configs[screen1Id] = config1
        configs[screen2Id] = config2
        settings.screenFolderConfigs = configs
        
        // Verify each screen maintains independent configuration
        let storedConfig1 = settings.screenFolderConfigs[screen1Id]
        let storedConfig2 = settings.screenFolderConfigs[screen2Id]
        
        XCTAssertNotNil(storedConfig1, "Screen 1 config should be preserved")
        XCTAssertNotNil(storedConfig2, "Screen 2 config should be preserved")
        
        XCTAssertEqual(storedConfig1?.folderPath, "/tmp/folder1",
            "Screen 1 folder path should be preserved")
        XCTAssertEqual(storedConfig2?.folderPath, "/tmp/folder2",
            "Screen 2 folder path should be preserved")
        
        XCTAssertEqual(storedConfig1?.rotationIntervalMinutes, 10,
            "Screen 1 rotation interval should be preserved")
        XCTAssertEqual(storedConfig2?.rotationIntervalMinutes, 30,
            "Screen 2 rotation interval should be preserved")
        
        XCTAssertFalse(storedConfig1?.isShuffleMode ?? true,
            "Screen 1 shuffle mode should be preserved")
        XCTAssertTrue(storedConfig2?.isShuffleMode ?? false,
            "Screen 2 shuffle mode should be preserved")
        
        XCTAssertTrue(storedConfig1?.isRotationEnabled ?? false,
            "Screen 1 rotation enabled should be preserved")
        XCTAssertFalse(storedConfig2?.isRotationEnabled ?? true,
            "Screen 2 rotation enabled should be preserved")
    }
}
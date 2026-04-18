import XCTest
@testable import SakuraWallpaperCore

final class SettingsManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: SettingsManager!
    private var suiteName: String!

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

    func testWallpaperHistoryDeduplicatesAndCapsAtTen() {
        for index in 0..<12 {
            settings.addToHistory("/tmp/\(index).jpg")
        }
        settings.addToHistory("/tmp/5.jpg")

        XCTAssertEqual(settings.wallpaperHistory.count, 10)
        XCTAssertEqual(settings.wallpaperHistory.first, "/tmp/5.jpg")
    }

    func testOnboardingCompletedPersists() {
        settings.onboardingCompleted = true
        XCTAssertTrue(settings.onboardingCompleted)
    }

    func testScreenConfigRoundTrip() {
        let screenID = "screen_42"
        var config = Screen_Config.default
        config.folderPath = "/tmp/wallpapers"
        config.rotationIntervalMinutes = 30
        config.isShuffleMode = true

        settings.setScreenConfig(config, for: screenID)
        let retrieved = settings.screenConfig(for: screenID)

        XCTAssertEqual(retrieved.folderPath, "/tmp/wallpapers")
        XCTAssertEqual(retrieved.rotationIntervalMinutes, 30)
        XCTAssertTrue(retrieved.isShuffleMode)
    }

    func testScreenConfigDefaultForUnknownScreen() {
        let config = settings.screenConfig(for: "nonexistent_screen")
        XCTAssertEqual(config, Screen_Config.default)
    }
}

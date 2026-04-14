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
            settings.wallpaperPath = "/tmp/\(index).jpg"
        }
        settings.wallpaperPath = "/tmp/5.jpg"

        XCTAssertEqual(settings.wallpaperHistory.count, 10)
        XCTAssertEqual(settings.wallpaperHistory.first, "/tmp/5.jpg")
    }

    func testIncludeSubfoldersPersists() {
        settings.includeSubfolders = true
        XCTAssertTrue(settings.includeSubfolders)
    }

    func testOnboardingCompletedPersists() {
        settings.onboardingCompleted = true
        XCTAssertTrue(settings.onboardingCompleted)
    }
}

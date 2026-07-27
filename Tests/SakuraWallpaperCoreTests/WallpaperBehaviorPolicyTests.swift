import XCTest
@testable import SakuraWallpaperCore

final class WallpaperBehaviorPolicyTests: XCTestCase {
    func testDesktopIsCoveredByFullscreenWindow() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        XCTAssertTrue(WallpaperBehavior.isScreenCovered(screen, by: screen))
    }

    func testDesktopIsNotCoveredByRegularWindow() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let window = CGRect(x: 200, y: 150, width: 1100, height: 700)

        XCTAssertFalse(WallpaperBehavior.isScreenCovered(screen, by: window))
    }

    func testDesktopCoverageUsesQuartzCoordinatesForSecondaryScreen() {
        let screen = CGRect(x: -2560, y: 0, width: 2560, height: 1440)
        let window = CGRect(x: -2560, y: 0, width: 2560, height: 1400)

        XCTAssertTrue(WallpaperBehavior.isScreenCovered(screen, by: window))
    }

    func testDisablingDesktopSyncRequestsRestoreWhenOriginalDesktopExists() {
        let action = WallpaperBehavior.desktopSyncAction(
            wasEnabled: true,
            isEnabled: false,
            hasOriginalDesktopRecord: true
        )

        XCTAssertEqual(action, .restoreOriginalDesktop)
    }

    func testDisablingDesktopSyncDoesNotRestoreWhenNoOriginalDesktopExists() {
        let action = WallpaperBehavior.desktopSyncAction(
            wasEnabled: true,
            isEnabled: false,
            hasOriginalDesktopRecord: false
        )

        XCTAssertEqual(action, .none)
    }

    func testBatterySaverPausesWhenDesktopIsCoveredEvenWithHealthyBattery() {
        let shouldPause = WallpaperBehavior.shouldAutoPausePlayback(
            pauseWhenInvisibleEnabled: true,
            batteryLevel: 88,
            isCharging: true,
            isDesktopCovered: true
        )

        XCTAssertTrue(shouldPause)
    }

    func testBatterySaverPausesOnLowBatteryWhenDesktopRemainsVisible() {
        let shouldPause = WallpaperBehavior.shouldAutoPausePlayback(
            pauseWhenInvisibleEnabled: true,
            batteryLevel: 20,
            isCharging: false,
            isDesktopCovered: false
        )

        XCTAssertTrue(shouldPause)
    }

    func testBatterySaverDoesNotPauseWhenDisabled() {
        let shouldPause = WallpaperBehavior.shouldAutoPausePlayback(
            pauseWhenInvisibleEnabled: false,
            batteryLevel: 5,
            isCharging: false,
            isDesktopCovered: true
        )

        XCTAssertFalse(shouldPause)
    }
}

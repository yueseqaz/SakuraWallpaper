import XCTest
@testable import SakuraWallpaperCore

/// Bug condition exploration tests for SettingsManager.screenIdentifier.
///
/// These tests encode the EXPECTED (fixed) behavior.
/// They MUST FAIL on unfixed code — failure confirms Bug 3 exists.
/// They will PASS after the fix is applied in task 3.1.
///
/// Bug 3: When NSScreenNumber is unavailable, the fallback returns UUID().uuidString,
/// which produces a different string on every call. The same physical screen is treated
/// as a brand-new screen on every topology change, losing its saved config and creating
/// orphaned player entries.
final class ScreenIdentifierBugConditionTests: XCTestCase {

    // MARK: - Bug 3: UUID fallback is non-deterministic

    /// Calls screenIdentifier twice with a device description that has NO NSScreenNumber.
    /// On unfixed code: returns two different UUID strings → test FAILS (counterexample found).
    /// On fixed code: returns the same deterministic fallback string → test PASSES.
    func testScreenIdentifierWithoutNSScreenNumberIsDeterministic() {
        // Device description with no NSScreenNumber — simulates a virtual display,
        // certain USB-C adapters, or a screen during a brief topology transition.
        let deviceDescription: [NSDeviceDescriptionKey: Any] = [
            NSDeviceDescriptionKey("NSDeviceSize"): NSValue(size: NSSize(width: 2560, height: 1440)),
            NSDeviceDescriptionKey("NSDeviceResolution"): NSValue(size: NSSize(width: 72, height: 72))
        ]

        let first  = SettingsManager.screenIdentifier(deviceDescription: deviceDescription, name: "External Display")
        let second = SettingsManager.screenIdentifier(deviceDescription: deviceDescription, name: "External Display")

        // EXPECTED (fixed): both calls return the same string.
        // ACTUAL (unfixed): first and second are different UUID strings.
        XCTAssertEqual(first, second,
            "screenIdentifier must return the same string on every call for the same screen. " +
            "Counterexample: '\(first)' vs '\(second)'")
    }

    /// Verifies the fallback identifier does NOT look like a UUID (which would indicate
    /// the unfixed code path is still active).
    func testScreenIdentifierFallbackIsNotAUUID() {
        let deviceDescription: [NSDeviceDescriptionKey: Any] = [:]

        let id = SettingsManager.screenIdentifier(deviceDescription: deviceDescription, name: "Test Display")

        // A UUID string is 36 characters in the form 8-4-4-4-12 hex digits.
        // The fixed fallback should start with "screen_fallback_".
        XCTAssertTrue(id.hasPrefix("screen_fallback_"),
            "Fallback identifier should start with 'screen_fallback_', got: '\(id)'")
    }

    /// Verifies that two screens with different names produce different fallback identifiers,
    /// preventing cross-screen config collisions.
    func testScreenIdentifierFallbackDifferentiatesByName() {
        let desc: [NSDeviceDescriptionKey: Any] = [:]

        let idA = SettingsManager.screenIdentifier(deviceDescription: desc, name: "Display A")
        let idB = SettingsManager.screenIdentifier(deviceDescription: desc, name: "Display B")

        XCTAssertNotEqual(idA, idB,
            "Different screen names must produce different fallback identifiers")
    }

    /// Verifies that two screens with the same name but different resolutions produce
    /// different fallback identifiers (e.g. two identical monitors at different resolutions).
    func testScreenIdentifierFallbackDifferentiatesByResolution() {
        let desc1080: [NSDeviceDescriptionKey: Any] = [
            NSDeviceDescriptionKey("NSDeviceSize"): NSValue(size: NSSize(width: 1920, height: 1080))
        ]
        let desc4K: [NSDeviceDescriptionKey: Any] = [
            NSDeviceDescriptionKey("NSDeviceSize"): NSValue(size: NSSize(width: 3840, height: 2160))
        ]

        let id1080 = SettingsManager.screenIdentifier(deviceDescription: desc1080, name: "LG UltraFine")
        let id4K   = SettingsManager.screenIdentifier(deviceDescription: desc4K,   name: "LG UltraFine")

        XCTAssertNotEqual(id1080, id4K,
            "Same screen name but different resolutions must produce different fallback identifiers")
    }
}

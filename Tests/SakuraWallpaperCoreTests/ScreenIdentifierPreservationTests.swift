import XCTest
@testable import SakuraWallpaperCore

/// Preservation tests for SettingsManager.screenIdentifier.
///
/// These tests encode the EXISTING correct behavior for inputs where the bug condition
/// does NOT hold (NSScreenNumber IS present). They must PASS on both unfixed and fixed code.
///
/// Requirement 3.2: When NSScreenNumber IS present, screenIdentifier must continue to
/// return "screen_<CGDirectDisplayID>" — identical to the original behavior.
final class ScreenIdentifierPreservationTests: XCTestCase {

    // MARK: - Preservation: NSScreenNumber present → "screen_<id>" format unchanged

    func testScreenIdentifierWithNSScreenNumberReturnsExpectedFormat() {
        let deviceDescription: [NSDeviceDescriptionKey: Any] = [
            NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(1))
        ]
        let id = SettingsManager.screenIdentifier(deviceDescription: deviceDescription, name: "Built-in Retina Display")
        XCTAssertEqual(id, "screen_1")
    }

    func testScreenIdentifierWithNSScreenNumberUsesUInt32Value() {
        // Verify the uint32Value is used, not intValue, to match the original implementation.
        let deviceDescription: [NSDeviceDescriptionKey: Any] = [
            NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(69))
        ]
        let id = SettingsManager.screenIdentifier(deviceDescription: deviceDescription, name: "External Display")
        XCTAssertEqual(id, "screen_69")
    }

    /// Property-based style: verify "screen_<id>" format across a representative range of
    /// CGDirectDisplayID values (UInt32 domain).
    func testScreenIdentifierFormatPreservedAcrossRepresentativeDisplayIDs() {
        let representativeIDs: [UInt32] = [
            1,
            69,
            256,
            65535,
            65536,
            UInt32.max / 2,
            UInt32.max
        ]

        for displayID in representativeIDs {
            let deviceDescription: [NSDeviceDescriptionKey: Any] = [
                NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: displayID)
            ]
            let id = SettingsManager.screenIdentifier(deviceDescription: deviceDescription, name: "Display")
            XCTAssertEqual(id, "screen_\(displayID)",
                "Expected 'screen_\(displayID)' for displayID \(displayID), got '\(id)'")
        }
    }

    /// Verifies the "screen_<id>" format does NOT start with "screen_fallback_",
    /// confirming the primary path is taken when NSScreenNumber is present.
    func testScreenIdentifierWithNSScreenNumberDoesNotUseFallbackPath() {
        let deviceDescription: [NSDeviceDescriptionKey: Any] = [
            NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(12345))
        ]
        let id = SettingsManager.screenIdentifier(deviceDescription: deviceDescription, name: "Test Display")
        XCTAssertFalse(id.hasPrefix("screen_fallback_"),
            "Primary path (NSScreenNumber present) must not use the fallback format")
        XCTAssertEqual(id, "screen_12345")
    }

    /// Verifies that two different display IDs produce different identifiers,
    /// preserving per-screen config isolation.
    func testScreenIdentifierDifferentDisplayIDsProduceDifferentIdentifiers() {
        let desc1: [NSDeviceDescriptionKey: Any] = [NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(1))]
        let desc2: [NSDeviceDescriptionKey: Any] = [NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(2))]

        let id1 = SettingsManager.screenIdentifier(deviceDescription: desc1, name: "Display 1")
        let id2 = SettingsManager.screenIdentifier(deviceDescription: desc2, name: "Display 2")

        XCTAssertNotEqual(id1, id2)
    }
}

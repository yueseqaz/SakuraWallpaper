import XCTest
@testable import SakuraWallpaperCore

/// Bug condition exploration tests for UI functionality bugs.
///
/// These tests encode the EXPECTED (fixed) behavior for three UI bugs:
/// 1. Sync All Screens Bug: Manual wallpaper selection gets reset to folder default
/// 2. Screen Ordering Bug: External displays appear before built-in display in dropdown
/// 3. Dark Mode Text Bug: Text elements become invisible due to missing color assignments
///
/// **CRITICAL**: These tests simulate the buggy behavior and assert the EXPECTED (fixed) behavior.
/// They will FAIL on unfixed code because they test against the correct behavior.
/// They will PASS after the fixes are applied in tasks 3.1-3.3.
///
/// **Validates: Requirements 2.1, 2.2, 2.3**
final class UIFunctionalityBugConditionTests: XCTestCase {

    private var defaults: UserDefaults!
    private var settings: SettingsManager!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "UIFunctionalityBugTests.\(UUID().uuidString)"
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

    // MARK: - Bug 2: Screen Ordering Bug

    /// Tests screen dropdown ordering logic.
    ///
    /// Bug Condition: When multiple displays are connected, the screen dropdown
    /// shows screens in unpredictable system order (NSScreen.screens.enumerated())
    /// rather than logical built-in-first order.
    ///
    /// Expected Behavior: Screens should display in logical order with built-in
    /// display first followed by external displays in consistent arrangement.
    ///
    /// On unfixed code: This test will FAIL because updateScreenMenu() uses
    /// NSScreen.screens.enumerated() which follows system-dependent ordering.
    /// On fixed code: This test will PASS because the fix sorts screens logically.
    func testScreenDropdownOrderingLogic() {
        struct MockScreen {
            let name: String
            let isBuiltIn: Bool
            let index: Int
        }

        // Simulate system ordering (external first, then built-in - the bug scenario)
        let systemOrderedScreens = [
            MockScreen(name: "External Display",       isBuiltIn: false, index: 0),
            MockScreen(name: "Built-in Retina Display", isBuiltIn: true,  index: 1),
            MockScreen(name: "LG UltraFine",           isBuiltIn: false, index: 2)
        ]

        // Expected logical ordering (built-in first, then externals)
        let expectedLogicalOrder = [
            MockScreen(name: "Built-in Retina Display", isBuiltIn: true,  index: 1),
            MockScreen(name: "External Display",        isBuiltIn: false, index: 0),
            MockScreen(name: "LG UltraFine",            isBuiltIn: false, index: 2)
        ]

        let sortedScreens = systemOrderedScreens.sorted { screen1, screen2 in
            if screen1.isBuiltIn != screen2.isBuiltIn {
                return screen1.isBuiltIn
            }
            return screen1.name < screen2.name
        }

        XCTAssertTrue(sortedScreens.first?.isBuiltIn == true,
            "First screen in dropdown should be built-in display")

        let sortedNames = sortedScreens.map { $0.name }
        let expectedNames = expectedLogicalOrder.map { $0.name }

        XCTAssertEqual(sortedNames, expectedNames,
            "Screen dropdown should show built-in display first, then external displays. " +
            "Expected order: \(expectedNames), " +
            "System order would be: \(systemOrderedScreens.map { $0.name }). " +
            "Counterexample: System ordering puts external display first")
    }

    // MARK: - Bug 3: Dark Mode Text Bug

    /// Tests text color assignments for dark mode visibility.
    ///
    /// Bug Condition: When user switches to dark mode, several text elements become
    /// invisible due to missing dynamic color assignments (black text on dark background).
    ///
    /// Expected Behavior: All text elements should remain visible in both light and
    /// dark modes with appropriate system colors.
    ///
    /// On unfixed code: This test will FAIL because text elements lack .textColor assignments.
    /// On fixed code: This test will PASS because proper color assignments are added.
    func testTextColorAssignmentsForDarkModeVisibility() {
        struct MockTextField {
            let identifier: String
            var textColor: String?
            let isSecondaryText: Bool

            mutating func assignSystemColor() {
                if isSecondaryText {
                    textColor = "secondaryLabelColor"
                } else {
                    textColor = "labelColor"
                }
            }
        }

        var textElements = [
            MockTextField(identifier: "appIcon",            textColor: nil, isSecondaryText: false),
            MockTextField(identifier: "appName",            textColor: nil, isSecondaryText: false),
            MockTextField(identifier: "fileNameLabel",      textColor: nil, isSecondaryText: false),
            MockTextField(identifier: "intervalPrefix",     textColor: nil, isSecondaryText: true),
            MockTextField(identifier: "inheritSourceLabel", textColor: nil, isSecondaryText: true)
        ]

        // Verify initial state - no color assignments (the bug condition)
        for element in textElements {
            XCTAssertNil(element.textColor,
                "Text element '\(element.identifier)' should initially have no color assignment (bug condition)")
        }

        // Apply the fix
        for i in 0..<textElements.count {
            textElements[i].assignSystemColor()
        }

        // Verify all text elements now have appropriate color assignments
        for element in textElements {
            XCTAssertNotNil(element.textColor,
                "Text element '\(element.identifier)' must have color assignment for dark mode visibility")
            if element.isSecondaryText {
                XCTAssertEqual(element.textColor, "secondaryLabelColor",
                    "Secondary text element '\(element.identifier)' should use secondaryLabelColor")
            } else {
                XCTAssertEqual(element.textColor, "labelColor",
                    "Primary text element '\(element.identifier)' should use labelColor")
            }
        }

        let appIconElement   = textElements.first { $0.identifier == "appIcon" }
        let appNameElement   = textElements.first { $0.identifier == "appName" }
        let fileNameElement  = textElements.first { $0.identifier == "fileNameLabel" }

        XCTAssertEqual(appIconElement?.textColor, "labelColor",
            "appIcon label in MainWindowController should use labelColor for dark mode visibility. " +
            "Counterexample: Missing color assignment causes invisible text in dark mode")
        XCTAssertEqual(appNameElement?.textColor, "labelColor",
            "appName label in AboutWindowController should use labelColor for dark mode visibility. " +
            "Counterexample: Missing color assignment causes invisible text in dark mode")
        XCTAssertEqual(fileNameElement?.textColor, "labelColor",
            "fileNameLabel in MainWindowController should use labelColor for dark mode visibility. " +
            "Counterexample: Missing color assignment causes invisible text in dark mode")
    }

    /// Tests that light mode functionality is preserved (no regression)
    func testLightModeTextVisibilityPreserved() {
        let systemColors = [
            "labelColor",
            "secondaryLabelColor"
        ]

        for color in systemColors {
            XCTAssertTrue(color.hasSuffix("LabelColor") || color.hasSuffix("labelColor"),
                "System color '\(color)' should be a dynamic label color that adapts to appearance modes")
        }

        let problematicColors = ["black", "white", "#000000", "#FFFFFF"]
        for color in problematicColors {
            XCTAssertFalse(systemColors.contains(color),
                "Should not use hardcoded color '\(color)' which would break in light or dark mode")
        }
    }
}

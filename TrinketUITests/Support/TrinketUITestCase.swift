import XCTest

enum TestLaunchArg {
    static func tab(_ tab: String) -> String {
        "-selectedTab \(tab)"
    }

    static let resetState = "-reset-state"
    static let seedTestProgress = "-seed-test-progress"
    static let disableCloudSync = "-disable-cloud-sync"
    static let testLaunchArgs = [
        resetState,
        seedTestProgress,
        disableCloudSync,
        "-disable-audio",
        "-persist-save-immediately",
        "-battle-tick-interval",
        "1.0"
    ]
    static func screen(_ screen: String) -> [String] {
        ["-launch-screen", screen]
    }

    static func completedStages(_ stageIDs: [String]) -> [String] {
        ["-completed-stages", stageIDs.joined(separator: ",")]
    }

    static func mapScrollTarget(_ targetID: String) -> [String] {
        ["-map-scroll-target", targetID]
    }

    static func allForTab(_ tab: String, reset: Bool = true) -> [String] {
        var args = reset ? testLaunchArgs : []
        args.append(contentsOf: ["-selectedTab", tab])
        return args
    }

    static func allForScreen(_ screen: String, reset: Bool = true) -> [String] {
        var args = reset ? testLaunchArgs : []
        args.append(contentsOf: self.screen(screen))
        return args
    }

    static func allForBattle(reset: Bool = true, fastTicks: Bool = false) -> [String] {
        var args = allForScreen("battle", reset: reset)
        if fastTicks {
            args += ["-battle-tick-interval", "0.01"]
        }
        return args
    }

    static func replacingBattleTickInterval(_ interval: String, in args: [String]) -> [String] {
        var result = args
        if let index = result.firstIndex(of: "-battle-tick-interval"), index + 1 < result.count {
            result[index + 1] = interval
        } else {
            result += ["-battle-tick-interval", interval]
        }
        return result
    }
}

class TrinketUITestCase: XCTestCase {
    private(set) var app: XCUIApplication!

    var play: PlayScreen {
        PlayScreen(app: app)
    }

    var collection: CollectionScreen {
        CollectionScreen(app: app)
    }

    var combatantDetail: CombatantDetailScreen {
        CombatantDetailScreen(app: app)
    }

    var tabBar: TabBar {
        TabBar(app: app)
    }

    var homestead: HomesteadScreen {
        HomesteadScreen(app: app)
    }

    var search: SearchScreen {
        SearchScreen(app: app)
    }

    var options: OptionsScreen {
        OptionsScreen(app: app)
    }

    func launchApp(arguments: [String] = []) {
        app = XCUIApplication()
        var launchArgs = arguments
        launchArgs.append(contentsOf: ["-store-name", UUID().uuidString])
        app.launchArguments = launchArgs
        app.launch()
    }

    func button(_ identifier: String) -> XCUIElement {
        app.buttons[identifier]
    }

    func any(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func assertButtonExists(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        let element = button(identifier)
        guard element.waitForExistence(timeout: timeout) else {
            fail("Button '\(identifier)' not found", file: file, line: line)
            return
        }
    }

    func assertCombatantDetailSections(timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        combatantDetail.assertSections(timeout: timeout, file: file, line: line)
    }

    func assertExists(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        let element = app.descendants(matching: .any)[identifier]
        guard element.waitForExistence(timeout: timeout) else {
            fail("Element '\(identifier)' not found", file: file, line: line)
            return
        }
    }

    func assertItemCardExists(_ itemName: String, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        let card = app.buttons.matching(identifier: "\(itemName) item card").firstMatch
        guard card.waitForExistence(timeout: timeout) else {
            fail("Item card '\(itemName)' not found", file: file, line: line)
            return
        }
    }

    func assertItemCardExistsAfterScroll(_ itemName: String, maxAttempts: Int = 8, file: StaticString = #file, line: UInt = #line) {
        let card = app.buttons.matching(identifier: "\(itemName) item card").firstMatch
        scrollUntilVisible(card, swipingUp: true, maxAttempts: maxAttempts, file: file, line: line)
        guard card.exists else {
            fail("Item card '\(itemName)' not found", file: file, line: line)
            return
        }
    }

    func assertExists(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        guard element.waitForExistence(timeout: timeout) else {
            fail("Element not found", file: file, line: line)
            return
        }
    }

    func assertAccessibilityAudit(file: StaticString = #file, line: UInt = #line) {
        do {
            try app.performAccessibilityAudit()
        } catch {
            fail("Accessibility audit failed: \(error)", file: file, line: line)
        }
    }

    func assertExistsAfterScroll(_ identifier: String, maxAttempts: Int = 6, file: StaticString = #file, line: UInt = #line) {
        let element = app.descendants(matching: .any)[identifier]
        scrollUntilVisible(element, swipingUp: true, maxAttempts: maxAttempts, file: file, line: line)
        guard element.exists else {
            fail("Element '\(identifier)' not found after scroll", file: file, line: line)
            return
        }
    }

    func goBack() {
        let navBackButton = app.navigationBars.buttons.element(boundBy: 0)
        guard navBackButton.waitForExistence(timeout: 2) else { return }
        if navBackButton.isHittable {
            navBackButton.tap()
        } else {
            navBackButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    func scrollUntilVisible(_ element: XCUIElement, swipingUp: Bool, maxAttempts: Int = 6, file _: StaticString = #file, line _: UInt = #line) {
        for _ in 0 ..< maxAttempts where !element.exists {
            if swipingUp {
                dragScroll(fromY: 0.90, toY: 0.35)
            } else {
                dragScroll(fromY: 0.35, toY: 0.90)
            }
            _ = element.waitForExistence(timeout: 0.15)
        }
    }

    private func scrollContainer() -> XCUIElement {
        let playScreen = app.descendants(matching: .any)[AccessibilityID.Screen.play]
        if playScreen.exists {
            return playScreen
        }
        return app
    }

    private func dragScroll(fromY: CGFloat, toY: CGFloat) {
        let container = scrollContainer()
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func dragInDetailList(fromY: CGFloat, toY: CGFloat) {
        dragScroll(fromY: fromY, toY: toY)
    }

    func dismissSheet() {
        let closeButton = app.navigationBars.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2), closeButton.isHittable {
            closeButton.tap()
            _ = closeButton.waitForNonExistence(timeout: 3)
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            start.press(forDuration: 0.1, thenDragTo: end)
            _ = closeButton.waitForNonExistence(timeout: 3)
        }
    }

    func clearAndEnterText(_ element: XCUIElement, _ text: String) {
        replaceText(in: element, with: text)
    }

    func replaceText(in element: XCUIElement, with text: String) {
        element.tap()
        let clearButton = element.buttons["Clear text"]
        if clearButton.waitForExistence(timeout: 1) {
            clearButton.tap()
        } else if let stringValue = element.value as? String, !stringValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            element.typeText(deleteString)
        }
        if !text.isEmpty {
            element.typeText(text)
        }
    }

    func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {
        attachScreenshotOnFailure()
        XCTFail(message, file: file, line: line)
    }

    private func attachScreenshotOnFailure() {
        guard let app else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

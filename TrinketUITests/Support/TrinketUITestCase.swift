import XCTest

enum TestLaunchArg {
    static func tab(_ tab: String) -> String { "-selectedTab \(tab)" }
    static let resetState = "-reset-state"
    static func screen(_ screen: String) -> String { "-launch-screen \(screen)" }

    static func allForTab(_ tab: String, reset: Bool = true) -> [String] {
        var args = reset ? [resetState] : []
        args.append(tab)
        return args
    }

    static func allForScreen(_ screen: String, reset: Bool = true) -> [String] {
        var args = reset ? [resetState] : []
        args.append(self.screen(screen))
        return args
    }
}

class TrinketUITestCase: XCTestCase {
    private(set) var app: XCUIApplication!

    func launchApp(arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    func assertExists(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element '\(identifier)' not found", file: file, line: line)
    }

    func assertExists(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element not found", file: file, line: line)
    }

    func goBack() {
        let navBackButton = app.navigationBars.buttons.element(boundBy: 0)
        if navBackButton.waitForExistence(timeout: 5) {
            navBackButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }

    func scrollUntilVisible(_ element: XCUIElement, swipingUp: Bool, file: StaticString = #file, line: UInt = #line) {
        for _ in 0..<8 where !element.exists {
            if swipingUp {
                dragInDetailList(fromY: 0.84, toY: 0.62)
            } else {
                dragInDetailList(fromY: 0.62, toY: 0.84)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    private func dragInDetailList(fromY: CGFloat, toY: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func dismissSheet() {
        let closeButton = app.navigationBars.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2) && closeButton.isHittable {
            closeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            start.press(forDuration: 0.1, thenDragTo: end)
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        }
    }
}

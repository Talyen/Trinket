import XCTest

struct PlayScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Screen.play]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Play screen not found", file: file, line: line)
    }

    func assertChapterHeader(
        number: Int,
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: number)]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Chapter \(number) header not found", file: file, line: line)
    }

    func openStage(_ nodeID: String) {
        app.buttons[nodeID].tap()
    }

    func openStage(chapter: Int, stage: Int) {
        openStage(AccessibilityID.Play.stageNode(chapter: chapter, stage: stage))
    }
}

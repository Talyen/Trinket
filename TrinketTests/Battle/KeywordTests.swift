import XCTest
@testable import Trinket

final class KeywordTests: XCTestCase {
    func testKeywordDescriptionTextRendersWithoutCrash() {
        let sentence = Keyword.allCases.map(\.rawValue).joined(separator: " ")
            + " Frozen Stunned Burning Poisoned Bleeding"
        let view = KeywordDescriptionText(text: sentence)
        XCTAssertNotNil(view)
    }
}

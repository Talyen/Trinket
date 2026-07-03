import XCTest
@testable import Trinket

final class EffectHandlersTests: XCTestCase {
    func testRegistryContainsEveryEffectKind() {
        XCTAssertEqual(Set(EffectHandlers.all.keys), Set(EffectKind.allCases))
        for kind in EffectKind.allCases {
            XCTAssertNotNil(EffectHandlers.all[kind], "Missing handler for \(kind)")
            XCTAssertEqual(EffectHandlers.all[kind]?.kind, kind)
            XCTAssertEqual(EffectHandlers.handler(for: kind).kind, kind)
        }
    }
}

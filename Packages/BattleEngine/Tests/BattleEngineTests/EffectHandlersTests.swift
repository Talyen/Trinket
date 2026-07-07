import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class EffectHandlersTests: XCTestCase {
    func testRegistryContainsEveryEffectKind() throws {
        XCTAssertEqual(Set(EffectHandlers.all.keys), Set(EffectKind.allCases))
        for kind in EffectKind.allCases {
            let handler = try XCTUnwrap(EffectHandlers.all[kind], "Missing handler for \(kind)")
            XCTAssertEqual(handler.kind, kind)
            XCTAssertEqual(EffectHandlers.handler(for: kind)?.kind, kind)
        }
    }
}

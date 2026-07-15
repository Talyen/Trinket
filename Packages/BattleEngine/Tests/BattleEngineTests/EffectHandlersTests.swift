import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectHandlersTests {
    @Test func registryCoversEveryEffectKind() throws {
        try #expect(Set(EffectHandlers.all.keys) == Set(EffectKind.allCases))
        for kind in EffectKind.allCases {
            let handler = try #require(EffectHandlers.all[kind], "Missing handler for \(kind)")
            try #expect(handler.kind == kind)
            try #expect(EffectHandlers.handler(for: kind)?.kind == kind)
        }
    }
}

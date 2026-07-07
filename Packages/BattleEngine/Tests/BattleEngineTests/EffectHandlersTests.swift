import BattleEngine
import Testing
import TrinketContent
import TrinketCore

@Suite struct EffectHandlersTests {
    @Test func registryKeysMatchAllEffectKinds() {
        #expect(Set(EffectHandlers.all.keys) == Set(EffectKind.allCases))
    }

    @Test(arguments: EffectKind.allCases)
    func registryContainsHandler(for kind: EffectKind) {
        let handler = EffectHandlers.all[kind]
        #require(handler != nil, "Missing handler for \(kind)")
        #expect(handler?.kind == kind)
        #expect(EffectHandlers.handler(for: kind)?.kind == kind)
    }
}

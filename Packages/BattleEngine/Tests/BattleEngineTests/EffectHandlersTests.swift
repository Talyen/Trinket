import BattleEngine
import Testing
import TrinketContent
import TrinketCore

@Suite struct EffectHandlersTests {
    @Test func registryKeysMatchAllEffectKinds() throws {
        try #expect(Set(EffectHandlers.all.keys) == Set(EffectKind.allCases))
    }

    @Test(arguments: EffectKind.allCases)
    func registryContainsHandler(for kind: EffectKind) throws {
        let handler = EffectHandlers.all[kind]
        try #require(handler != nil, "Missing handler for \(kind)")
        try #expect(handler?.kind == kind)
        try #expect(EffectHandlers.handler(for: kind)?.kind == kind)
    }
}

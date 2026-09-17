import Testing
import TrinketCore
@testable import BattleEngine

/// Registry parity: every `EffectKind` must resolve to a handler so a new kind
/// cannot silently fall through to the missing-handler path in turn processing.
struct EffectHandlersRegistryTests {
    @Test func `registry covers every effect kind`() {
        for kind in EffectKind.allCases {
            #expect(EffectHandlers.handler(for: kind) != nil, "Missing handler for \(kind)")
        }
    }

    @Test func `registry has no unmapped handlers`() {
        #expect(EffectHandlers.all.count == EffectKind.allCases.count)
    }
}

import Foundation
import Testing
@testable import TrinketContent

struct TriggerCodingTests {
    @Test func `encoding omits defaulted fields`() throws {
        let empty = try JSONEncoder().encode(CombatTraitTriggers())
        #expect(String(data: empty, encoding: .utf8) == "{}")
    }

    @Test func `legacy flat trigger payloads preserve mixed families across reload`() throws {
        let data = Data(#"{"blockPerTurn":2,"goldDoubledWhileFullHealth":true,"burnProcsBleedChancePercent":0.2,"futureField":9}"#.utf8)
        let expected = CombatTraitTriggers(
            block: BlockTriggers(blockPerTurn: 2),
            dot: DotTriggers(burnProcsBleedChancePercent: 0.2),
            gold: GoldTriggers(goldDoubledWhileFullHealth: true),
        )
        let decoded = try JSONDecoder().decode(CombatTraitTriggers.self, from: data)
        #expect(decoded == expected)
        let encoded = try JSONEncoder().encode(decoded)
        let persisted = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(persisted.keys) == ["blockPerTurn", "goldDoubledWhileFullHealth", "burnProcsBleedChancePercent"])
        #expect(try JSONDecoder().decode(CombatTraitTriggers.self, from: encoded) == expected)
    }
}

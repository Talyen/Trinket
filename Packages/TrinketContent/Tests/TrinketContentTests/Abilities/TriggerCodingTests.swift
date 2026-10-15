import Foundation
import Testing
@testable import TrinketContent

struct TriggerCodingTests {
    @Test func `legacy flat trigger payloads preserve mixed families across reload`() throws {
        let data = Data(#"{"blockPerTurn":2,"goldDoubledWhileFullHealth":true,"burnProcsBleedChancePercent":0.2,"futureField":9}"#.utf8)
        let expected = CombatTraitTriggers(
            block: BlockTriggers { $0.blockPerTurn = 2 },
            dot: DotTriggers { $0.burnProcsBleedChancePercent = 0.2 },
            gold: GoldTriggers { $0.goldDoubledWhileFullHealth = true },
        )
        let decoded = try JSONDecoder().decode(CombatTraitTriggers.self, from: data)
        #expect(decoded == expected)
        let encoded = try JSONEncoder().encode(decoded)
        let persisted = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(persisted.keys) == ["blockPerTurn", "goldDoubledWhileFullHealth", "burnProcsBleedChancePercent"])
        #expect(try JSONDecoder().decode(CombatTraitTriggers.self, from: encoded) == expected)
    }

    @Test func `saved integer trigger rewards saturate when equipment combines`() throws {
        let data = Data("{\"blockPerTurn\":\(Int.max),\"goldPerTurn\":\(Int.max)}".utf8)
        var decoded = try JSONDecoder().decode(CombatTraitTriggers.self, from: data)
        let contribution = CombatTraitTriggers(
            block: BlockTriggers { $0.blockPerTurn = 1 }, gold: GoldTriggers { $0.goldPerTurn = 1 },
        )
        decoded.merge(contribution)
        #expect(decoded.blockPerTurn == Int.max)
        #expect(decoded.goldPerTurn == Int.max)
        #expect(try JSONDecoder().decode(CombatTraitTriggers.self, from: JSONEncoder().encode(decoded)) == decoded)
    }
}

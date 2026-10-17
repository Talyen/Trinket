import Foundation
import Testing
@testable import TrinketContent

struct TriggerCodingTests {
    @Test func `legacy flat trigger payloads preserve mixed families across reload`() throws {
        let data = Data(#"{"blockPerTurn":2,"goldDoubledWhileFullHealth":true,"burnProcsBleedChancePercent":0.2,"futureField":9}"#.utf8)
        let expected = CombatTraitTriggers {
            $0.blockPerTurn = 2
            $0.burnProcsBleedChancePercent = 0.2
            $0.goldDoubledWhileFullHealth = true
        }
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
        let contribution = CombatTraitTriggers {
            $0.blockPerTurn = 1
            $0.goldPerTurn = 1
        }
        decoded.merge(contribution)
        #expect(decoded.blockPerTurn == Int.max)
        #expect(decoded.goldPerTurn == Int.max)
        #expect(try JSONDecoder().decode(CombatTraitTriggers.self, from: JSONEncoder().encode(decoded)) == decoded)
    }

    @Test func `trigger copies isolate scalar collection and merged equipment changes`() throws {
        let original = CombatTraitTriggers {
            $0.blockPerTurn = 2
            $0.bonusManaOnTurns = [1, 3]
            $0.stunnedDamageMultiplier = 2
        }
        var changed = original
        changed.blockPerTurn = 4
        changed.bonusManaOnTurns.append(5)
        changed.merge(CombatTraitTriggers {
            $0.blockPerTurn = 3
            $0.bonusManaOnTurns = [3, 7]
            $0.stunnedDamageMultiplier = 1.5
        })
        #expect(original.blockPerTurn == 2 && original.bonusManaOnTurns == [1, 3])
        #expect(original.stunnedDamageMultiplier == 2)
        #expect(changed.blockPerTurn == 7 && changed.bonusManaOnTurns == [1, 3, 5, 7])
        #expect(changed.stunnedDamageMultiplier == 3)
        let reloaded = try JSONDecoder().decode(CombatTraitTriggers.self, from: JSONEncoder().encode(changed))
        #expect(reloaded == changed && reloaded != original)
        var merged = original
        merged.merge(changed)
        #expect(original.blockPerTurn == 2 && merged.blockPerTurn == 9)
    }
}

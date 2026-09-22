import Foundation
import Testing
@testable import TrinketContent

struct TriggerCodingTests {
    @Test func `decoding tolerates unknown future fields`() throws {
        let data = Data(#"{"blockPerTurn": 2, "futureField": 9}"#.utf8)
        let decoded = try JSONDecoder().decode(CombatTraitTriggers.self, from: data)
        #expect(decoded.blockPerTurn == 2)
    }

    @Test func `encoding omits defaulted fields and round-trips`() throws {
        let empty = try JSONEncoder().encode(CombatTraitTriggers())
        #expect(String(data: empty, encoding: .utf8) == "{}")
        var populated = CombatTraitTriggers()
        populated.blockPerTurn = 2
        let roundTrip = try JSONDecoder().decode(
            CombatTraitTriggers.self,
            from: JSONEncoder().encode(populated),
        )
        #expect(roundTrip.blockPerTurn == 2)
    }
}

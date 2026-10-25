import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct EarnedGearProgressionTests {
    @Test func `victory loot persists but losses previews and level 35 never generate equipment`() throws {
        let step = BalanceTestFixtures.step(enemyLevel: 34)
        let controller = InterleavingPlayerController(
            campaignTracker: .init(steps: [step]), spireTracker: .init(steps: []), labyrinthTracker: .init(steps: []),
            initialState: PlayerProgressionState(heroLevel: 34, companionLevel: 34), worldSeed: 43,
        )
        let party = try #require(controller.earnedParty)
        #expect(party.inventory.isEmpty)
        let before = controller.makeMatchup(for: step, seed: 10).context
        controller.recordOutcome(step: step, won: false)
        #expect(party.inventory.isEmpty)
        controller.recordOutcome(step: step, won: true)
        #expect(party.inventory.count == 1)
        let earned = party.inventory
        let worn = party.equipment
        let talents = party.talents
        party.invest(state: PlayerProgressionState(heroLevel: 35, companionLevel: 35))
        #expect(party.inventory == earned)
        #expect(party.equipment == worn)
        #expect(talents.allSatisfy { $0.value.isSubset(of: party.talents[$0.key] ?? []) })
        let first = controller.makeMatchup(for: step, seed: 11).context
        let next = controller.makeMatchup(for: step, seed: 12).context
        #expect(first.heroAffixIDs == next.heroAffixIDs)
        #expect(first.companionAffixIDs == next.companionAffixIDs)
        #expect(first.heroLoadout == before.heroLoadout)
        #expect(first.companionLoadout == before.companionLoadout)
        controller.recordOutcome(step: step, won: true)
        #expect(party.inventory == earned)
    }

    @Test func `renewable recovery wins earn distinct items and retain their offer on defeat`() throws {
        let controller = InterleavingPlayerController(worldSeed: 43)
        let first = controller.selectRecoveryStep()
        controller.recordOutcome(step: first, won: false)
        #expect(controller.selectRecoveryStep() == first)
        controller.recordOutcome(step: first, won: true)
        let second = controller.selectRecoveryStep()
        #expect(second.id != first.id)
        controller.recordOutcome(step: second, won: true)
        let party = try #require(controller.earnedParty)
        #expect(party.inventory.count == 2)
        #expect(Set(party.inventory.map(\.id)).count == 2)
        let ids = party.equipment.values.flatMap(\.itemIDsBySlot.values)
        #expect(Set(ids).count == ids.count)
    }

    @Test func `historical configurations retain their tier interpretation`() throws {
        var config = BalanceSweepConfig(mode: .modeProgression)
        #expect(config.resolvedProgressionEquipmentModel == .earned)
        #expect(config.progressionEquipmentPolicyID == SimulationEquipmentPolicy.id)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        json.removeValue(forKey: "progressionEquipmentModel")
        json.removeValue(forKey: "progressionEquipmentPolicyID")
        config = try JSONDecoder().decode(BalanceSweepConfig.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(config.resolvedProgressionEquipmentModel == .tier)
    }
}

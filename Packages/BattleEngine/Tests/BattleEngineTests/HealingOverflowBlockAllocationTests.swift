import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealingOverflowBlockAllocationTests {
    @Test(arguments: ["full", "fractional", "capped", "marrowmend"], [0, 2])
    func `overflow Block conversion spends only accepted capacity`(conversion: String, capacity: Int) {
        var battle = makeBattle(conversion: conversion)
        DefensePoolEngine.set(Int.max - capacity, on: battle.companion, in: &battle)
        var request = HealRequest(
            amount: 10, target: battle.companion, sourceActorID: battle.companion.id,
            origin: .leech, logAs: .silent,
        )
        request.amountBasis = .resolved

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }

        #expect(result.allocation.block == capacity)
        #expect(result.allocation.remaining == 10 - capacity)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == Int.max)
    }

    @Test(arguments: ["full", "fractional", "capped", "marrowmend"])
    func `rejected overflow Block remains available to Flawless Bounty`(conversion: String) {
        var battle = makeBattle(conversion: conversion)
        battle.roster.companion.talents.turn.blockGainPrevented = true

        let outcome = battle.recordingResult { context in await HealingEngine.leechFromDamage(
            20, sourceActorID: context.companion.id, target: context.enemy,
            abilityHasLeech: true, in: &context,
        ) }

        #expect(battle.gold == 10)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == 0)
        #expect(outcome.events.contains { $0.abilityName == "Flawless Bounty" && $0.amount == 10 })
    }

    @Test func `capped base conversion keeps bonus Block separate from overflow consumption`() {
        var battle = makeBattle(conversion: "capped")
        var request = HealRequest(amount: 10, target: battle.companion, sourceActorID: battle.companion.id)
        request.amountBasis = .resolved

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }

        #expect(result.allocation.block == 4)
        #expect(result.allocation.remaining == 6)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == 11)
    }

    private func makeBattle(conversion: String) -> BattleState {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.excessLeechHealthToGoldChancePercent = 1
        switch conversion {
        case "full": profile.triggers.overhealConvertsToBlock = true
        case "fractional": profile.triggers.overhealToBlockPercent = 0.5
        case "capped":
            profile.triggers.overhealShieldCap = 4
            profile.blockGainedBonus = 7
        default: profile.triggers.marrowmend = true
        }
        return BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            companionModifiers: profile, appliesFightPacing: false,
        )
    }
}

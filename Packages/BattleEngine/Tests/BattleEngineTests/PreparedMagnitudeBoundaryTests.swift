import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct PreparedMagnitudeBoundaryTests {
    @Test(arguments: [false, true])
    func `Mana empowerment saturates bonuses and doubled damage`(maximumBonus: Bool) {
        let profile = CombatModifierProfile.withTriggers {
            $0.manaEmpoweredAttackDoubleChancePercent = 1
            $0.empowermentDamageBonus = maximumBonus ? Int.max : 0
            $0.empowerFreezeDamageBonus = maximumBonus ? Int.max : 0
            $0.flashFreeze = maximumBonus
        }
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 3, heroMana: 3, heroModifiers: profile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        var ability = Ability(
            id: "empower-boundary", name: "Empower", tier: .skill,
            damageComponents: [DamageComponent(Int.max / 2 + 1, keyword: .freeze, bonusAmount: Int.max / 2 + 1)],
            targetedEffects: [TargetedEffect(.recurringDamage(.freeze, Int.max / 2 + 1, 2))],
        )

        _ = CombatExecutor.run {
            await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(for: &ability, actor: battle.hero, context: &battle)
        }

        #expect(ability.damageComponents.first?.amount == Int.max)
        #expect(ability.damageComponents.first?.bonusAmount == Int.max)
        #expect(ability.targetedEffects.first?.effect == .recurringDamage(.freeze, Int.max, 2))
        #expect(battle.mana(of: battle.hero) == 0)
    }

    @Test func `combined party card preparation saturates and consumes each source once`() {
        var battle = BattleTestFixtures.makePipelineContext()
        battle.resolution.preparePartyCardDamage(Int.max, sourceID: battle.hero.id)
        battle.resolution.preparePartyCardDamage(1, sourceID: battle.companion.id)
        let living = [battle.hero.id, battle.companion.id]

        #expect(battle.resolution.reservePartyCardDamage(livingSourceIDs: living) == Int.max)
        #expect(battle.resolution.reservePartyCardDamage(livingSourceIDs: living) == 0)
    }

    @Test func `healing echo details saturate without consuming queued restoration`() {
        var battle = BattleTestFixtures.makePipelineContext()
        let sourceID = battle.hero.id
        let echoes = [Int.max / 2 + 1, Int.max / 2 + 1].map { HealingEcho(amount: $0, sourceActorID: sourceID) }
        battle.roster.hero.talents.pending.healingEchoes = echoes

        let summaries = battle.talentEffectSummaries(of: battle.hero)

        #expect(summaries.contains { $0.keyword == .health && $0.text == "Living Archive: Restore \(Int.max) Health next round" })
        #expect(battle.roster.hero.talents.pending.healingEchoes == echoes)
    }
}

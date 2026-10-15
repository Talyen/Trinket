import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BlockCostRollbackRegressionTests {
    @Test(arguments: [(0, 0, 0), (1, 0, 1), (3, 2, 5), (1, Int.max, Int.max)])
    func `intercepted attacks refund only paid Block while preserving nested gains`(
        startingBlock: Int,
        nestedBlock: Int,
        expectedBlock: Int,
    ) {
        let attack = Ability(id: "block-cost-attack", name: "Block Cost Attack", tier: .basic, directDamage: 1, blockCost: 3)
        var profile = CombatModifierProfile.zero
        profile.triggers.onDodgeDrawAndPlayCardChainOnCrit = nestedBlock > 0
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack],
            heroModifiers: profile,
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t2_2"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(startingBlock, on: battle.enemy, in: &battle)
        if nestedBlock > 0 {
            // A supported automatic support card grants Block during Warning Bark's Dodge reactions.
            battle.heroDeck = CombatDeck(abilities: [Ability(
                id: "interception-block", name: "Interception Block", tier: .basic,
                targetedEffects: [TargetedEffect(.shield(.block, nestedBlock), target: .enemy)],
            )])
        }

        let events = battle.recordingEvents { battle in
            _ = await BattleTurnEngine.performEnemyAction(ability: attack, abilityTarget: battle.hero, context: &battle)
        }

        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == expectedBlock)
        #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
        #expect(events.contains { $0.abilityName == "Warning Bark" && $0.effectKind == .dodgeApplied })
        #expect(!events.contains { $0.effectKind == .blockSpent })
        if nestedBlock > 0 {
            #expect(events.contains { $0.abilityID == "interception-block" })
        }
    }
}

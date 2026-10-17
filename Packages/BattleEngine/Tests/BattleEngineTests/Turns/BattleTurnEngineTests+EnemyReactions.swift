import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension BattleTurnEngineTests {
    @Test(arguments: [false, true])
    func `random enemy support outcomes preserve attack defenses and resolve once`(attacks: Bool) throws {
        let ability = Ability(
            id: "enemy-choice", name: "Enemy Choice", tier: .basic,
            outcomeBranches: [
                AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .physical)]),
                AbilityOutcomeBranch(effects: [.shield(.block, 3)]),
            ],
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [ability], companionModifiers: .withTriggers { $0.negateFirstEnemyAttack = true },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.rng = try BattleTestFixtures.rngSelectingOutcome(ability, in: battle, actor: .enemy) {
            $0.dealsCombatDamage == attacks
        }
        var expected = battle
        _ = BattleAbilityRules.resolveOutcome(ability, actor: battle.enemy, in: &expected)
        let events = battle.recordingEvents { context in await BattleCardCombatEngine.resolveEnemyTurn(context: &context) }
        #expect(battle.roster.companion.talents.battle.negatedFirstEnemyAttack == attacks)
        #expect(events.contains { $0.effectKind == .shieldApplied && $0.targetID == battle.enemy.id } == !attacks)
        #expect(battle.rng == expected.rng)
    }

    @Test func `attack avoidance preserves enemy support actions and warning bark`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [.block],
            heroModifiers: CombatModifierProfile.withTriggers { $0.poisonedEnemyMissChancePercent = 1 },
            companionModifiers: CombatModifierProfile.withTriggers {
                $0.negateFirstEnemyAttack = true
                $0.swapAndDodgeForHeroChance = 1
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.insertEffect(.poison(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let events = battle.recordingEvents { context in await BattleCardCombatEngine.resolveEnemyTurn(context: &context) }

        #expect(events.contains { $0.effectKind == .shieldApplied && $0.targetID == battle.enemy.id })
        #expect(!battle.roster.companion.talents.battle.negatedFirstEnemyAttack)
        #expect(!battle.roster.hero.activeEffects.contains { $0.effect == .evadeNextHit })
    }

    @Test(arguments: [Keyword?.none, .stun, .freeze])
    func `pinning strike does not damage an enemy that cannot attack`(control: Keyword?) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [control == nil ? .block : .slash],
            heroModifiers: CombatantTalentCatalog.profile(for: ["ranger_bleed_t3_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.insertEffect(.bleed(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 3)
        if let control {
            battle.insertEffect(.controlMeter(control, 20, 20), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }

        let events = battle.recordingEvents { context in await BattleCardCombatEngine.resolveEnemyTurn(context: &context) }

        #expect(battle.roster.enemy.currentHealth == 100)
        #expect(events.contains { $0.effectKind == (control == nil ? .shieldApplied : .controlActionSkipped) })
    }
}

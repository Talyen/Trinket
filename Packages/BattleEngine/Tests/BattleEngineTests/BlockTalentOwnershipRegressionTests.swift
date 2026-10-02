import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BlockTalentOwnershipRegressionTests {
    @Test(arguments: [false, true])
    func `Glacial Reprieve returns only damage absorbed by its owners Block`(heroBlocks: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_freeze_t4_1"]),
        )
        battle.appliesFightPacing = false
        let defender = heroBlocks ? battle.hero : battle.companion
        DefensePoolEngine.set(5, on: defender, in: &battle)

        let damage = battle.resolveDamage(DamageRequest(
            amount: 5, target: defender, keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(damage.healthLost == 0)
        #expect(battle.health(of: battle.enemy) == (heroBlocks ? 95 : 100))
        #expect(battle.activeEffects(of: battle.enemy).contains {
            if case let .controlMeter(.freeze, amount, _) = $0.effect {
                return amount == 5
            }
            return false
        } == heroBlocks)
    }

    @Test func `Glacial Reprieve returns borrowed Hero Block without returning Companion Block`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_freeze_t4_1", "knight_block_t2_1"]),
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(2, on: battle.hero, in: &battle)
        DefensePoolEngine.set(3, on: battle.companion, in: &battle)

        let damage = battle.resolveDamage(DamageRequest(
            amount: 5, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(damage.healthLost == 0)
        #expect(battle.health(of: battle.enemy) == 98)
        #expect(battle.activeEffects(of: battle.enemy).contains {
            if case let .controlMeter(.freeze, amount, _) = $0.effect {
                return amount == 2
            }
            return false
        })
    }

    @Test(arguments: [
        (DamageOperation.attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1), 2),
        (.periodic, 4), (.reaction(), 4),
    ])
    func `Ironhide reduces only attack damage after Block breaks`(operation: DamageOperation, expectedHealthLoss: Int) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: CombatantTalentCatalog.profile(for: ["bear_block_t3_1"]),
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(2, on: battle.companion, in: &battle)

        let damage = battle.resolveDamage(DamageRequest(
            amount: 6, target: battle.companion, keyword: .bleed,
            sourceActorID: battle.enemy.id, options: operation,
        ))

        #expect(damage.healthLost == expectedHealthLoss)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 0)
    }

    @Test func `Ironhide does not reduce bypass damage while Block remains`() {
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.physicalBlockIgnorePercent = 0.5
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: CombatantTalentCatalog.profile(for: ["bear_block_t3_1"]),
            enemyModifiers: enemyProfile,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(8, on: battle.companion, in: &battle)

        let damage = battle.resolveDamage(DamageRequest(
            amount: 6, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(damage.healthLost == 2)
        #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 4)
    }
}

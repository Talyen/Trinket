import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

/// Cross-profile talent wiring and P1 combat fixes from the talent-system review.
struct CompanionTalentReviewTests {
    @Test func preyOnTheWeakUsesHeroTalentOnCompanionHits() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(companionDamageVsPoisonedBonus: 2)
            )),
            dealOpeningHand: false
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.companion.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func radiantHealthBuffsHeroHitsWhileCompanionIsFullHealth() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(partyDamageBonusWhileCompanionFullHealth: 2)
            )),
            dealOpeningHand: false
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func sacrificialGuardRedirectsThroughCompanionBlock() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 8),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 30),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionFatalDamageRedirectBlock: 10)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            20,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 12,
                target: battle.roster.hero.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 0)
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 8)
        #expect(battle.roster.health(for: battle.roster.companion.combatant) == 30)
        let companionBlock = DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.companion.combatant)
        )
        #expect(companionBlock == 18)
    }

    @Test func manaSnatchTransfersManaToDodger() {
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: 20,
            maxMana: 5,
            abilities: []
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            maxMana: 5,
            actionIntervalTurns: 100,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: companion,
            enemy: enemy,
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgeStealMana: 1)
            )),
            dealOpeningHand: false
        )
        _ = battle.spendMana(5, for: companion)
        _ = battle.spendMana(5, for: enemy)
        _ = battle.restoreMana(3, to: enemy)
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle
        )
        #expect(battle.mana(of: enemy) == 2)
        #expect(battle.mana(of: companion) == 1)
    }

    @Test func vitalInfusionOverhealCapsPerEventOnHealedAlly() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    overhealConvertsToMaxHealth: true,
                    overhealConvertsToMaxHealthCap: 5,
                    overhealConvertsToMaxHealthPerEvent: 1
                )
            )),
            dealOpeningHand: false
        )
        let hero = battle.roster.hero.combatant
        _ = battle.resolveHeal(
            HealRequest(amount: 8, target: hero, sourceActorID: battle.roster.companion.id)
        )
        #expect(battle.roster.maxHealth(for: hero) == 21)
        #expect(battle.roster.health(for: hero) == 21)
    }
}

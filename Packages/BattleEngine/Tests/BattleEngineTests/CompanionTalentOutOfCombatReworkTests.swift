import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

/// Deterministic coverage for the seven companion talents reworked from
/// out-of-combat (shop/camp/chest/victory) effects to in-battle effects so
/// out-of-combat party swapping cannot stack them (§7 / §10.15).
struct CompanionTalentOutOfCombatReworkTests {
    @Test func hagglerBoostsAllPartyGoldGain() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(partyGoldGainedPercent: 0.15)
            )),
            dealOpeningHand: false
        )
        battle.addGold(20, sourceActorID: battle.roster.hero.id)
        #expect(battle.gold == 23)
    }

    @Test func scavengersCacheSpendsGoldToAbsorbDamage() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldAbsorbsDamage: true)
            )),
            dealOpeningHand: false
        )
        battle.gold = 5
        let companion = battle.roster.companion.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 4,
                target: companion,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 0)
        #expect(battle.gold == 1)
    }

    @Test func scavengersCacheCapsAbsorptionAtFivePerHit() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldAbsorbsDamage: true)
            )),
            dealOpeningHand: false
        )
        battle.gold = 20
        let companion = battle.roster.companion.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 12,
                target: companion,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 7)
        #expect(battle.gold == 15)
    }

    @Test func campfireComfortRestoresEachAllyAtEndOfRound() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(partyRegenPerRound: 1)
            )),
            dealOpeningHand: false
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.currentHealth = 10 }
        _ = CombatTriggerEngine.atPlayerEndTurn(in: &battle)
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 11)
        #expect(battle.roster.health(for: battle.roster.companion.combatant) == 11)
    }

    @Test func flawlessBountyDoublesGoldWhileCompanionAtFullHealth() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldDoubledWhileFullHealth: true)
            )),
            dealOpeningHand: false
        )
        battle.addGold(10, sourceActorID: battle.roster.hero.id)
        #expect(battle.gold == 20)

        var woundedBattle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldDoubledWhileFullHealth: true)
            )),
            dealOpeningHand: false
        )
        woundedBattle.roster.mutateRuntime(for: woundedBattle.roster.companion.combatant) { $0.currentHealth = 10 }
        woundedBattle.addGold(10, sourceActorID: woundedBattle.roster.hero.id)
        #expect(woundedBattle.gold == 10)
    }

    @Test func treasureHoardGrantsPartyCritChanceWhileCarryingEnoughGold() {
        func makeBattle(gold: Int) -> BattleState {
            // Deterministic seed plus a large bonus: with 50+ Gold the capped roll
            // succeeds; without it the base contested chance stays below the threshold.
            var battle = BattleStateTestFactory.makeBattle(
                hero: BattleTestFixtures.passiveHero(),
                companion: BattleTestFixtures.passiveCompanion(),
                enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
                companionModifiers: .init(triggers: CombatTraitTriggers(
                    damage: DamageTriggers(
                        partyCritChanceWhileGoldAbove: 50,
                        partyCritChanceWhileGoldAboveBonus: 1.0
                    )
                )),
                dealOpeningHand: false
            )
            battle.gold = gold
            return battle
        }
        var richBattle = makeBattle(gold: 50)
        var poorBattle = makeBattle(gold: 49)
        let richOutcome = richBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: richBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: richBattle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        let poorOutcome = poorBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: poorBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: poorBattle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(richOutcome.isCritical)
        #expect(!poorOutcome.isCritical)
    }

    @Test func thiefStealsEnemyBlockOnCriticalHit() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(critStealEnemyBlock: true)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            5,
            to: battle.roster.enemy.combatant,
            source: battle.roster.enemy.combatant,
            abilityName: "Test"
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 2,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: companion.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    guaranteedCritical: true
                )
            )
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant)) == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: companion)) == 5)
    }

    @Test func afterglowRestoresEachAllyWhenPhoenixSurvivesDeathsDoor() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                revival: RevivalTriggers(surviveDeathsDoorPartyHealPercent: 0.15)
            )),
            dealOpeningHand: false
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.currentHealth = 10 }
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: companion,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        // 10 → 1 on Death's Door, then Afterglow restores 15% of 20 = 3 to each ally.
        #expect(battle.roster.health(for: companion) == 4)
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 13)
    }
}

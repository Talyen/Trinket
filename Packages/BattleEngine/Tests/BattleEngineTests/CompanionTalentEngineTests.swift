import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

/// Deterministic coverage for Companion talent engine hooks (Combatant Talent System).
struct CompanionTalentEngineTests {
    @Test func intercedeHeroBlockAbsorbsCompanionDamage() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(blockAbsorbsCompanionDamage: true)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            6,
            to: battle.roster.hero.combatant,
            source: battle.roster.hero.combatant,
            abilityName: "Test"
        )
        let companion = battle.roster.companion.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: companion, keyword: .physical, sourceActorID: "enemy")
        )
        #expect(outcome.healthLost == 0)
        let heroBlock = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant))
        #expect(heroBlock == 2)
    }

    @Test func bulwarkFortressReducesHeroDamageWhileCompanionBlocked() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionBlockProtectsHeroPercent: 0.5)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            5,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        let hero = battle.roster.hero.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 10, target: hero, keyword: .physical, sourceActorID: "enemy")
        )
        #expect(outcome.healthLost == 5)
    }

    @Test func ironhideCapsDamagePerHit() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(maxDamagePerHitCap: 10)
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 16, target: companion, keyword: .physical, sourceActorID: "enemy")
        )
        #expect(outcome.healthLost == 10)
    }

    @Test func counterPounceCountersWhenDodging() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgeCounterDamage: 3)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle
        )
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 97)
    }

    @Test func shieldBondSharesBlockToHero() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionBlockSharesToHeroPercent: 1)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            4,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        let heroBlock = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant))
        #expect(heroBlock == 4)
    }

    @Test func seismicRoarStunsEnemyWhenCompanionDropsBelowHalf() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onceBelowHealthPercentStunAllEnemies: true,
                    onceBelowHealthPercentThreshold: 0.5
                )
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(amount: 11, target: companion, keyword: .physical, sourceActorID: "enemy")
        )
        #expect(battle.roster.hasControlStatus(for: battle.roster.enemy.combatant, keyword: .stun))
    }

    @Test func paralysisStunsEnemyWithEnoughPoison() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dot: DotTriggers(poisonThresholdStunAmount: 6)
            )),
            dealOpeningHand: false
        )
        let enemy = battle.roster.enemy.combatant
        let active = ActiveEffect(
            id: 1,
            effect: .poison(8),
            remainingTurns: 0,
            sourceActorID: battle.roster.companion.id
        )
        _ = DecayingDoTHandler(keyword: .poison).advanceTurn(active, on: enemy, in: &battle)
        #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
    }

    @Test func venomousSkinPoisonsAttacker() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(onHitAttackerPoison: 1)
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(amount: 3, target: companion, keyword: .physical, sourceActorID: "enemy")
        )
        let poisoned = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .contains { $0.effect.keyword == .poison }
        #expect(poisoned)
    }

    @Test func prismaticSparkCanDoubleManaGain() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 6,
            companionMana: 0,
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(manaGainDoubleChancePercent: 1)
            )),
            dealOpeningHand: false
        )
        let restored = battle.restoreMana(1, to: battle.roster.companion.combatant)
        #expect(restored == 2)
    }

    @Test func blindingCarapaceDebuffsAttackerAfterBlocking() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 50),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onBlockReduceAttackerAccuracyPercent: 25,
                    onBlockReduceAttackerAccuracyTurns: 2
                )
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            10,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        _ = battle.resolveDamage(
            DamageRequest(amount: 10, target: battle.roster.companion.combatant, keyword: .physical, sourceActorID: "enemy")
        )
        let hasDebuff = battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains { active in
            if case .damageReductionPercent = active.effect {
                return true
            }
            return false
        }
        #expect(hasDebuff)
    }

    @Test func weakenSoulReducesEnemyStrengthOnLeech() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onLeechReduceEnemyStrength: 1,
                    onLeechReduceEnemyStrengthTurns: 2
                )
            )),
            dealOpeningHand: false
        )
        let enemy = battle.roster.enemy.combatant
        _ = CombatTriggerEngine.afterLeech(
            by: battle.roster.companion.combatant,
            target: enemy,
            in: &battle
        )
        let effectiveStrength = battle.roster.runtime(for: enemy)?.primaryStats.strength ?? 0
        #expect(effectiveStrength < enemy.primaryStats.strength)
    }
}

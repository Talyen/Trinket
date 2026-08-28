import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatTriggerTalentDefenseTests {
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
            companionModifiers: .init(
                blockGainedBonus: 2,
                triggers: CombatTraitTriggers(
                    block: BlockTriggers(companionBlockSharesToHeroPercent: 1)
                )
            ),
            dealOpeningHand: false
        )
        let outcome = EffectHandlersTestSupport.dispatch(
            .shield(.block, 4),
            ability: .block,
            source: battle.roster.companion.combatant,
            target: battle.roster.companion.combatant,
            battle: &battle
        )
        let companionBlock = DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.companion.combatant)
        )
        let heroBlock = DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant)
        )
        #expect(companionBlock == 6)
        #expect(heroBlock == 6)
        #expect(outcome.events.contains {
            $0.effectKind == .shieldApplied && $0.targetID == battle.roster.hero.id && $0.amount == 6
        })
    }

    @Test func shieldBondSharedBlockGrantsHeroThorns() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(blockGainThornsPercent: 0.5)
            )),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionBlockSharesToHeroPercent: 1)
            )),
            dealOpeningHand: false
        )
        _ = EffectHandlersTestSupport.dispatch(
            .shield(.block, 4),
            ability: .block,
            source: battle.roster.companion.combatant,
            target: battle.roster.companion.combatant,
            battle: &battle
        )
        let heroBlock = DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant)
        )
        #expect(heroBlock == 4)
        #expect(battle.roster.activeEffects(for: battle.roster.hero.combatant).contains {
            guard case let .thorns(amount) = $0.effect else { return false }
            return amount == 2
        })
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

    @Test func armorPierceIgnoresMitigationForLeechOnly() {
        let toughEnemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 40,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 80)
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: toughEnemy,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(leechIgnoresMitigation: true)
            )),
            dealOpeningHand: false
        )
        let physical = battle.resolveDamage(
            DamageRequest(
                amount: 10,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        let leech = battle.resolveDamage(
            DamageRequest(
                amount: 10,
                target: battle.roster.enemy.combatant,
                keyword: .leech,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        #expect(physical.healthLost == 5)
        #expect(leech.healthLost == 10)
    }

    @Test func ironhideDoesNotCapDotDamage() {
        let ironhideProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(maxDamagePerHitCap: 10)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: ironhideProfile,
            dealOpeningHand: false
        )
        let attackOutcome = battle.resolveDamage(DamageRequest(
            amount: 20,
            target: battle.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.enemy.id,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false, isAttackHit: true)
        ))
        #expect(attackOutcome.healthLost == 10)

        let dotOutcome = battle.resolveDamage(DamageRequest(
            amount: 20,
            target: battle.roster.hero.combatant,
            keyword: .bleed,
            sourceActorID: battle.roster.enemy.id,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false, isAttackHit: false)
        ))
        #expect(dotOutcome.healthLost == 20)
    }

    @Test func blockPerTurnDoesNotRequireDeathsDoor() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(blockPerTurn: 2),
                revival: RevivalTriggers(guaranteedCritWhileOnDeathsDoor: true)
            )),
            dealOpeningHand: false
        )
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.companion.combatant)
        ) == 2)
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

    @Test func thickHideReducesDamageTaken() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    mitigation: MitigationTriggers(
                        passiveMitigationFlat: 1
                    )
                )
            )
        )
        context.roster.mutateRuntime(for: companion) { $0.currentHealth = 15 }
        _ = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: companion,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(context.roster.health(for: companion) == 11)
    }
}

import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatTriggerTalentDamageTests {
    @Test func damageVsBleedingBonusAppliesWhenTargetIsBleeding() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBleedingBonus: 3)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func damageVsFrozenMultiplierDoublesDamage() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsFrozenMultiplier: 2)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 8)
    }

    @Test func holyDamageIgnoresEnemyBlock() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(holyIgnoresBlock: true)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 6, target: battle.roster.enemy.combatant, keyword: .holy, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 6)
        let block = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant))
        #expect(block == 10)
    }

    @Test func burnDamageVsNoBlockMultiplierApplies() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(burnDamageVsNoBlockMultiplier: 2)
            ))
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 3, target: battle.roster.enemy.combatant, keyword: .burn, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 6)
    }

    @Test func baneOfEvilDoublesHolyAgainstUndead() {
        let triggers = CombatTraitTriggers(
            damage: DamageTriggers(holyDamageVsUndeadOrCorruptedMultiplier: 2)
        )
        var undead = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: triggers),
            enemyFaction: .undead,
            dealOpeningHand: false
        )
        let vsUndead = undead.resolveDamage(
            DamageRequest(
                amount: 4,
                target: undead.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: undead.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        var mortal = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: triggers),
            enemyFaction: .mortal,
            dealOpeningHand: false
        )
        let vsMortal = mortal.resolveDamage(
            DamageRequest(
                amount: 4,
                target: mortal.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: mortal.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        #expect(vsUndead.healthLost == 8)
        #expect(vsMortal.healthLost == 4)
    }

    @Test func stalkerPrecisionCapsCritMultiplier() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(critMultiplierPerDodge: 0.5)
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        for _ in 0 ..< 4 {
            _ = CombatTriggerEngine.afterDodge(
                by: companion,
                attackerID: battle.roster.enemy.id,
                in: &battle
            )
        }
        #expect(battle.roster.runtime(for: companion)?.talentCritMultiplierBonus == 1.0)
    }

    @Test func nestedDamageBeyondDepthTwoIsRetaliation() {
        let harvest = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(onAnyHealthLossGainBlock: 1)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false
        )
        battle.talentReactionDepth = 2
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isAttackHit: true
                )
            )
        )
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant)
        ) == 0)
    }

    @Test func shieldScarabCompanionDealsBonusDamageToStunnedEnemies() {
        let scarabProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            damage: DamageTriggers(damageWhileTargetStunnedBonus: 4)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: scarabProfile,
            dealOpeningHand: false
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 100, 100), remainingTurns: 1)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 5,
            target: battle.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.companion.id,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false, isAttackHit: true)
        ))
        #expect(outcome.healthLost == 9)
    }

    @Test func keywordReactionsSkipRetaliationHolyPings() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(holyDamageTargetMissNextAttack: true),
                dot: DotTriggers(onBurnTickHolyDamage: 1)
            )),
            dealOpeningHand: false
        )
        _ = battle.resolveDamage(DamageRequest(
            amount: 1,
            target: battle.roster.enemy.combatant,
            keyword: .holy,
            sourceActorID: battle.roster.hero.id,
            options: DamageOptions(
                applyStatBonus: false,
                applyItemBonus: false,
                applyDodge: false,
                isRetaliation: true,
                isAttackHit: false
            )
        ))
        let hasEvade = battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }
        #expect(!hasEvade)
    }

    @Test func afflictedDamageAurasStackAdditively() {
        var stacked = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            heroModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Damnation"]
            ),
            companionModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Intense Heat"]
            ),
            dealOpeningHand: false
        )
        let stackedHit = stacked.resolveDamage(DamageRequest(
            amount: 20,
            target: stacked.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: stacked.roster.hero.id,
            options: DamageOptions(applyStatBonus: false, applyDodge: false)
        ))
        #expect(stackedHit.healthLost == 30)
        #expect(stackedHit.events.contains { $0.abilityName == "Damnation" && $0.kind == .ability })
        #expect(stackedHit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })

        var companionAura = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            companionModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Intense Heat"]
            ),
            dealOpeningHand: false
        )
        let auraHit = companionAura.resolveDamage(DamageRequest(
            amount: 20,
            target: companionAura.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: companionAura.roster.hero.id,
            options: DamageOptions(applyStatBonus: false, applyDodge: false)
        ))
        #expect(auraHit.healthLost == 25)
        #expect(auraHit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })
    }

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
}

import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatTriggerTalentDamageTests {
    @Test func `damage vs bleeding bonus applies when target is bleeding`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBleedingBonus: 3),
            )),
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source"),
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func `damage vs frozen multiplier doubles damage`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsFrozenMultiplier: 2),
            )),
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source"),
        )
        #expect(outcome.healthLost == 8)
    }

    @Test func `holy damage ignores enemy block`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(holyIgnoresBlock: true),
            )),
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 6, target: battle.roster.enemy.combatant, keyword: .holy, sourceActorID: "source"),
        )
        #expect(outcome.healthLost == 6)
        let block = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant))
        #expect(block == 10)
    }

    @Test func `piercing starlight ignores block only for holy damage`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(holyIgnoresBlockAndDodge: true),
            )),
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let holyOutcome = battle.resolveDamage(
            DamageRequest(amount: 6, target: battle.roster.enemy.combatant, keyword: .holy, sourceActorID: "source"),
        )
        #expect(holyOutcome.healthLost == 6)

        let physicalOutcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source"),
        )
        #expect(physicalOutcome.healthLost == 0)
        let block = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant))
        #expect(block == 6)
    }

    @Test func `burn damage vs no block multiplier applies`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(burnDamageVsNoBlockMultiplier: 2),
            )),
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 3, target: battle.roster.enemy.combatant, keyword: .burn, sourceActorID: "source"),
        )
        #expect(outcome.healthLost == 6)
    }

    @Test func `bane of evil doubles holy against undead`() {
        let triggers = CombatTraitTriggers(
            damage: DamageTriggers(holyDamageVsUndeadOrCorruptedMultiplier: 2),
        )
        var undead = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: triggers),
            enemyFaction: .undead,
            dealOpeningHand: false,
        )
        let vsUndead = undead.resolveDamage(
            DamageRequest(
                amount: 4,
                target: undead.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: undead.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false),
            ),
        )
        var mortal = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: triggers),
            enemyFaction: .mortal,
            dealOpeningHand: false,
        )
        let vsMortal = mortal.resolveDamage(
            DamageRequest(
                amount: 4,
                target: mortal.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: mortal.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false),
            ),
        )
        #expect(vsUndead.healthLost == 8)
        #expect(vsMortal.healthLost == 4)
    }

    @Test func `stalker precision caps crit multiplier`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(critMultiplierPerDodge: 0.5),
            )),
            dealOpeningHand: false,
        )
        let companion = battle.roster.companion.combatant
        for _ in 0 ..< 4 {
            _ = CombatTriggerEngine.afterDodge(
                by: companion,
                attackerID: battle.roster.enemy.id,
                in: &battle,
            )
        }
        #expect(battle.roster.runtime(for: companion)?.talentCritMultiplierBonus == 1.0)
    }

    @Test func `nested damage beyond depth two is retaliation`() {
        let harvest = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(onAnyHealthLossGainBlock: 1),
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false,
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
                    isAttackHit: true,
                ),
            ),
        )
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant),
        ) == 0)
    }

    @Test func `shield scarab companion deals bonus damage to stunned enemies`() {
        let scarabProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            damage: DamageTriggers(damageWhileTargetStunnedBonus: 4),
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: scarabProfile,
            dealOpeningHand: false,
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 100, 100), remainingTurns: 1)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 5,
            target: battle.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.companion.id,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false, isAttackHit: true),
        ))
        #expect(outcome.healthLost == 9)
    }

    @Test func `keyword reactions skip retaliation holy pings`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(holyDamageTargetMissNextAttack: true),
                dot: DotTriggers(onBurnTickHolyDamage: 1),
            )),
            dealOpeningHand: false,
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
                isAttackHit: false,
            ),
        ))
        let hasEvade = battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }
        #expect(!hasEvade)
    }

    @Test func `afflicted damage auras stack additively`() {
        var stacked = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            heroModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25),
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Damnation"],
            ),
            companionModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25),
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Intense Heat"],
            ),
            dealOpeningHand: false,
        )
        let stackedHit = stacked.resolveDamage(DamageRequest(
            amount: 20,
            target: stacked.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: stacked.roster.hero.id,
            options: DamageOptions(applyStatBonus: false, applyDodge: false),
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
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25),
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Intense Heat"],
            ),
            dealOpeningHand: false,
        )
        let auraHit = companionAura.resolveDamage(DamageRequest(
            amount: 20,
            target: companionAura.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: companionAura.roster.hero.id,
            options: DamageOptions(applyStatBonus: false, applyDodge: false),
        ))
        #expect(auraHit.healthLost == 25)
        #expect(auraHit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })
    }

    @Test func `prey on the weak uses hero talent on companion hits`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(companionDamageVsPoisonedBonus: 2),
            )),
            dealOpeningHand: false,
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.companion.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false),
            ),
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func `radiant health buffs hero hits while companion is full health`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(partyDamageBonusWhileCompanionFullHealth: 2),
            )),
            dealOpeningHand: false,
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false),
            ),
        )
        #expect(outcome.healthLost == 7)
    }
}

extension CombatTriggerTalentDamageTests {
    @Test func `unbroken vow allows ally with block to ignore enemy block and dodge`() {
        var battle = BattleTestFixtures.makePipelineContext(
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(unbrokenVow: true),
            )),
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            for: battle.roster.hero.combatant,
            on: &battle,
        )
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 2, effect: .shield(.block, 10), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .evadeNextHit, remainingTurns: 0),
            ],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 6, target: battle.roster.enemy.combatant, keyword: .holy, sourceActorID: "source"),
        )
        #expect(outcome.healthLost == 6)
        #expect(!outcome.isDodged)
        let enemyBlock = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant))
        #expect(enemyBlock == 10)
    }

    @Test func `unbroken vow does not give enemies block or dodge ignore`() {
        var battle = BattleTestFixtures.makePipelineContext(
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(unbrokenVow: true),
            )),
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 2, effect: .shield(.block, 10), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .evadeNextHit, remainingTurns: 0),
            ],
            for: battle.roster.hero.combatant,
            on: &battle,
        )
        let dodgedOutcome = battle.resolveDamage(
            DamageRequest(amount: 6, target: battle.roster.hero.combatant, keyword: .holy, sourceActorID: "target"),
        )
        #expect(dodgedOutcome.healthLost == 0)
        #expect(dodgedOutcome.isDodged)

        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 4, effect: .shield(.block, 10), remainingTurns: 0)],
            for: battle.roster.hero.combatant,
            on: &battle,
        )
        let blockedOutcome = battle.resolveDamage(
            DamageRequest(amount: 6, target: battle.roster.hero.combatant, keyword: .holy, sourceActorID: "target"),
        )
        #expect(blockedOutcome.healthLost == 0)
        #expect(!blockedOutcome.isDodged)
        let heroBlock = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant))
        #expect(heroBlock == 4)
    }
}

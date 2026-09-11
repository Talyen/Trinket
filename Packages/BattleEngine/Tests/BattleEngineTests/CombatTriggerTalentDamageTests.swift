import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatTriggerTalentDamageTests {
    @Test(arguments: [9, 10, 11])
    func `high altitude only adds dodge above half health`(health: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 20,
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(dodgeChanceAboveHalfHealthBonus: 0.15),
            )),
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = health }
        let hit = DamageResolutionState(
            amount: 1, combatant: battle.companion, sourceActorID: battle.enemy.id,
            damageKeyword: .physical, options: .attack(),
        )
        #expect(DamagePipeline.dodgeChance(for: hit, in: battle) == (health > 10 ? 0.25 : 0.10))
    }

    @Test func `damage vs bleeding bonus applies when target is bleeding`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBleedingBonus: 3),
            )),
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
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
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
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
                options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
            ),
        )
        var mortal = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
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
                options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
            ),
        )
        #expect(vsUndead.healthLost == 8)
        #expect(vsMortal.healthLost == 4)
    }

    @Test func `stalker precision caps crit multiplier`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
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
        #expect(battle.roster.runtime(for: companion)?.talents.battle.criticalMultiplierBonus == 1.0)
    }

    @Test func `nested damage beyond depth two is retaliation`() {
        let harvest = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(onAnyHealthLossGainBlock: 1),
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false,
        )

        _ = battle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOperation.attack(origin: .counterattack, scaling: .flat, accuracy: .unavoidable),
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
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
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
            options: DamageOperation.attack(tier: .skill, scaling: .items, accuracy: .unavoidable),
        ))
        #expect(outcome.healthLost == 9)
    }

    @Test func `keyword reactions skip retaliation holy pings`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(blindingLight: true),
                dot: DotTriggers(onBurnTickHolyDamage: 1),
            )),
            dealOpeningHand: false,
        )
        _ = battle.resolveDamage(DamageRequest(
            amount: 1,
            target: battle.roster.enemy.combatant,
            keyword: .holy,
            sourceActorID: battle.roster.hero.id,
            options: DamageOperation.reaction(cause: .talent, scaling: .flat, accuracy: .unavoidable),
        ))
        #expect(battle.heroTalents.history[battle.enemy.id]?.blindingReduction ?? 0 == 0)
    }

    @Test func `afflicted damage auras stack additively`() {
        var stacked = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
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
            options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
        ))
        #expect(stackedHit.healthLost == 30)
        #expect(stackedHit.events.contains { $0.abilityName == "Damnation" && $0.kind == .ability })
        #expect(stackedHit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })

        var companionAura = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
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
            options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
        ))
        #expect(auraHit.healthLost == 25)
        #expect(auraHit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })
    }

    @Test func `prey on the weak uses hero talent on companion hits`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
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
                options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
            ),
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func `radiant health buffs hero hits while companion is full health`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
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
                options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
            ),
        )
        #expect(outcome.healthLost == 7)
    }
}

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [(false, true, 8), (true, true, 5), (false, false, 5), (true, false, 5)])
    func `enrage boosts only party attacks`(enemySource: Bool, attackHit: Bool, expectedDamage: Int) {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    partyAllStatsBonusBelowHealthThreshold: 0.5,
                    partyAllStatsBonusBelowHealthAmount: 3,
                ),
            )),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 9 }
        let sourceID = enemySource ? battle.enemy.id : battle.hero.id
        let target = enemySource ? battle.hero : battle.enemy
        let request = attackHit ? DamageRequest(
            amount: 5,
            target: target,
            keyword: .physical,
            sourceActorID: sourceID,
            options: DamageOperation.attack(tier: .skill, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) : DamageRequest.doTTick(amount: 5, target: target, keyword: .burn, sourceActorID: sourceID)
        let outcome = battle.resolveDamage(request)
        #expect(outcome.healthLost == expectedDamage)
    }

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

    @Test func `damage cap applies to periodic hits`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(maxDamagePerHitCap: 12),
            )),
        )
        let outcome = battle.resolveDamage(
            DamageRequest.doTTick(amount: 20, target: battle.roster.hero.combatant, keyword: .burn, sourceActorID: "target"),
        )
        #expect(outcome.healthLost == 12)
    }
}

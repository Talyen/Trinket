import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleTurnEngineTests {
    private func makeContext(
        actorEffects: [ActiveEffect] = [],
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            abilities: [.slash]
        )
        return BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: actorEffects,
            rngSeed: seed,
            dealOpeningHand: false
        )
    }

    @Test func consumeActionSkipEmitsEventLingersStatusAndRecordsAction() throws {
        var context = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
        ])
        let enemy = context.roster.enemy.combatant
        let before = try #require(context.roster.runtime(for: enemy)?.actionCount)

        let events = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        try #expect(events.contains { $0.effectKind == .controlActionSkipped && $0.keyword == .stun })
        try #expect(!(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun)))
        try #expect(context.roster.hasControlStatus(for: enemy, keyword: .stun))
        try #expect(context.roster.activeEffects(for: enemy).contains { active in
            active.effect.isActionSkipPending && active.remainingTurns == BattleTiming.controlStatusLingerTurns
        })
        try #expect(try #require(context.roster.runtime(for: enemy)?.actionCount) == before + 1)
        try #expect(context.actionCount == 1)
    }

    @Test func performActionResolvesWhenNoSkipPending() throws {
        var context = makeContext()
        let enemy = context.roster.enemy.combatant
        let ability = try #require(enemy.abilityLoadout.basic)

        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: enemy,
            abilityTarget: context.roster.enemyAttackTarget,
            context: &context
        )

        try #expect(events.contains { $0.kind == .ability })
        try #expect(!(events.contains { $0.effectKind == .controlActionSkipped }))
    }

    @Test func deathgripGrantsBlockWhenEnteringDeathsDoor() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            maxHealth: 50,
            abilities: [.slash]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroHealth: 5,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    blockOnDeathsDoor: 8
                )
            )),
            seed: 0,
            nextEventID: 0
        )

        let (_, events) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(events.contains { $0.effectKind == .deathsDoorTriggered })
        let expectedBlock = context.paced(8, sourceActorID: hero.id)
        try #expect(events.contains { $0.abilityName == "Deathgrip" && $0.amount == expectedBlock })
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(
            context.roster.activeEffects(for: hero).contains {
                if case let .shield(keyword, points) = $0.effect {
                    return keyword == .block && points == expectedBlock
                }
                return false
            }
        )
    }

    @Test func abilityEventIncludesActorAbilityAndTier() throws {
        var context = makeContext()
        let enemy = context.roster.enemy.combatant
        let ability = try #require(enemy.abilityLoadout.basic)

        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: enemy,
            abilityTarget: context.roster.enemyAttackTarget,
            context: &context
        )
        let abilityEvent = try #require(events.first { $0.kind == .ability })

        #expect(abilityEvent.actorID == enemy.id)
        #expect(abilityEvent.abilityID == Ability.slash.id)
        #expect(abilityEvent.abilityName == Ability.slash.name)
        #expect(abilityEvent.abilityTier == Ability.slash.tier)
    }

    @Test func nextStrikeDoubleDoublesOutgoingDamageAndConsumes() throws {
        let ability = Ability(
            id: "test-strike",
            name: "Test Strike",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical)]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroEffects: [ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0)],
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
            nextEffectID: 2,
            nextEventID: 0
        )
        let healthBefore = context.roster.health(for: enemy)

        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context
        )

        let damageEvent = try #require(events.first { $0.kind == .abilityDamage })
        try #expect(damageEvent.amount == 4)
        try #expect(context.roster.health(for: enemy) == healthBefore - 4)
        try #expect(!(context.roster.activeEffects(for: hero).contains {
            if case .nextStrikeDouble = $0.effect {
                return true
            }
            return false
        }))
    }

    @Test func mixedDamageComponentsEmitExactFeedbackEventsAndOneLogSummary() {
        let ability = Ability(
            id: "mixed-strike",
            name: "Mixed Strike",
            tier: .basic,
            damageComponents: [
                DamageComponent(2, keyword: .physical),
                DamageComponent(2, keyword: .burn),
            ]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
            nextEventID: 0
        )
        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context
        )

        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 2)
        #expect(components.map(\.keyword) == [.physical, .burn])
        #expect(components.allSatisfy { $0.amount > 0 })
        #expect(Set(components.map(\.actionID)).count == 1)
        #expect(events.count { $0.kind == .ability } == 1)
        #expect(BattleLogReducer.entries(from: events).count == 1)
    }

    @Test func criticalMetadataBelongsToExactDamageComponent() throws {
        let ability = Ability(
            id: "critical-strike",
            name: "Critical Strike",
            tier: .basic,
            directDamage: 3,
            guaranteedCriticalIfEnemyBuffed: true
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 2),
            ],
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
            nextEventID: 0
        )
        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context
        )

        let component = try #require(events.first { $0.kind == .abilityDamage })
        #expect(component.isCritical)
        #expect(!events.contains { $0.effectKind != nil && $0.abilityName == "Critical" })
    }

    @Test(arguments: [true, false])
    func performActionAfterLethalHitSkipsCorpseEffectsButStillGrantsGold(grantGold: Bool) throws {
        let ability = Ability(
            id: grantGold ? "kill-gold" : "kill-mark",
            name: grantGold ? "Kill Gold" : "Kill Mark",
            tier: .basic,
            directDamage: 100,
            damageKeyword: .physical,
            effects: grantGold ? [.resourceGain(.gold, 3)] : [.marked(2, 4)]
        )
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [ability]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 5
        )
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            seed: 0,
            nextEventID: 0
        )
        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context
        )

        try #expect(context.roster.health(for: enemy) == 0)
        if grantGold {
            try #expect(context.gold == 3)
        } else {
            try #expect(!(context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect {
                    return true
                }
                return false
            }))
            let abilityEvent = try #require(events.first { $0.kind == .ability })
            try #expect(!(abilityEvent.appliedEffectSummaries.contains {
                $0.localizedCaseInsensitiveContains("mark")
            }))
        }
    }

    @Test func preferredTierFollowsEnemyCadence() throws {
        try #expect(BattleTurnEngine.preferredTier(for: 1) == .basic)
        try #expect(BattleTurnEngine.preferredTier(for: 2) == .basic)
        try #expect(BattleTurnEngine.preferredTier(for: 3) == .skill)
        try #expect(BattleTurnEngine.preferredTier(for: 6) == .ultimate)
        try #expect(BattleTurnEngine.preferredTier(for: 9) == .skill)
        try #expect(BattleTurnEngine.preferredTier(for: 12) == .ultimate)

        let basic = Ability(id: "basic", name: "Basic", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(id: "skill", name: "Skill", tier: .skill, directDamage: 5, description: "Skill")
        let ultimate = Ability(id: "ult", name: "Ult", tier: .ultimate, directDamage: 9, description: "Ult")
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 30,
            abilities: [basic, skill, ultimate]
        )
        try #expect(BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: 3)?.id == skill.id)
        try #expect(BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: 6)?.id == ultimate.id)
    }
}

struct BattleTurnEngineComponentTests {
    @Test func nextHolyStrikeBurnUsesAuthoredNotDoubledPotency() throws {
        let ability = Ability(
            id: "holy-strike",
            name: "Holy Strike",
            tier: .basic,
            damageComponents: [DamageComponent(10, keyword: .holy)]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 200)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroEffects: [ActiveEffect(id: 1, effect: .nextHolyStrike, remainingTurns: 0)],
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
            nextEffectID: 2,
            nextEventID: 0
        )
        let healthBefore = context.roster.health(for: enemy)

        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context
        )

        #expect(context.roster.health(for: enemy) == healthBefore - 30)
        let burnStatus = try #require(events.first { $0.kind == .status && $0.keyword == .burn })
        #expect(burnStatus.amount == 10)
        let burnStack = try #require(context.roster.enemy.activeEffects.first { $0.keyword == .burn })
        #expect(burnStack.effect.potency == 10)
    }

    @Test func multiTargetComponentsEmitAbilityDamageForEveryResolvedTargetAndSumInSummary() throws {
        let ability = Ability(
            id: "sweep",
            name: "Sweep",
            tier: .basic,
            damageComponents: [
                DamageComponent(2, keyword: .physical),
                DamageComponent(3, keyword: .physical, target: .enemy),
            ]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
            nextEventID: 0
        )

        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context
        )

        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 2)
        #expect(components.map(\.amount) == [2, 3])
        let summary = try #require(events.first { $0.kind == .ability })
        #expect(summary.amount == 5)
    }

    @Test func turnCadenceResetsAllParticipantsIncludingEnemy() throws {
        var context = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.slash]),
            dealOpeningHand: false
        )
        for participant in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[participant].combatant) { runtime in
                runtime.hasTakenAttackHitThisTurn = true
                runtime.faeWardBlockedThisTurn = true
            }
        }
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &context)
        for participant in BattleParticipant.allCases {
            let runtime = try #require(context.roster.runtime(for: context.roster[participant].combatant))
            #expect(!runtime.hasTakenAttackHitThisTurn)
            #expect(!runtime.faeWardBlockedThisTurn)
        }
    }

    @Test func manaEmpowermentTerminatesSafelyWithZeroCost() throws {
        let burnAbility = Ability(
            id: "flame-burst",
            name: "Flame Burst",
            tier: .basic,
            damageComponents: [DamageComponent(5, keyword: .burn)]
        )
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            maxMana: 10,
            abilities: [burnAbility]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    mana: ManaTriggers(
                        repeatManaEmpowerment: true,
                        empowermentCostReduction: 10
                    )
                )
            ),
            dealOpeningHand: false
        )
        context.roster.mutateRuntime(for: hero) {
            $0.currentMana = 5
        }
        let events = BattleTurnEngine.performAction(
            ability: burnAbility,
            actor: hero,
            abilityTarget: enemy,
            context: &context
        )
        try #expect(context.roster.runtime(for: hero)?.currentMana == 5)
        let summary = try #require(events.first { $0.kind == .ability })
        #expect(summary.amount == 6)
    }
}

import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

private func makeTurnContext(
    heroAbilities: [Ability] = [.slash],
    heroMaxHealth: Int = 20,
    heroHealth: Int? = nil,
    heroEffects: [ActiveEffect] = [],
    heroModifiers: CombatModifierProfile = .zero,
    enemyAbilities: [Ability] = [.slash],
    enemyMaxHealth: Int = 100,
    actorEffects: [ActiveEffect] = [],
    seed: UInt64 = CombatantFixtures.deterministicBattleSeed,
) -> BattleState {
    let resolvedHero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: heroMaxHealth, abilities: heroAbilities)
    let resolvedCompanion = CombatantFixtures.combatant(id: "companion", role: .companion)
    let resolvedEnemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: enemyMaxHealth, abilities: enemyAbilities)
    return BattleStateTestFactory.makeMinimalBattle(
        hero: resolvedHero,
        companion: resolvedCompanion,
        enemy: resolvedEnemy,
        heroEffects: heroEffects,
        enemyEffects: actorEffects,
        heroHealth: heroHealth,
        heroModifiers: heroModifiers,
        rngSeed: seed,
    )
}

struct BattleTurnEngineTests {
    @Test func `consume action skip emits event lingers status and records action`() throws {
        var context = makeTurnContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
        ])
        let enemy = context.roster.enemy.combatant
        let before = try #require(context.roster.runtime(for: enemy)?.actionCount)

        let events = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: enemy, context: &context) }

        try #expect(events.contains { $0.effectKind == .controlActionSkipped && $0.keyword == .stun })
        try #expect(!(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun)))
        try #expect(context.roster.hasControlStatus(for: enemy, keyword: .stun))
        try #expect(context.roster.activeEffects(for: enemy).contains { active in
            active.effect.isActionSkipPending && active.remainingTurns == BattleTiming.controlStatusLingerTurns
        })
        try #expect(try #require(context.roster.runtime(for: enemy)?.actionCount) == before + 1)
        try #expect(context.actionCount == 1)
    }

    @Test func `deathgrip grants block when entering deaths door`() throws {
        var context = makeTurnContext(
            heroMaxHealth: 50,
            heroHealth: 5,
            heroModifiers: CombatModifierProfile.withTriggers { $0.blockOnDeathsDoor = 8 },
            seed: 0,
        )
        let hero = context.hero

        let events = context.resolveTestDamage(
            40,
            to: hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ).events

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
            },
        )
    }

    @Test func `ability event includes actor ability and tier`() throws {
        var context = makeTurnContext()
        let enemy = context.roster.enemy.combatant
        let ability = try #require(enemy.abilityLoadout.basic)

        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: enemy,
            abilityTarget: context.roster.enemyAttackTarget,
            context: &context,
        )
        let abilityEvent = try #require(events.first { $0.kind == .ability })

        #expect(!events.contains { $0.effectKind == .controlActionSkipped })
        #expect(abilityEvent.actorID == enemy.id)
        #expect(abilityEvent.abilityID == Ability.slash.id)
        #expect(abilityEvent.abilityName == Ability.slash.name)
        #expect(abilityEvent.abilityTier == Ability.slash.tier)
    }

    @Test(arguments: [
        (Effect.nextStrikeDouble, Keyword.physical, 4, true),
        (.nextBurnBonus(1), .burn, 3, true),
        (.nextBurnBonus(1), .physical, 2, false),
    ])
    func `next hit bonuses match their keyword and consume only on a qualifying attack`(
        effect: Effect, keyword: Keyword, damage: Int, consumed: Bool,
    ) throws {
        let ability = Ability(id: "test-bonus", name: "Test Bonus", tier: .basic, damageComponents: [DamageComponent(2, keyword: keyword)])
        var context = makeTurnContext(
            heroAbilities: [ability], heroEffects: [ActiveEffect(id: 1, effect: effect, remainingTurns: 0)],
        )
        let healthBefore = context.health(of: context.enemy)
        let events = context.performTestAction(ability)
        let hit = try #require(events.first { $0.kind == .abilityDamage })
        #expect(hit.amount == damage)
        if consumed {
            #expect(context.health(of: context.enemy) == healthBefore - damage)
        }
        #expect(context.activeEffects(of: context.hero).contains {
            consumed ? $0.effect.kind == effect.kind : $0.effect == effect
        } == !consumed)
    }

    @Test func `mixed damage components emit exact feedback events and one log summary`() {
        let ability = Ability(
            id: "mixed-strike",
            name: "Mixed Strike",
            tier: .basic,
            damageComponents: [
                DamageComponent(2, keyword: .physical),
                DamageComponent(2, keyword: .burn),
            ],
        )
        var context = makeTurnContext(heroAbilities: [ability])
        let events = context.performTestAction(ability)

        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 2)
        #expect(components.map(\.keyword) == [.physical, .burn])
        #expect(components.allSatisfy { $0.amount > 0 })
        #expect(Set(components.map(\.actionID)).count == 1)
        #expect(events.count { $0.kind == .ability } == 1)
        #expect(BattleLogProjection.entries(from: events).count == 1)
    }

    @Test func `critical metadata belongs to exact damage component`() throws {
        let ability = Ability(
            id: "critical-strike",
            name: "Critical Strike",
            tier: .basic,
            directDamage: 3,
            guaranteedCriticalIfEnemyBuffed: true,
        )
        var context = makeTurnContext(
            heroAbilities: [ability],
            actorEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 2),
            ],
        )
        let events = context.performTestAction(ability)

        let component = try #require(events.first { $0.kind == .abilityDamage })
        #expect(component.isCritical)
        #expect(!events.contains { $0.effectKind != nil && $0.abilityName == "Critical" })
    }

    @Test(arguments: [true, false])
    func `perform action after lethal hit skips corpse effects but still grants gold`(grantGold: Bool) throws {
        let ability = Ability(
            id: grantGold ? "kill-gold" : "kill-mark",
            name: grantGold ? "Kill Gold" : "Kill Mark",
            tier: .basic,
            directDamage: 100,
            damageKeyword: .physical,
            effects: grantGold ? [.resourceGain(.gold, 3)] : [.marked(2, 4)],
        )
        var context = makeTurnContext(
            heroAbilities: [ability],
            enemyMaxHealth: 5,
            seed: 0,
        )
        let enemy = context.enemy
        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: context.hero,
            abilityTarget: enemy,
            context: &context,
        )

        try #expect(context.roster.health(for: enemy) == 0)
        if grantGold {
            try #expect(context.gold == 3)
        } else {
            try #expect(!(context.roster.activeEffects(for: enemy).contains {
                $0.effect.kind == .marked
            }))
            let abilityEvent = try #require(events.first { $0.kind == .ability })
            try #expect(!(abilityEvent.appliedEffectSummaries.contains {
                $0.localizedCaseInsensitiveContains("mark")
            }))
        }
    }

    @Test func `preferred tier follows enemy cadence`() throws {
        try #expect(BattleTurnEngine.preferredTier(for: 1) == .basic)
        try #expect(BattleTurnEngine.preferredTier(for: 2) == .basic)
        try #expect(BattleTurnEngine.preferredTier(for: 3) == .skill)
        try #expect(BattleTurnEngine.preferredTier(for: 6) == .ultimate)
        try #expect(BattleTurnEngine.preferredTier(for: 9) == .skill)
        try #expect(BattleTurnEngine.preferredTier(for: 12) == .ultimate)

        let basic = Ability(id: "basic", name: "Basic", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(id: "skill", name: "Skill", tier: .skill, directDamage: 5, description: "Skill")
        let ultimate = Ability(id: "ult", name: "Ult", tier: .ultimate, directDamage: 9, description: "Ult")
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30, abilities: [basic, skill, ultimate])
        try #expect(BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: 3)?.id == skill.id)
        try #expect(BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: 6)?.id == ultimate.id)
    }
}

struct BattleTurnEngineBurnBonusTests {
    @Test(arguments: [false, true])
    func `kindling doubles against an unburning enemy and consumes any existing burn bonus`(hasBonus: Bool) throws {
        var context = makeTurnContext(
            heroAbilities: [.kindling],
            heroEffects: hasBonus ? [ActiveEffect(id: 1, effect: .nextBurnBonus(1), remainingTurns: 0)] : [],
        )
        let events = context.performTestAction(.kindling)
        let hit = try #require(events.first { $0.kind == .abilityDamage })
        #expect(hit.amount == (hasBonus ? 5 : 4))
        #expect(!context.activeEffects(of: context.hero).contains { $0.effect.kind == .nextBurnBonus })
        if !hasBonus {
            #expect(!events.contains { $0.effectKind == .nextBurnBonusApplied })
        }
    }
}

struct BattleTurnEngineComponentTests {
    @Test func `next holy strike burn uses authored not doubled potency`() throws {
        let ability = Ability(id: "holy-strike", name: "Holy Strike", tier: .basic, damageComponents: [DamageComponent(10, keyword: .holy)])
        var context = makeTurnContext(
            heroAbilities: [ability],
            heroEffects: [ActiveEffect(id: 1, effect: .nextHolyStrike, remainingTurns: 0)],
            enemyMaxHealth: 200,
        )
        let healthBefore = context.roster.health(for: context.enemy)

        let events = context.performTestAction(ability)

        #expect(context.roster.health(for: context.enemy) == healthBefore - 30)
        let burnStatus = try #require(events.first { $0.kind == .status && $0.keyword == .burn })
        #expect(burnStatus.amount == 10)
        let burnStack = try #require(context.roster.enemy.activeEffects.first { $0.keyword == .burn })
        #expect(burnStack.effect.potency == 10)
    }

    @Test func `multi target components emit ability damage for every resolved target and sum in summary`() throws {
        let ability = Ability(
            id: "sweep",
            name: "Sweep",
            tier: .basic,
            damageComponents: [
                DamageComponent(2, keyword: .physical),
                DamageComponent(3, keyword: .physical, target: .enemy),
            ],
        )
        var context = makeTurnContext(heroAbilities: [ability])

        let events = context.performTestAction(ability)

        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 2)
        #expect(components.map(\.amount) == [2, 3])
        let summary = try #require(events.first { $0.kind == .ability })
        #expect(summary.amount == 5)
    }

    @Test func `turn cadence resets all participants including enemy`() throws {
        var context = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.slash]),
            dealOpeningHand: false,
        )
        for participant in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[participant].combatant) { runtime in
                runtime.talents.turn.tookAttackHit = true
                runtime.talents.turn.blockedFaeWard = true
            }
        }
        _ = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &context) }
        for participant in BattleParticipant.allCases {
            let runtime = try #require(context.roster.runtime(for: context.roster[participant].combatant))
            #expect(!runtime.talents.turn.tookAttackHit)
            #expect(!runtime.talents.turn.blockedFaeWard)
        }
    }

    @Test func `mana empowerment terminates safely with zero cost`() throws {
        let burnAbility = Ability(
            id: "flame-burst",
            name: "Flame Burst",
            tier: .basic,
            damageComponents: [DamageComponent(5, keyword: .burn)],
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50, maxMana: 10, abilities: [burnAbility])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: CombatModifierProfile.withTriggers {
                $0.repeatManaEmpowerment = true
                $0.empowermentCostReduction = 10
            },
            dealOpeningHand: false,
        )
        context.roster.mutateRuntime(for: hero) {
            $0.currentMana = 5
        }
        let events = BattleTurnEngine.performAction(
            ability: burnAbility,
            actor: hero,
            abilityTarget: enemy,
            context: &context,
        )
        try #expect(context.roster.runtime(for: hero)?.currentMana == 5)
        let summary = try #require(events.first { $0.kind == .ability })
        #expect(summary.amount == 6)
    }
}

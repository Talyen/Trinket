import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct DoTMechanicsTests {
    @Test func `lethal Bleed reaction does not remain on a defeated ally`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            heroHealth: 1, appliesFightPacing: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.hasConsumedDeathsDoor = true }

        CombatExecutor.run { await DoTApplicator.applyBleed(
            potency: 1, to: battle.hero, sourceActorID: battle.enemy.id,
            application: .reaction, in: &battle,
        ) }

        #expect(battle.roster.health(for: battle.hero) == 0)
        #expect(!battle.roster.activeEffects(for: battle.hero).contains { $0.effect.isBleed })
    }

    @Test(arguments: [Keyword.burn, .poison], [false, true])
    func `flashover doubles the burn hit but not stored ticks`(keyword: Keyword, frozen: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.burnDoubleVsFrozenChancePercent = 1
            }, appliesFightPacing: false,
        )
        let enemy = battle.roster.enemy.combatant
        if frozen {
            let threshold = ControlMeterEngine.threshold(for: enemy, in: battle)
            _ = battle.chargeTestControl(
                threshold,
                keyword: .freeze,
                to: enemy,
                sourceActorID: battle.roster.hero.id,
                applyFightPacing: false,
            )
        }
        #expect(battle.roster.hasControlStatus(for: enemy, keyword: .freeze) == frozen)
        let initialHit = battle.resolveTestDamage(4, to: enemy, keyword: keyword, sourceActorID: battle.roster.hero.id)
        #expect(initialHit.healthLost == (keyword == .burn && frozen ? 8 : 4))
        let effect: Effect = keyword == .burn ? .burn(4) : .poison(4)
        let active = ActiveEffect(id: 100, effect: effect, remainingTurns: 0, sourceActorID: battle.roster.hero.id)
        let healthBefore = battle.health(of: enemy)

        CombatExecutor.run { await EffectHandlers.advanceTurn(active, on: enemy, in: &battle) }

        let expectedDamage = keyword == .burn ? 2 : 3
        #expect(healthBefore - battle.health(of: enemy) == expectedDamage)
    }

    private func isolatedBattle(
        heroAbilities: [Ability] = [],
        enemyEffects: [ActiveEffect] = [],
        heroEffects: [ActiveEffect] = [],
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20, abilities: heroAbilities),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            activeEnemyEffects: enemyEffects,
            activeHeroEffects: heroEffects,
        )
    }

    private func burnAbility(potency: Int) -> Ability {
        Ability(id: "burn-\(potency)", name: "Burn", tier: .basic, directDamage: 0, description: "Burn", effects: [.burn(potency)])
    }

    private func poisonAbility(potency: Int) -> Ability {
        Ability(id: "poison-\(potency)", name: "Poison", tier: .basic, directDamage: 0, description: "Poison", effects: [.poison(potency)])
    }

    private func bleedAbility(potency: Int) -> Ability {
        Ability(id: "bleed-\(potency)", name: "Bleed", tier: .basic, directDamage: 0, description: "Bleed", effects: [.bleed(potency)])
    }

    private func statusAmounts(
        from events: [ActionEvent],
        keyword: Keyword,
    ) -> [Int] {
        events
            .filter { $0.kind == .status && $0.keyword == keyword }
            .map(\.amount)
    }

    @Test func `burn four deals four then two then one`() throws {
        var battle = isolatedBattle(heroAbilities: [burnAbility(potency: 4)])

        let applyEvents = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))
        try #expect(statusAmounts(from: applyEvents, keyword: .burn) == [4])
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 4)

        for potency in [2, 1, 0] {
            let events = battle.endTurn().events
            try #expect(statusAmounts(from: events, keyword: .burn) == (potency > 0 ? [potency] : []))
            try #expect(BattleTestFixtures.burnPotency(on: battle) == (potency > 0 ? potency : nil))
        }
    }

    @Test func `burn stacks merge and decay together`() throws {
        var battle = isolatedBattle(
            heroAbilities: [burnAbility(potency: 2)],
            enemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
        )

        _ = battle.endTurn()
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 2)

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 4)

        _ = battle.endTurn()
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 2)
    }

    @Test func `poison eight decays to zero`() throws {
        var battle = isolatedBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .poison(8), remainingTurns: 0)],
        )

        var amounts: [Int] = []
        for _ in 0 ..< 8 {
            let events = battle.endTurn().events
            amounts.append(contentsOf: statusAmounts(from: events, keyword: .poison))
            if battle.activeEffects(of: battle.enemy).contains(where: { $0.keyword == .poison }) == false {
                break
            }
        }

        try #expect(amounts == [6, 5, 4, 3, 2, 1])
        try #expect(!battle.activeEffects(of: battle.enemy).contains { $0.keyword == .poison })
    }

    @Test func `poison applies initial damage`() throws {
        var battle = isolatedBattle(heroAbilities: [poisonAbility(potency: 8)])

        let applyEvents = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))

        try #expect(statusAmounts(from: applyEvents, keyword: .poison) == [8])
        try #expect(
            battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }?.effect.potency == 8,
        )
    }

    @Test func `bleed four ticks once after apply`() throws {
        var battle = isolatedBattle(heroAbilities: [bleedAbility(potency: 4)])

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        var amounts: [Int] = []
        for _ in 0 ..< 2 {
            let events = battle.endTurn().events
            amounts.append(contentsOf: statusAmounts(from: events, keyword: .bleed))
        }

        try #expect(amounts == [4])
        try #expect(battle.health(of: battle.enemy) == 92)
        try #expect(!battle.activeEffects(of: battle.enemy).contains { $0.keyword == .bleed })
    }

    @Test func `bleed instances track independently`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20, abilities: [bleedAbility(potency: 6)]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20, abilities: [bleedAbility(potency: 4)]),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .companion, on: &battle)

        try #expect(battle.activeEffects(of: battle.enemy).count(where: { $0.keyword == .bleed }) == 2)
    }

    @Test func `burn respects block`() throws {
        var battle = isolatedBattle(
            heroAbilities: [burnAbility(potency: 4)],
            enemyEffects: [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 5)],
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        _ = battle.endTurn()

        try #expect(battle.health(of: battle.enemy) == 100)
    }

    @Test(arguments: [0, 10, 20])
    func `poison leech requires restored health for followups`(health: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 100,
            heroMaxMana: 5,
            heroMana: 0,
            heroModifiers: CombatModifierProfile.withTriggers {
                $0.criticalChanceBonus = -1
                $0.poisonDamageLeechChancePercent = 1
                $0.leechRestoreManaFlat = 2
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        let hero = battle.roster.hero.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = health }
        let events = battle.recordingResult { context in context.resolveTestDamage(4, keyword: .poison, options: .reaction()) }.events

        #expect(battle.roster.hero.currentMana == (health == 10 ? 2 : 0))
        #expect(battle.roster.hero.currentHealth == (health == 10 ? 12 : health))
        #expect(events.contains { $0.effectKind == .resourceGain } == (health == 10))
    }

    @Test func `poison leech heals once for attacks applications and ticks`() throws {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.poisonDamageLeechChancePercent = 1
            }, appliesFightPacing: false,
        )
        let hero = battle.roster.hero.combatant
        let enemy = battle.roster.enemy.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 20 }

        _ = battle.resolveTestDamage(8, keyword: .poison)
        #expect(battle.health(of: hero) == 24)

        battle.applyDecayingDoT(
            keyword: .poison, potency: 8, to: enemy,
            sourceActorID: hero.id, application: .ability,
        )
        #expect(battle.health(of: hero) == 28)

        let poison = battle.activeEffects(of: enemy).first { $0.keyword == .poison }
        let active = try #require(poison)
        CombatExecutor.run { await EffectHandlers.advanceTurn(active, on: enemy, in: &battle) }
        #expect(battle.health(of: hero) == 31)
        #expect(battle.health(of: enemy) == enemy.maxHealth - 22)
    }

    @Test(arguments: [false, true], [false, true])
    func `bleed rewards require health loss from cards and ticks`(isTick: Bool, blocked: Bool) {
        let bleed = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 1, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile.withTriggers {
                $0.onBleedDamageNextBasicCritBonus = 0.35
                $0.onBleedDamageHealSelf = 2
            },
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 10 }
        battle.roster.setActiveEffects(
            [bleed] + (blocked ? [ActiveEffect(id: 101, effect: .shield(.block, 10), remainingTurns: 0)] : []),
            for: battle.enemy,
        )
        if isTick {
            CombatExecutor.run { await EffectHandlers.advanceTurn(bleed, on: battle.enemy, in: &battle) }
        } else {
            _ = battle.performTestAction(.rendingSlash)
        }
        #expect(battle.roster.hero.currentHealth == (blocked ? 10 : 12))
        #expect(battle.roster.hero.talents.pending.basicCriticalBonus == (blocked ? 0 : 0.35))
    }

    private func makeRampBattle(cap: Int = 4) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            heroModifiers: CombatModifierProfile.withTriggers {
                $0.burnDamageRampPerRound = 1
                $0.burnDamageRampCap = cap
            },
            dealOpeningHand: false,
        )
    }

    @Test(arguments: [(4, [1, 2, 3, 4, 4]), (0, [1, 2, 3, 4, 5])])
    func `damage ramp grows each round with optional cap`(cap: Int, amounts: [Int]) throws {
        var battle = makeRampBattle(cap: cap)
        for expected in amounts {
            CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
            let runtime = try #require(battle.roster.runtime(for: battle.hero))
            #expect(runtime.talents.battle.keywordDamageRamp[.burn] == expected)
        }
        if cap > 0 {
            let companion = try #require(battle.roster.runtime(for: battle.companion))
            #expect(companion.talents.battle.keywordDamageRamp[.burn, default: 0] == 0)
        }
    }

    @Test func `damage ramp applies to matching keyword only`() {
        var battle = makeRampBattle(cap: 4)
        CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(DamagePipeline.outgoingDamageBonus(
            for: battle.roster.hero.id,
            keyword: .burn,
            in: battle,
        ) == 1)
        #expect(DamagePipeline.outgoingDamageBonus(
            for: battle.roster.hero.id,
            keyword: .bleed,
            in: battle,
        ) == 0)
    }
}

extension DoTMechanicsTests {
    @Test func `burn bonuses are stored once and double tick preserves resolved potency`() throws {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(
                damageDealtBonus: [.burn: 2],
                triggers: CombatTraitTriggers.configured {
                    $0.criticalChanceBonus = -1
                    $0.burnDamageDoubleChancePercent = 1
                    $0.burnTicksTwicePerTurn = true
                },
            ), appliesFightPacing: false,
        )
        let enemy = battle.roster.enemy.combatant
        let initial = battle.recordingEvents { battle in await battle.applyDecayingDoT(
            keyword: .burn, potency: 8, to: enemy,
            sourceActorID: battle.roster.hero.id, application: .ability,
        ) }
        #expect(statusAmounts(from: initial, keyword: .burn) == [20])
        let burn = battle.activeEffects(of: enemy).first { $0.keyword == .burn }
        let active = try #require(burn)
        #expect(active.effect.potency == 20)
        let ticks = battle.recordingEvents { battle in await EffectHandlers.advanceTurn(active, on: enemy, in: &battle) }
        #expect(statusAmounts(from: ticks, keyword: .burn) == [10, 10])
        #expect(battle.activeEffects(of: enemy).first { $0.keyword == .burn }?.effect.potency == 10)
    }

    @Test(arguments: [false, true])
    func `savage tear critically scales the whole bleed tick and reports critical damage`(specialCrit: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(
                damageDealtBonus: [.bleed: 2],
                triggers: CombatTraitTriggers.configured {
                    $0.criticalChanceBonus = 1
                    $0.bleedTickCritChancePercent = specialCrit ? 1 : 0
                },
            ), appliesFightPacing: false,
        )
        let hero = battle.roster.hero.combatant
        let enemy = battle.roster.enemy.combatant
        battle.roster.mutateRuntime(for: hero) { $0.talents.battle.criticalMultiplierBonus = 0.5 }
        let initial = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: .bleed, target: enemy,
            sourceActorID: hero.id, in: &battle,
        ) }
        #expect(initial.healthLost == 6)
        #expect(!initial.isCritical)
        let active = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 2, sourceActorID: hero.id)
        battle.roster.setActiveEffects([active], for: enemy)

        let events = battle.recordingEvents { battle in await EffectHandlers.advanceTurn(active, on: enemy, in: &battle) }

        #expect(statusAmounts(from: events, keyword: .bleed) == [specialCrit ? 15 : 6])
        let status = events.first { $0.kind == .status && $0.keyword == .bleed }
        #expect(status?.isCritical == specialCrit)
        #expect(battle.activeEffects(of: enemy).first?.effect.potency == 4)
        #expect(battle.activeEffects(of: enemy).first?.remainingTurns == 1)
    }
}

extension DoTMechanicsTests {
    private static func makeBurnManaBattle(
        threshold: Int = 0,
        perTurnCap: Int = 0,
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 100,
            heroMaxMana: 5,
            heroMana: 0,
            heroModifiers: CombatModifierProfile.withTriggers {
                $0.criticalChanceBonus = -1
                $0.burnDamageManaRestoreThreshold = threshold
                $0.onBurnDamageRestoreManaPerTurnCap = perTurnCap
                $0.onBurnDamageRestoreManaFlat = 1
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
    }

    @Test func `direct burn damage restores mana up to the per-turn cap`() {
        var battle = Self.makeBurnManaBattle(perTurnCap: 2)
        for expected in [1, 2, 2] {
            let outcome = battle.resolveTestDamage(3, keyword: .burn)
            #expect(outcome.healthLost == 3)
            #expect(battle.roster.hero.currentMana == expected)
        }
        #expect(battle.turnCadence.burnManaRestored[.hero] == 2)
    }

    @Test(arguments: [(3, 0), (5, 1)])
    func `direct burn damage honors the mana restore threshold`(damage: Int, expectedMana: Int) {
        var battle = Self.makeBurnManaBattle(threshold: 4)
        let outcome = battle.resolveTestDamage(damage, keyword: .burn)
        #expect(outcome.healthLost == damage)
        #expect(battle.roster.hero.currentMana == expectedMana)
    }

    @Test func `burn tick restores mana exactly once`() {
        var battle = Self.makeBurnManaBattle(perTurnCap: 2)
        let hero = battle.roster.hero.combatant
        let enemy = battle.roster.enemy.combatant
        let active = ActiveEffect(id: 100, effect: .burn(4), remainingTurns: 0, sourceActorID: hero.id)
        battle.roster.setActiveEffects([active], for: enemy)
        CombatExecutor.run { await EffectHandlers.advanceTurn(active, on: enemy, in: &battle) }
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.turnCadence.burnManaRestored[.hero] == 1)
    }

    @Test(arguments: [Keyword.burn, .poison])
    func `one potency DoT expires before dealing turn damage`(keyword: Keyword) {
        var battle = isolatedBattle()
        let effect: Effect = keyword == .burn ? .burn(1) : .poison(1)
        battle.insertEffect(effect, to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: battle.enemy, context: &battle) }
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(!battle.roster.hasAffliction(keyword, on: battle.enemy))
    }
}

import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct DoTMechanicsTests {
    @Test(arguments: [Keyword.burn, .poison], [false, true])
    func `flashover only doubles burn against frozen enemies`(keyword: Keyword, frozen: Bool) throws {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(criticalChanceBonus: -1, burnDoubleVsFrozenChancePercent: 1),
            )),
        )
        battle.appliesFightPacing = false
        let enemy = battle.roster.enemy.combatant
        if frozen {
            let threshold = ControlMeterEngine.threshold(for: enemy, in: battle)
            _ = ControlMeterEngine.applyMeterCharge(
                threshold, keyword: .freeze, to: enemy,
                sourceActorID: battle.roster.hero.id, applyFightPacing: false, in: &battle,
            )
        }
        #expect(battle.roster.hasControlStatus(for: enemy, keyword: .freeze) == frozen)
        let initialHit = battle.resolveDamage(DamageRequest(
            amount: 4, target: enemy, keyword: keyword,
            sourceActorID: battle.roster.hero.id, options: .attack(),
        ))
        #expect(initialHit.healthLost == (keyword == .burn && frozen ? 8 : 4))
        let effect: Effect = keyword == .burn ? .burn(4) : .poison(4)
        let active = ActiveEffect(id: 100, effect: effect, remainingTurns: 0, sourceActorID: battle.roster.hero.id)
        let handler = try #require(EffectHandlers.all[effect.kind])
        let healthBefore = battle.health(of: enemy)

        _ = handler.advanceTurn(active, on: enemy, in: &battle)

        let expectedDamage = keyword == .burn ? (frozen ? 4 : 2) : 3
        #expect(healthBefore - battle.health(of: enemy) == expectedDamage)
    }

    private func isolatedBattle(
        heroAbilities: [Ability] = [],
        enemyEffects: [ActiveEffect] = [],
        heroEffects: [ActiveEffect] = [],
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                abilities: heroAbilities,
            ),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100),
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

        let tickOne = BattleTestFixtures.endTurn(on: &battle)
        try #expect(statusAmounts(from: tickOne, keyword: .burn) == [2])
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 2)

        let tickTwo = BattleTestFixtures.endTurn(on: &battle)
        try #expect(statusAmounts(from: tickTwo, keyword: .burn) == [1])
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 1)

        let tickThree = BattleTestFixtures.endTurn(on: &battle)
        try #expect(statusAmounts(from: tickThree, keyword: .burn).isEmpty)
        try #expect(BattleTestFixtures.burnPotency(on: battle) == nil)
    }

    @Test func `burn stacks merge and decay together`() throws {
        var battle = isolatedBattle(
            heroAbilities: [burnAbility(potency: 2)],
            enemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 2)

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 4)

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(BattleTestFixtures.burnPotency(on: battle) == 2)
    }

    @Test func `poison eight decays to zero`() throws {
        var battle = isolatedBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .poison(8), remainingTurns: 0)],
        )

        var amounts: [Int] = []
        for _ in 0 ..< 8 {
            let events = BattleTestFixtures.endTurn(on: &battle)
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
            let events = BattleTestFixtures.endTurn(on: &battle)
            amounts.append(contentsOf: statusAmounts(from: events, keyword: .bleed))
        }

        try #expect(amounts == [4])
        try #expect(battle.health(of: battle.enemy) == 92)
        try #expect(!battle.activeEffects(of: battle.enemy).contains { $0.keyword == .bleed })
    }

    @Test func `bleed instances track independently`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [bleedAbility(potency: 6)]),
            companion: Combatant(
                id: "companion",
                name: "Companion",
                role: .companion,
                maxHealth: 20,
                abilities: [bleedAbility(potency: 4)],
            ),
            enemy: CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100),
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .companion, on: &battle)

        try #expect(battle.activeEffects(of: battle.enemy).count(where: { $0.keyword == .bleed }) == 2)
    }

    @Test func `burn respects block`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                abilities: [burnAbility(potency: 4)],
            ),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 5),
            ],
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        _ = BattleTestFixtures.endTurn(on: &battle)

        try #expect(battle.health(of: battle.enemy) == 100)
    }

    @Test(arguments: [0, 10, 20])
    func `poison leech requires restored health for followups`(health: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 100,
            heroMaxMana: 5,
            heroMana: 0,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(criticalChanceBonus: -1),
                dot: DotTriggers(poisonDamageLeechPercent: 0.5),
                mana: ManaTriggers(leechRestoreManaFlat: 2),
            )),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let hero = battle.roster.hero.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = health }
        let events = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.roster.enemy.combatant, keyword: .poison,
            sourceActorID: hero.id, options: .reaction(),
        )).events

        #expect(battle.roster.hero.currentMana == (health == 10 ? 2 : 0))
        #expect(battle.roster.hero.currentHealth == (health == 10 ? 12 : health))
        #expect(events.contains { $0.effectKind == .resourceGain } == (health == 10))
    }

    @Test func `toxiphage heals once for poison attacks applications and ticks`() throws {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(criticalChanceBonus: -1),
                dot: DotTriggers(poisonDamageLeechPercent: 0.5),
            )),
        )
        battle.appliesFightPacing = false
        let hero = battle.roster.hero.combatant
        let enemy = battle.roster.enemy.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 20 }

        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: enemy, keyword: .poison, sourceActorID: hero.id,
            options: .attack(),
        ))
        #expect(battle.health(of: hero) == 24)

        _ = battle.applyDecayingDoT(
            keyword: .poison, potency: 8, to: enemy,
            sourceActorID: hero.id, application: .ability,
        )
        #expect(battle.health(of: hero) == 28)

        let poison = battle.activeEffects(of: enemy).first { $0.keyword == .poison }
        let active = try #require(poison)
        let handler = try #require(EffectHandlers.all[.poison])
        _ = handler.advanceTurn(active, on: enemy, in: &battle)
        #expect(battle.health(of: hero) == 31)
        #expect(battle.health(of: enemy) == enemy.maxHealth - 22)
    }

    @Test(arguments: [false, true], [false, true])
    func `bleed rewards require health loss from cards and ticks`(isTick: Bool, blocked: Bool) throws {
        let bleed = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 1, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                attack: AttackTriggers(onBleedDamageNextBasicCritBonus: 0.35),
                dot: DotTriggers(onBleedDamageHealSelf: 2),
            )),
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 10 }
        battle.roster.setActiveEffects(
            [bleed] + (blocked ? [ActiveEffect(id: 101, effect: .shield(.block, 10), remainingTurns: 0)] : []),
            for: battle.enemy,
        )
        if isTick {
            let handler = try #require(EffectHandlers.all[.bleed])
            _ = handler.advanceTurn(bleed, on: battle.enemy, in: &battle)
        } else {
            _ = BattleTurnEngine.performAction(
                ability: .rendingSlash, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
            )
        }
        #expect(battle.roster.hero.currentHealth == (blocked ? 10 : 12))
        #expect(battle.roster.hero.pendingBasicCritBonus == (blocked ? 0 : 0.35))
    }

    @Test(arguments: [false, true])
    func `noxious reaction consumes poison equal to bleed damage`(isTick: Bool) throws {
        let bleed = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 1, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatantTalentCatalog.profile(for: ["rogue_poison_t2_1"]),
            dealOpeningHand: false,
        )
        battle.roster.setActiveEffects(
            [bleed, ActiveEffect(id: 101, effect: .poison(6), remainingTurns: 0, sourceActorID: "hero")],
            for: battle.enemy,
        )
        let events: [ActionEvent]
        if isTick {
            let handler = try #require(EffectHandlers.all[.bleed])
            events = handler.advanceTurn(bleed, on: battle.enemy, in: &battle)
        } else {
            events = BattleTurnEngine.performAction(
                ability: .rendingSlash, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
            )
        }
        let bleedDamage = events.filter {
            $0.keyword == .bleed && $0.kind == (isTick ? .status : .abilityDamage)
        }.reduce(0) { $0 + $1.amount }
        let consumed = min(6, bleedDamage)
        #expect(consumed > 0)
        #expect(statusAmounts(from: events, keyword: .poison) == [consumed])
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .poison(6 - consumed) })
    }

    @Test func `damage ramp grows each round up to cap`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(dot: DotTriggers(
                    burnDamageRampPerRound: 1,
                    burnDamageRampCap: 4,
                )),
            ),
            dealOpeningHand: false,
        )
        for expected in [1, 2, 3, 4, 4] {
            _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
            let runtime = try #require(battle.roster.runtime(for: battle.roster.hero.combatant))
            #expect(runtime.keywordDamageRamp[.burn] == expected)
        }
        let companion = try #require(battle.roster.runtime(for: battle.roster.companion.combatant))
        #expect(companion.keywordDamageRamp[.burn, default: 0] == 0)
    }

    @Test func `damage ramp grows uncapped without a cap`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(dot: DotTriggers(
                    burnDamageRampPerRound: 1,
                    burnDamageRampCap: 0,
                )),
            ),
            dealOpeningHand: false,
        )
        for expected in [1, 2, 3, 4, 5] {
            _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
            let runtime = try #require(battle.roster.runtime(for: battle.roster.hero.combatant))
            #expect(runtime.keywordDamageRamp[.burn] == expected)
        }
    }

    @Test func `damage ramp applies to matching keyword only`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.slash]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(dot: DotTriggers(
                    burnDamageRampPerRound: 1,
                    burnDamageRampCap: 4,
                )),
            ),
            dealOpeningHand: false,
        )
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
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
    @Test func `burn doubling applies once to initial damage and each decayed tick`() throws {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(
                damageDealtBonus: [.burn: 2],
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(criticalChanceBonus: -1, burnDamageDoubleChancePercent: 1),
                    dot: DotTriggers(burnTicksTwicePerTurn: true),
                ),
            ),
        )
        battle.appliesFightPacing = false
        let enemy = battle.roster.enemy.combatant
        let initial = battle.applyDecayingDoT(
            keyword: .burn, potency: 8, to: enemy,
            sourceActorID: battle.roster.hero.id, application: .ability,
        )
        #expect(statusAmounts(from: initial, keyword: .burn) == [20])
        let burn = battle.activeEffects(of: enemy).first { $0.keyword == .burn }
        let active = try #require(burn)
        #expect(active.effect.potency == 8)
        let handler = try #require(EffectHandlers.all[.burn])
        let ticks = handler.advanceTurn(active, on: enemy, in: &battle)
        #expect(statusAmounts(from: ticks, keyword: .burn) == [12, 12])
        #expect(battle.activeEffects(of: enemy).first { $0.keyword == .burn }?.effect.potency == 4)
    }

    @Test(arguments: [false, true])
    func `savage tear critically scales the whole bleed tick and reports critical damage`(specialCrit: Bool) throws {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(
                damageDealtBonus: [.bleed: 2],
                triggers: CombatTraitTriggers(damage: DamageTriggers(
                    criticalChanceBonus: 1,
                    bleedTickCritChancePercent: specialCrit ? 1 : 0,
                )),
            ),
        )
        battle.appliesFightPacing = false
        let hero = battle.roster.hero.combatant
        let enemy = battle.roster.enemy.combatant
        battle.roster.mutateRuntime(for: hero) { $0.talentCritMultiplierBonus = 0.5 }
        let initial = DoTDamage.resolveTurnDamage(
            basePotency: 4, keyword: .bleed, target: enemy,
            sourceActorID: hero.id, in: &battle,
        )
        #expect(initial.healthLost == 6)
        #expect(!initial.isCritical)
        let active = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 2, sourceActorID: hero.id)
        battle.roster.setActiveEffects([active], for: enemy)
        let handler = try #require(EffectHandlers.all[.bleed])

        let events = handler.advanceTurn(active, on: enemy, in: &battle)

        #expect(statusAmounts(from: events, keyword: .bleed) == [specialCrit ? 15 : 6])
        let status = events.first { $0.kind == .status && $0.keyword == .bleed }
        #expect(status?.isCritical == specialCrit)
        #expect(battle.activeEffects(of: enemy).first?.effect.potency == 4)
        #expect(battle.activeEffects(of: enemy).first?.remainingTurns == 1)
    }
}

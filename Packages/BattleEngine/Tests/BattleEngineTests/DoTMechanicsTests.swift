import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct DoTMechanicsTests {
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
                dot: DotTriggers(poisonDamageLeechPercent: 0.5),
                mana: ManaTriggers(leechRestoreManaFlat: 2),
            )),
            dealOpeningHand: false,
        )
        let hero = battle.roster.hero.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = health }
        let events = CombatTriggerEngine.afterDoTTick(
            keyword: .poison, healthLost: 4, target: battle.roster.enemy.combatant,
            sourceActorID: hero.id, in: &battle,
        )

        #expect(battle.roster.hero.currentMana == (health == 10 ? 2 : 0))
        #expect(battle.roster.hero.currentHealth == (health == 10 ? 12 : health))
        #expect(events.contains { $0.effectKind == .resourceGain } == (health == 10))
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
            events = handler.advanceTurn(bleed, on: battle.enemy, in: &battle).events
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
}

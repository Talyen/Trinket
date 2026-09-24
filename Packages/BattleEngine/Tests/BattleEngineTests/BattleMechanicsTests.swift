import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleMechanicsTests {
    @Test func `mutual knockout is a defeat without victory Gold`() {
        let gold = CombatModifierProfile(triggers: CombatTraitTriggers(gold: GoldTriggers(victoryGoldFlat: 4)))
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(1), remainingTurns: 0)],
            heroHealth: 1, companionHealth: 0, enemyHealth: 1,
            heroModifiers: gold, companionModifiers: gold,
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.hero) { $0.hasConsumedDeathsDoor = true }

        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.hero, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .attack(accuracy: .unavoidable),
        ))
        _ = battle.appendDefeatMilestonesIfNeeded()

        #expect(battle.isPartyDefeated && battle.isEnemyDefeated)
        #expect(BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: true) == .defeat)
        #expect(battle.gold == 0)
    }

    @Test func `a defeated ally does not grant victory Gold`() {
        let gold = CombatModifierProfile(triggers: CombatTraitTriggers(gold: GoldTriggers(victoryGoldFlat: 4)))
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            companionHealth: 0, enemyHealth: 0,
            companionModifiers: gold,
        )

        _ = battle.appendDefeatMilestonesIfNeeded()

        #expect(battle.isEnemyDefeated && !battle.isPartyDefeated)
        #expect(battle.gold == 0)
    }

    @Test func `advancing a copied battle expires talent bonuses without changing the original`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
        )
        battle.roster.hero.talents.battle.damageBonus = 2
        battle.roster.hero.talents.pending.nextAttackHolyBonus = 4
        battle.roster.hero.talents.turn.cleansedKeywordProtection = [.burn]
        battle.roster.hero.talents.timed.dodge = .init(amount: 0.3, expiresAtTurn: 2)
        battle.roster.hero.talents.timed.damage = .init(amount: 0.5, expiresAtTurn: 1)
        let original = battle.roster.hero
        var preview = battle

        _ = preview.endTurn()

        #expect(preview.roster.hero.talents.turn.cleansedKeywordProtection.isEmpty)
        #expect(preview.roster.hero.talents.timed.damage.amount == 0)
        #expect(preview.roster.hero.talents.timed.dodge.amount == 0.3)
        _ = preview.endTurn()
        #expect(preview.roster.hero.talents.timed.dodge.amount == 0)
        #expect(preview.roster.hero.talents.pending.nextAttackHolyBonus == 4)
        #expect(preview.roster.hero.talents.battle.damageBonus == 2)
        #expect(battle.roster.hero == original)
    }

    @Test(arguments: [DamageOperation.periodic, .reaction()])
    func `repeating nonattack damage preserves attack resources and rewards`(operation: DamageOperation) {
        var profile = CombatModifierProfile.zero
        profile.triggers.onAttackStealGold = 2
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.appliesFightPacing = false
        battle.roster.hero.talents.pending.nextAttackHolyBonus = 3
        let result = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: operation.repeated(),
        ))
        #expect(result.healthLost == 4)
        #expect(battle.roster.enemy.currentHealth == 46)
        #expect(battle.roster.hero.talents.pending.nextAttackHolyBonus == 3)
        #expect(battle.gold == 0)
    }

    private func makeContext(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant,
        heroMana: Int? = nil,
        enemyEffects: [ActiveEffect] = [],
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: enemyEffects,
        )
        if let heroMana {
            battle.roster.hero.currentMana = heroMana
        }
        return battle
    }

    @Test func `marked bonus adds damage and consumes mark`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEffects: [ActiveEffect(id: 1, effect: .marked(2, 6), remainingTurns: 6, sourceActorID: hero.id)],
        )

        let dotOutcome = context.resolveDamage(
            .doTTick(amount: 3, target: enemy, keyword: .burn, sourceActorID: hero.id),
        )

        try #expect(dotOutcome.healthLost == 3)
        try #expect(context.roster.activeEffects(for: enemy).contains {
            if case .marked = $0.effect {
                return true
            }
            return false
        })

        let attackOutcome = context.resolveDamage(
            .directAbilityHit(amount: 3, target: enemy, keyword: .physical, sourceActorID: hero.id),
        )

        try #expect(attackOutcome.healthLost == 5)
        try #expect(
            !context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect {
                    return true
                }
                return false
            },
        )
    }

    @Test func `predators focus applies leech preparation`() throws {
        let baseWolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let wolf = baseWolf.withAbilityLoadout(
            AbilityLoadout(
                basic: baseWolf.abilityLoadout.basic,
                skill: .predatorsFocus,
                ultimate: baseWolf.abilityLoadout.ultimate,
            ),
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(hero: hero, companion: wolf, enemy: enemy)
        let ability = try #require(wolf.abilityLoadout.skill)

        _ = BattleTurnEngine.performAction(
            ability: ability,
            actor: wolf,
            abilityTarget: context.enemy,
            context: &context,
        )

        try #expect(context.roster.activeEffects(for: wolf).contains { $0.effect == .nextStrikeLeech })
        try #expect(!context.roster.activeEffects(for: wolf).contains { $0.effect == .nextStrikeCritical })
    }

    @Test func `next strike critical guarantees crit and consumes`() throws {
        let ability = Ability(
            id: "test-crit-strike",
            name: "Test Crit Strike",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical)],
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroEffects: [ActiveEffect(id: 1, effect: .nextStrikeCritical, remainingTurns: 0)],
            nextEffectID: 2,
            nextEventID: 0,
        )
        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context,
        )

        let damageEvent = try #require(events.first { $0.kind == .abilityDamage })
        try #expect(damageEvent.isCritical)
        try #expect(!(context.roster.activeEffects(for: hero).contains {
            if case .nextStrikeCritical = $0.effect {
                return true
            }
            return false
        }))
    }

    @Test func `marked consumed when fully shielded`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 50), remainingTurns: 6, sourceActorID: hero.id)
        let mark = ActiveEffect(id: 2, effect: .marked(5, 6), remainingTurns: 6, sourceActorID: hero.id)

        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy,
            enemyEffects: [shield, mark],
            nextEffectID: 3,
        )

        let outcome = context.resolveDamage(
            DamageRequest.directAbilityHit(amount: 3, target: enemy, keyword: .physical, sourceActorID: hero.id),
        )

        try #expect(outcome.healthLost == 0)
        try #expect(
            !context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect {
                    return true
                }; return false
            },
        )
        try #expect(outcome.events.contains { $0.effectKind == .markedConsumed })
    }
}

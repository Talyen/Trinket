import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleMechanicsTests {
    @Test(arguments: [(80, 0.10), (81, 0.20)])
    func `pack bloodlust requires health above eighty percent`(health: Int, expectedChance: Double) {
        let battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(),
            companionHealth: health,
            companionModifiers: CombatantTalentCatalog.profile(for: ["panther_leech_t3_2"]),
        )
        for actor in [battle.hero, battle.companion] {
            #expect(CriticalChanceEngine.chance(
                actorID: actor.id, defender: battle.enemy, in: battle,
            ) == expectedChance)
        }
    }

    @Test func `flanking position empowers the next hero hit`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: CombatantTalentCatalog.profile(for: ["wolf_dodge_t2_2"]),
        )
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        let hit = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
        ))
        #expect(hit.isCritical)
        #expect(hit.healthLost == 4)
        #expect(!battle.roster.companion.pendingGuaranteedCriticalAfterDodge)
    }

    @Test func `guaranteed basic hit consumes taste for blood`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: CombatantTalentCatalog.profile(for: ["rogue_bleed_t2_1"]),
        )
        _ = CombatTriggerEngine.afterBleedDamage(
            healthLost: 1, target: battle.enemy, sourceActorID: battle.hero.id, in: &battle,
        )
        #expect(battle.roster.hero.pendingBasicCritBonus == 0.35)
        let hit = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
        ))
        #expect(hit.isCritical)
        #expect(battle.roster.hero.pendingBasicCritBonus == 0)
    }

    @Test func `block gained from reflected damage survives the incoming hit`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionEffects: [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 0)],
            enemyEffects: [ActiveEffect(id: 2, effect: .shield(.block, 20), remainingTurns: 0)],
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_freeze_t4_1"]),
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_block_t4_1"]),
        )
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 5, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: DamageOperation.effect(scaling: .statsAndItems, accuracy: .unavoidable),
        ))
        #expect(outcome.healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 5)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 20)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 15)
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

    @Test func `predators focus applies critical chance bonus`() throws {
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

        try #expect(
            context.roster.activeEffects(for: wolf).contains {
                if case .nextStrikeCritical = $0.effect {
                    return true
                }
                return false
            },
        )
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

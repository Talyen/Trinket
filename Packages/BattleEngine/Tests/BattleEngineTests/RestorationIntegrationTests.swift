import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct RestorationIntegrationTests {
    @Test(arguments: [0, 3, 10])
    func `healing reports overflow without inflating restoration`(missingHealth: Int) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
        )
        battle.roster.hero.currentHealth = battle.hero.maxHealth - missingHealth
        var request = HealRequest(
            amount: 10, target: battle.hero,
            logAs: .instantHeal(actorName: battle.hero.name, abilityName: "Heal", keyword: .health),
        )
        request.amountBasis = .resolved

        let result = HealingEngine.resolveHealing(request, in: &battle)

        #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
        #expect(result.directRestoration == missingHealth)
        #expect(result.events.first { $0.effectKind == .instantHeal }?.amount == missingHealth)
        let overflow = result.events.filter { $0.effectKind == .overheal }
        #expect(overflow.map(\.amount) == (missingHealth < 10 ? [10 - missingHealth] : []))
        #expect(overflow.allSatisfy { BattleLogReducer.line(for: $0) == nil })
    }

    @Test func `full health leech emits overflow without triggering leech success`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
        )
        battle.appliesFightPacing = false
        let result = HealingEngine.leechFromDamage(
            20, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle,
        )
        #expect(result.healthDelta == 0)
        #expect(!result.flags.contains(.leeched))
        #expect(result.events.contains { $0.effectKind == .overheal && $0.amount > 0 })
    }

    @Test func `instant heal restores health`() throws {
        let heal = Ability(
            id: "heal",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 3 Health.",
            effects: [.instantHeal(.health, 3)],
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 10, abilities: [heal])
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
            ],
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Heal", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) == 10)
        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
    }

    @Test func `leech heals attacker on damage dealt`() throws {
        let leechSlash = Ability(
            id: "leech-slash",
            name: "Leech Slash",
            tier: .basic,
            directDamage: 2,
            damageKeyword: .physical,
            hasLeech: true,
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 10, abilities: [leechSlash])
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(5), remainingTurns: 0),
            ],
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Leech Slash", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) > 8)
        try #expect(events.contains { $0.effectKind == .leechHeal && $0.keyword == .leech && $0.amount > 0 })
    }

    @Test func `enemy instant heal restores health when below max`() throws {
        let selfHeal = Ability(
            id: "self-heal",
            name: "Self Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 5 Health.",
            effects: [.instantHeal(.health, 5)],
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 20, abilities: [selfHeal])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
            ],
        )

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 16 }
        }

        let events = BattleTestFixtures.endTurn(on: &battle)

        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
        try #expect(battle.health(of: battle.enemy) >= 16)
    }

    @Test func `hero leech share skips zero-rounded shares instead of fabricating healing`() {
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                healing: HealingTriggers(companionLeechSharePercent: 0.1),
            )),
            dealOpeningHand: false,
        )
        battle.roster.companion.currentHealth -= 5
        let healthBefore = battle.roster.companion.currentHealth
        let events = battle.withEngineContext {
            HealingEngine.shareHeroLeechWithCompanion(restored: 1, in: &$0)
        }
        #expect(events.isEmpty)
        #expect(battle.roster.companion.currentHealth == healthBefore)
    }

    @Test(arguments: [0, 1, 9, 10])
    func `overheal transfer consumes only recipient space before converting the remainder`(companionHealth: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 10, heroMaxMana: 10,
            heroModifiers: .init(triggers: CombatTraitTriggers(healing: HealingTriggers(
                wishspring: true, overhealConvertsToBlock: true, leechOverhealTransfersToCompanion: true,
            ))),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = companionHealth
        battle.roster.hero.currentMana = 0
        var request = HealRequest(amount: 10, target: battle.hero, sourceActorID: battle.hero.id, origin: .leech, logAs: .silent)
        request.amountBasis = .resolved
        let result = HealingEngine.resolveHealing(request, in: &battle)
        let transferred = companionHealth > 0 ? 10 - companionHealth : 0
        #expect(result.allocation.transferred == transferred)
        #expect(result.allocation.block == 10 - transferred)
        #expect(result.allocation.remaining == 0)
        #expect(battle.roster.companion.currentHealth == (companionHealth > 0 ? 10 : 0))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 10 - transferred)
        #expect(battle.roster.hero.currentMana == min(5, battle.roster.hero.maxMana))
    }

    @Test(arguments: [DamageOperation.healthCost, .periodic, .reaction(), .redirected])
    func `damage cap policy follows operation semantics`(operation: DamageOperation) {
        #expect(DamageDefensePolicy.cappedDamage(20, operation: operation, cap: 12) == (operation.isHealthCost ? 20 : 12))
        #expect(DamageDefensePolicy.cappedDamage(8, operation: operation, cap: 12) == 8)
    }

    @Test func `bounded gains cannot reduce an already capped value`() {
        #expect(CombatGain.amount(3, current: 3, cap: 4) == 1)
        #expect(CombatGain.amount(3, current: 5, cap: 4) == 0)
        #expect(CombatGain.amount(30, current: 0, cap: 10) == 10)
    }

    @Test func `aether shield waits for overflow remaining after blood link`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 20,
            heroModifiers: .init(triggers: CombatTraitTriggers(healing: HealingTriggers(
                leechOverhealTransfersToCompanion: true, overhealFirstBlockPerTurn: 3,
            ))),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 10
        var request = HealRequest(amount: 10, target: battle.hero, sourceActorID: battle.hero.id, origin: .leech, logAs: .silent)
        request.amountBasis = .resolved
        _ = HealingEngine.resolveHealing(request, in: &battle)
        #expect(battle.roster.companion.currentHealth == 20)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 0)
        _ = HealingEngine.resolveHealing(request, in: &battle)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 3)
    }
}

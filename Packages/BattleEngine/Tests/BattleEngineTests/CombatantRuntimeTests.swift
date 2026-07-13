import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct CombatantRuntimeTests {
    private func makeCombatant(
        id: String = "hero",
        role: Combatant.Role = .hero,
        maxHealth: Int = 20,
        actionIntervalTicks: Int? = nil,
        toughness: Int = 0,
        agility: Int = 0
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: [],
            primaryStats: PrimaryStats(agility: agility, toughness: toughness)
        )
    }

    // MARK: - Initialization

    @Test func initialHealthAccountsForToughness() throws {
        let combatant = makeCombatant(maxHealth: 10, toughness: 5)
        let runtime = CombatantRuntime(combatant: combatant)
        try #expect(runtime.currentHealth == 15)
        try #expect(runtime.maxHealth == 15)
    }

    @Test func initialHealthUsesProvidedOverride() throws {
        let combatant = makeCombatant(maxHealth: 20, toughness: 0)
        let runtime = CombatantRuntime(combatant: combatant, initialHealth: 7)
        try #expect(runtime.currentHealth == 7)
    }

    @Test func initialActiveEffectsAreStored() throws {
        let combatant = makeCombatant()
        let initial = [ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)]
        let runtime = CombatantRuntime(combatant: combatant, initialActiveEffects: initial)
        try #expect(runtime.activeEffects == initial)
    }

    @Test func initialManaAccountsForIntellect() throws {
        let combatant = Combatant(
            id: "mage",
            name: "Mage",
            role: .hero,
            maxHealth: 20,
            maxMana: 10,
            abilities: [],
            primaryStats: PrimaryStats(intellect: 5)
        )
        let runtime = CombatantRuntime(combatant: combatant)
        try #expect(runtime.currentMana == 15)
        try #expect(runtime.maxMana == 15)
    }

    // MARK: - takeRawDamage

    @Test func healthMutationRulesRespectBoundsAndBonuses() throws {
        for (maxHealth, damage, expectedLoss, expectedHealth, alive) in [
            (10, 3, 3, 7, true),
            (5, 100, 5, 0, false)
        ] {
            var runtime = CombatantRuntime(combatant: makeCombatant(maxHealth: maxHealth))
            let lost = runtime.takeRawDamage(damage)
            try #expect(lost == expectedLoss)
            try #expect(runtime.currentHealth == expectedHealth)
            try #expect(runtime.isAlive == alive)
        }

        var cappedRuntime = CombatantRuntime(combatant: makeCombatant(maxHealth: 10))
        _ = cappedRuntime.takeRawDamage(5)
        try #expect(cappedRuntime.heal(100) == 5)
        try #expect(cappedRuntime.currentHealth == 10)

        var wisdomRuntime = CombatantRuntime(combatant: Combatant(
            id: "wisdom",
            name: "Wisdom",
            role: .hero,
            maxHealth: 20,
            abilities: [],
            primaryStats: PrimaryStats(wisdom: 10)
        ))
        _ = wisdomRuntime.takeRawDamage(15)
        try #expect(wisdomRuntime.heal(3) == 5)
        try #expect(wisdomRuntime.currentHealth == 10)

        var fullRuntime = CombatantRuntime(combatant: makeCombatant(maxHealth: 10))
        try #expect(fullRuntime.heal(5) == 0)
    }

    // MARK: - heal

    // MARK: - mana

    @Test func manaMutationRulesRespectBounds() throws {
        let combatant = Combatant(
            id: "mage",
            name: "Mage",
            role: .hero,
            maxHealth: 20,
            maxMana: 10,
            abilities: []
        )
        var runtime = CombatantRuntime(combatant: combatant)
        let spent = runtime.spendMana(4)
        try #expect(spent == 4)
        try #expect(runtime.currentMana == 6)
        let overspend = runtime.spendMana(100)
        try #expect(overspend == 6)
        try #expect(runtime.currentMana == 0)

        var cappedRuntime = CombatantRuntime(combatant: combatant)
        _ = cappedRuntime.spendMana(5)
        try #expect(cappedRuntime.restoreMana(100) == 5)
        try #expect(cappedRuntime.currentMana == 10)
    }

    // MARK: - markActed

    @Test func markActedIncrementsActionCount() throws {
        let combatant = makeCombatant()
        var runtime = CombatantRuntime(combatant: combatant)
        try #expect(runtime.actionCount == 0)

        runtime.markActed()
        try #expect(runtime.actionCount == 1)

        runtime.markActed()
        try #expect(runtime.actionCount == 2)
    }

    // MARK: - Effect storage

    @Test func setEffectsReplacesEntireArray() throws {
        let combatant = makeCombatant()
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.setEffects([
            ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0)
        ])
        try #expect(runtime.activeEffects.count == 2)
    }

    @Test func removeEffectsFiltersByPredicate() throws {
        let combatant = makeCombatant()
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.setEffects([
            ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0),
            ActiveEffect(id: 3, effect: .shield(.block, 5), remainingTicks: 6)
        ])
        runtime.removeEffects { $0.effect.isDecayingDoT }
        try #expect(runtime.activeEffects.count == 1)
        try #expect(runtime.activeEffects.first?.effect.keyword == .block)
    }

    // MARK: - Identity passthrough

    @Test func identityPassthrough() throws {
        let combatant = makeCombatant(id: "alice", role: .hero, maxHealth: 12, toughness: 3)
        let runtime = CombatantRuntime(combatant: combatant)
        try #expect(runtime.id == "alice")
        try #expect(runtime.name == "Alice")
        try #expect(runtime.role == .hero)
        try #expect(runtime.maxHealth == 15)
    }
}

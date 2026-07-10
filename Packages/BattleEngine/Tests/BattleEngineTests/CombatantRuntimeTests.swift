import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
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

    @Test func takeRawDamageSubtractsAndClampsAtZero() throws {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let lost = runtime.takeRawDamage(3)
        try #expect(lost == 3)
        try #expect(runtime.currentHealth == 7)
    }

    @Test func takeRawDamageOverkillReturnsActualAmount() throws {
        let combatant = makeCombatant(maxHealth: 5, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let lost = runtime.takeRawDamage(100)
        try #expect(lost == 5)
        try #expect(runtime.currentHealth == 0)
        try #expect(!(runtime.isAlive))
    }

    // MARK: - heal

    @Test func healRestoresUpToMax() throws {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        _ = runtime.takeRawDamage(8)
        let restored = runtime.heal(5)
        try #expect(restored == 5)
        try #expect(runtime.currentHealth == 7)
    }

    @Test func healCapsAtMaxHealth() throws {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        _ = runtime.takeRawDamage(5)
        let restored = runtime.heal(100)
        try #expect(restored == 5)
        try #expect(runtime.currentHealth == 10)
    }

    @Test func healIncludesWisdomBonus() throws {
        let combatant = makeCombatant(maxHealth: 20, toughness: 0)
        let wisCombatant = Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: combatant.maxHealth,
            abilities: [],
            primaryStats: PrimaryStats(wisdom: 10)
        )
        var runtime = CombatantRuntime(combatant: wisCombatant)
        _ = runtime.takeRawDamage(15)
        // Heal 3 + wisdom 10/5 = 2 → 5
        let restored = runtime.heal(3)
        try #expect(restored == 5)
        try #expect(runtime.currentHealth == 10)
    }

    @Test func healAtFullHealthReturnsZero() throws {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let restored = runtime.heal(5)
        try #expect(restored == 0)
        try #expect(runtime.currentHealth == 10)
    }

    // MARK: - mana

    @Test func spendManaSubtractsAndClamps() throws {
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
    }

    @Test func restoreManaCapsAtMax() throws {
        let combatant = Combatant(
            id: "mage",
            name: "Mage",
            role: .hero,
            maxHealth: 20,
            maxMana: 10,
            abilities: []
        )
        var runtime = CombatantRuntime(combatant: combatant)
        _ = runtime.spendMana(5)
        let restored = runtime.restoreMana(100)
        try #expect(restored == 5)
        try #expect(runtime.currentMana == 10)
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
            ActiveEffect(id: 3, effect: .shield(.block, 5, 6), remainingTicks: 6)
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

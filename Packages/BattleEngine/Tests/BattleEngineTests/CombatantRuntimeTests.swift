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

    @Test func initialHealthAccountsForToughness() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 5)
        let runtime = CombatantRuntime(combatant: combatant)
        #expect(runtime.currentHealth == 15)
        #expect(runtime.maxHealth == 15)
    }

    @Test func initialHealthUsesProvidedOverride() {
        let combatant = makeCombatant(maxHealth: 20, toughness: 0)
        let runtime = CombatantRuntime(combatant: combatant, initialHealth: 7)
        #expect(runtime.currentHealth == 7)
    }

    @Test func initialActiveEffectsAreStored() {
        let combatant = makeCombatant()
        let initial = [ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)]
        let runtime = CombatantRuntime(combatant: combatant, initialActiveEffects: initial)
        #expect(runtime.activeEffects == initial)
    }

    @Test func actionSpeedAppliesAgilityModifier() {
        let combatant = makeCombatant(actionIntervalTicks: 10, agility: 25)
        let runtime = CombatantRuntime(combatant: combatant)
        // intervalModifier = -agility / 5 = -5 → effectiveInterval = max(1, 10-5) = 5
        #expect(runtime.actionSpeed.effectiveInterval == 5)
    }

    @Test func nextReadyAtTickDefaultsToEffectiveInterval() {
        let combatant = makeCombatant(actionIntervalTicks: 3)
        let runtime = CombatantRuntime(combatant: combatant)
        #expect(runtime.nextReadyAtTick == 3)
    }

    // MARK: - Role defaults

    @Test func defaultActionSpeedUsesRoleBaselineWhenNoOverride() {
        let hero = makeCombatant(role: .hero, actionIntervalTicks: nil)
        let pet = makeCombatant(role: .pet, actionIntervalTicks: nil)
        let enemy = makeCombatant(role: .enemy, actionIntervalTicks: nil)

        // Baseline intervals from BattleState: hero 2, pet 2, enemy 6
        #expect(CombatantRuntime(combatant: hero).actionSpeed.effectiveInterval == 2)
        #expect(CombatantRuntime(combatant: pet).actionSpeed.effectiveInterval == 2)
        #expect(CombatantRuntime(combatant: enemy).actionSpeed.effectiveInterval == 6)
    }

    // MARK: - isReady

    @Test func isReadyRequiresAliveAndOnOrAfterReadyTick() {
        let combatant = makeCombatant(actionIntervalTicks: 4)
        var runtime = CombatantRuntime(combatant: combatant)
        #expect(!(runtime.isReady(atTick: 0)))
        #expect(!(runtime.isReady(atTick: 3)))
        #expect(runtime.isReady(atTick: 4))
        #expect(runtime.isReady(atTick: 100))
    }

    @Test func isReadyReturnsFalseForDefeatedCombatant() {
        let combatant = makeCombatant(actionIntervalTicks: 4)
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.takeRawDamage(99)
        #expect(!(runtime.isReady(atTick: 100)))
    }

    // MARK: - takeRawDamage

    @Test func takeRawDamageSubtractsAndClampsAtZero() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let lost = runtime.takeRawDamage(3)
        #expect(lost == 3)
        #expect(runtime.currentHealth == 7)
    }

    @Test func takeRawDamageOverkillReturnsActualAmount() {
        let combatant = makeCombatant(maxHealth: 5, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let lost = runtime.takeRawDamage(100)
        #expect(lost == 5)
        #expect(runtime.currentHealth == 0)
        #expect(!(runtime.isAlive))
    }

    // MARK: - heal

    @Test func healRestoresUpToMax() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        _ = runtime.takeRawDamage(8)
        let restored = runtime.heal(5)
        #expect(restored == 5)
        #expect(runtime.currentHealth == 7)
    }

    @Test func healCapsAtMaxHealth() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        _ = runtime.takeRawDamage(5)
        let restored = runtime.heal(100)
        #expect(restored == 5)
        #expect(runtime.currentHealth == 10)
    }

    @Test func healIncludesWisdomBonus() {
        let combatant = makeCombatant(maxHealth: 20, toughness: 0)
        // Combatant has no wisdom by default; bump it explicitly.
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
        #expect(restored == 5)
        #expect(runtime.currentHealth == 10)
    }

    @Test func healAtFullHealthReturnsZero() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let restored = runtime.heal(5)
        #expect(restored == 0)
        #expect(runtime.currentHealth == 10)
    }

    // MARK: - markActed

    @Test func markActedAdvancesScheduleAndIncrementsCount() {
        let combatant = makeCombatant(actionIntervalTicks: 4)
        var runtime = CombatantRuntime(combatant: combatant)
        #expect(runtime.actionCount == 0)
        #expect(runtime.nextReadyAtTick == 4)

        runtime.markActed(atTick: 4)
        #expect(runtime.actionCount == 1)
        #expect(runtime.nextReadyAtTick == 8)

        runtime.markActed(atTick: 8)
        #expect(runtime.actionCount == 2)
        #expect(runtime.nextReadyAtTick == 12)
    }

    // MARK: - Effect storage

    @Test func setEffectsReplacesEntireArray() {
        let combatant = makeCombatant()
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.setEffects([
            ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0)
        ])
        #expect(runtime.activeEffects.count == 2)
    }

    @Test func removeEffectsFiltersByPredicate() {
        let combatant = makeCombatant()
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.setEffects([
            ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0),
            ActiveEffect(id: 3, effect: .shield(.block, 5, 6), remainingTicks: 6)
        ])
        runtime.removeEffects { $0.effect.isDecayingDoT }
        #expect(runtime.activeEffects.count == 1)
        #expect(runtime.activeEffects.first?.effect.keyword == .block)
    }

    // MARK: - Identity passthrough

    @Test func identityPassthrough() {
        let combatant = makeCombatant(id: "alice", role: .hero, maxHealth: 12, toughness: 3)
        let runtime = CombatantRuntime(combatant: combatant)
        #expect(runtime.id == "alice")
        #expect(runtime.name == "Alice")
        #expect(runtime.role == .hero)
        #expect(runtime.maxHealth == 15)
    }
}

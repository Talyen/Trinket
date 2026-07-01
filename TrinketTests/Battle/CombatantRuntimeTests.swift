import XCTest
@testable import Trinket

final class CombatantRuntimeTests: XCTestCase {
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

    func testInitialHealthAccountsForToughness() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 5)
        let runtime = CombatantRuntime(combatant: combatant)
        XCTAssertEqual(runtime.currentHealth, 15)
        XCTAssertEqual(runtime.maxHealth, 15)
    }

    func testInitialHealthUsesProvidedOverride() {
        let combatant = makeCombatant(maxHealth: 20, toughness: 0)
        let runtime = CombatantRuntime(combatant: combatant, initialHealth: 7)
        XCTAssertEqual(runtime.currentHealth, 7)
    }

    func testInitialActiveEffectsAreStored() {
        let combatant = makeCombatant()
        let initial = [ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)]
        let runtime = CombatantRuntime(combatant: combatant, initialActiveEffects: initial)
        XCTAssertEqual(runtime.activeEffects, initial)
    }

    func testActionSpeedAppliesAgilityModifier() {
        let combatant = makeCombatant(actionIntervalTicks: 10, agility: 25)
        let runtime = CombatantRuntime(combatant: combatant)
        // intervalModifier = -agility / 5 = -5 → effectiveInterval = max(1, 10-5) = 5
        XCTAssertEqual(runtime.actionSpeed.effectiveInterval, 5)
    }

    func testNextReadyAtTickDefaultsToEffectiveInterval() {
        let combatant = makeCombatant(actionIntervalTicks: 3)
        let runtime = CombatantRuntime(combatant: combatant)
        XCTAssertEqual(runtime.nextReadyAtTick, 3)
    }

    // MARK: - Role defaults

    func testDefaultActionSpeedUsesRoleBaselineWhenNoOverride() {
        let hero = makeCombatant(role: .hero, actionIntervalTicks: nil)
        let pet = makeCombatant(role: .pet, actionIntervalTicks: nil)
        let enemy = makeCombatant(role: .enemy, actionIntervalTicks: nil)

        // Baseline intervals from BattleState: hero 2, pet 2, enemy 6
        XCTAssertEqual(CombatantRuntime(combatant: hero).actionSpeed.effectiveInterval, 2)
        XCTAssertEqual(CombatantRuntime(combatant: pet).actionSpeed.effectiveInterval, 2)
        XCTAssertEqual(CombatantRuntime(combatant: enemy).actionSpeed.effectiveInterval, 6)
    }

    // MARK: - isReady

    func testIsReadyRequiresAliveAndOnOrAfterReadyTick() {
        let combatant = makeCombatant(actionIntervalTicks: 4)
        var runtime = CombatantRuntime(combatant: combatant)
        XCTAssertFalse(runtime.isReady(atTick: 0))
        XCTAssertFalse(runtime.isReady(atTick: 3))
        XCTAssertTrue(runtime.isReady(atTick: 4))
        XCTAssertTrue(runtime.isReady(atTick: 100))
    }

    func testIsReadyReturnsFalseForDefeatedCombatant() {
        let combatant = makeCombatant(actionIntervalTicks: 4)
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.takeRawDamage(99)
        XCTAssertFalse(runtime.isReady(atTick: 100))
    }

    // MARK: - takeRawDamage

    func testTakeRawDamageSubtractsAndClampsAtZero() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let lost = runtime.takeRawDamage(3)
        XCTAssertEqual(lost, 3)
        XCTAssertEqual(runtime.currentHealth, 7)
    }

    func testTakeRawDamageOverkillReturnsActualAmount() {
        let combatant = makeCombatant(maxHealth: 5, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let lost = runtime.takeRawDamage(100)
        XCTAssertEqual(lost, 5)
        XCTAssertEqual(runtime.currentHealth, 0)
        XCTAssertFalse(runtime.isAlive)
    }

    // MARK: - heal

    func testHealRestoresUpToMax() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        _ = runtime.takeRawDamage(8)
        let restored = runtime.heal(5)
        XCTAssertEqual(restored, 5)
        XCTAssertEqual(runtime.currentHealth, 7)
    }

    func testHealCapsAtMaxHealth() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        _ = runtime.takeRawDamage(5)
        let restored = runtime.heal(100)
        XCTAssertEqual(restored, 5)
        XCTAssertEqual(runtime.currentHealth, 10)
    }

    func testHealIncludesWisdomBonus() {
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
        XCTAssertEqual(restored, 5)
        XCTAssertEqual(runtime.currentHealth, 10)
    }

    func testHealAtFullHealthReturnsZero() {
        let combatant = makeCombatant(maxHealth: 10, toughness: 0)
        var runtime = CombatantRuntime(combatant: combatant)
        let restored = runtime.heal(5)
        XCTAssertEqual(restored, 0)
        XCTAssertEqual(runtime.currentHealth, 10)
    }

    // MARK: - markActed

    func testMarkActedAdvancesScheduleAndIncrementsCount() {
        let combatant = makeCombatant(actionIntervalTicks: 4)
        var runtime = CombatantRuntime(combatant: combatant)
        XCTAssertEqual(runtime.actionCount, 0)
        XCTAssertEqual(runtime.nextReadyAtTick, 4)

        runtime.markActed(atTick: 4)
        XCTAssertEqual(runtime.actionCount, 1)
        XCTAssertEqual(runtime.nextReadyAtTick, 8)

        runtime.markActed(atTick: 8)
        XCTAssertEqual(runtime.actionCount, 2)
        XCTAssertEqual(runtime.nextReadyAtTick, 12)
    }

    // MARK: - Effect storage

    func testSetEffectsReplacesEntireArray() {
        let combatant = makeCombatant()
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.setEffects([
            ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0)
        ])
        XCTAssertEqual(runtime.activeEffects.count, 2)
    }

    func testRemoveEffectsFiltersByPredicate() {
        let combatant = makeCombatant()
        var runtime = CombatantRuntime(combatant: combatant)
        runtime.setEffects([
            ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0),
            ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0),
            ActiveEffect(id: 3, effect: .shield(.block, 5, 6), remainingTicks: 6)
        ])
        runtime.removeEffects { $0.effect.isDecayingDoT }
        XCTAssertEqual(runtime.activeEffects.count, 1)
        XCTAssertTrue(runtime.activeEffects.first?.effect.isDodge == false)
    }

    // MARK: - Identity passthrough

    func testIdentityPassthrough() {
        let combatant = makeCombatant(id: "alice", role: .hero, maxHealth: 12, toughness: 3)
        let runtime = CombatantRuntime(combatant: combatant)
        XCTAssertEqual(runtime.id, "alice")
        XCTAssertEqual(runtime.name, "Alice")
        XCTAssertEqual(runtime.role, .hero)
        XCTAssertEqual(runtime.maxHealth, 15)
    }
}

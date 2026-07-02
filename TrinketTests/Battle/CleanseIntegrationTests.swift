import XCTest
@testable import Trinket

/// Integration tests for cleanse abilities through full battle ticks.
final class CleanseIntegrationTests: XCTestCase {
    func testCleanseAllRemovesAllEffects() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [.slash, .cleanse, .smite]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0)
            ]
        )

        BattleTestFixtures.advanceTicks(6, on: &battle)

        XCTAssertTrue(
            battle.activeHeroEffects.allSatisfy {
                if case .cleanse(nil, _) = $0.effect { return true }
                return false
            }
        )
    }

    /// Locks in the existing behavior: a `cleanse(.keyword, duration)` entry
    /// removes matching effects on its first tick and then itself remains
    /// (continuing to tick down its `remainingTicks`).
    func testCleanseSpecificKeywordRemovesMatchingEffectsOnFirstTick() {
        let cleansePoison = Ability(
            id: "cleanse-poison",
            name: "Cleanse Poison",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison, 3)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [cleansePoison]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        let step = battle.advanceOneStep()

        XCTAssertTrue(step.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
        XCTAssertFalse(battle.hasHeroEffect { if case .poison = $0 { return true }; return false })
        XCTAssertTrue(battle.hasHeroEffect { if case .burn = $0 { return true }; return false })
    }

    /// Locks in the existing behavior: a `cleanse(nil, duration)` ability use
    /// removes every debuff (`isRemovableDebuff`) but leaves defensive
    /// effects like shields in place.
    func testCleanseAllRemovesAllDebuffsButLeavesShields() {
        let cleanseAll = Ability(
            id: "cleanse-all",
            name: "Cleanse All",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse all.",
            effects: [.cleanse(nil, 0)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [cleanseAll]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 5, 6), remainingTicks: 6)
            ]
        )

        _ = battle.advanceOneStep()
        let step = battle.advanceOneStep()

        XCTAssertTrue(step.events.contains { $0.effectKind == .cleanseApplied })
        XCTAssertFalse(battle.hasHeroEffect { if case .poison = $0 { return true }; return false })
        XCTAssertFalse(battle.hasHeroEffect { if case .burn = $0 { return true }; return false })
        XCTAssertTrue(battle.hasHeroEffect { if case .shield = $0 { return true }; return false })
    }

    /// Locks in the existing behavior: a `cleanse` with `durationTicks > 0`
    /// keeps ticking down for that many ticks after removing its targets.
    func testCleanseContinuesToTickAfterRemovingEffects() {
        let cleansePoison = Ability(
            id: "cleanse-poison-3",
            name: "Cleanse Poison",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison, 3)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [cleansePoison]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        let cleanseEffects = battle.activeHeroEffects.filter {
            if case .cleanse(.poison, _) = $0.effect { return true }
            return false
        }
        XCTAssertFalse(cleanseEffects.isEmpty)
    }
}

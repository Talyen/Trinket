import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class BattleLogReducerTests: XCTestCase {
    func testNoDamageNoEffectsFallsBackToShortForm() {
        let line = BattleLogReducer.lineForAction(
            actorName: "Hero",
            abilityName: "Block",
            dealt: 0,
            damageKeyword: .physical,
            targetName: "Enemy",
            appliedEffectSummaries: []
        )
        XCTAssertEqual(line, "Hero uses Block.")
    }

    func testDamageOnlyShowsDamageForm() {
        let line = BattleLogReducer.lineForAction(
            actorName: "Hero",
            abilityName: "Slash",
            dealt: 3,
            damageKeyword: .physical,
            targetName: "Enemy",
            appliedEffectSummaries: []
        )
        XCTAssertEqual(line, "Hero uses Slash for 3 Physical damage to Enemy.")
    }

    func testEffectsOnlyShowsOnForm() {
        let line = BattleLogReducer.lineForAction(
            actorName: "Hero",
            abilityName: "Smite",
            dealt: 0,
            damageKeyword: .holy,
            targetName: "Hero",
            appliedEffectSummaries: ["restore 3 Health"]
        )
        XCTAssertEqual(line, "Hero uses Smite on Hero and restore 3 Health.")
    }

    func testDamageAndEffectsCombines() {
        let line = BattleLogReducer.lineForAction(
            actorName: "Hero",
            abilityName: "Fireball",
            dealt: 3,
            damageKeyword: .burn,
            targetName: "Enemy",
            appliedEffectSummaries: ["applies Burning"]
        )
        XCTAssertEqual(line, "Hero uses Fireball for 3 Burn damage to Enemy and applies Burning.")
    }

    func testMultipleEffectsJoinedByComma() {
        let line = BattleLogReducer.lineForAction(
            actorName: "Hero",
            abilityName: "Heat Wave",
            dealt: 0,
            damageKeyword: .burn,
            targetName: "Enemy",
            appliedEffectSummaries: ["applies Burning", "gain Block"]
        )
        XCTAssertEqual(line, "Hero uses Heat Wave on Enemy and applies Burning, gain Block.")
    }

    func testEntriesReduceMilestonesStatusAndAbilityEvents() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, abilities: [])
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)

        let events: [ActionEvent] = [
            ActionEvent(
                id: 1,
                kind: .milestone,
                actorName: "",
                abilityName: "",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 0,
                keyword: .physical,
                milestone: .battleStarted
            ),
            ActionEvent(
                id: 2,
                kind: .ability,
                actorName: "Hero",
                abilityName: "Slash",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 3,
                keyword: .physical
            ),
            ActionEvent(
                id: 3,
                kind: .status,
                actorName: "Burn",
                abilityName: "Burn",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 2,
                keyword: .burn
            ),
            ActionEvent(
                id: 4,
                kind: .milestone,
                actorName: "",
                abilityName: "",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 0,
                keyword: .physical,
                milestone: .enemyDefeated
            )
        ]

        let entries = BattleLogReducer.entries(from: events, matchup: matchup)
        XCTAssertEqual(entries.map(\.text), [
            "Hero and Pet face Enemy.",
            "Hero uses Slash for 3 Physical damage to Enemy.",
            "Enemy takes 2 Burn damage.",
            "Enemy is defeated."
        ])
    }

    func testIncrementalEntriesMatchFullRebuild() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, abilities: [])
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)

        let events: [ActionEvent] = [
            ActionEvent(
                id: 1,
                kind: .milestone,
                actorName: "",
                abilityName: "",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 0,
                keyword: .physical,
                milestone: .battleStarted
            ),
            ActionEvent(
                id: 2,
                kind: .ability,
                actorName: "Hero",
                abilityName: "Slash",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 3,
                keyword: .physical
            ),
            ActionEvent(
                id: 3,
                kind: .status,
                actorName: "Burn",
                abilityName: "Burn",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 2,
                keyword: .burn
            )
        ]

        let full = BattleLogReducer.entries(from: events, matchup: matchup)
        let firstBatch = BattleLogReducer.entries(from: [events[0]], startingAt: 0, matchup: matchup)
        let secondBatch = BattleLogReducer.entries(from: events, startingAt: 1, matchup: matchup)
        XCTAssertEqual(firstBatch + secondBatch, full)
    }

    func testLogProjectionIncrementalSyncMatchesFullReduce() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 20, abilities: [])
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)
        let events = [
            ActionEvent(
                id: 1,
                kind: .milestone,
                actorName: "",
                abilityName: "",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 0,
                keyword: .physical,
                milestone: .battleStarted
            ),
            ActionEvent(
                id: 2,
                kind: .ability,
                actorName: "Hero",
                abilityName: "Slash",
                targetID: enemy.id,
                targetName: enemy.name,
                amount: 3,
                keyword: .physical
            )
        ]

        var projection = BattleLogProjection()
        projection.sync(events: [events[0]], matchup: matchup)
        projection.sync(events: events, matchup: matchup)

        XCTAssertEqual(projection.entries, BattleLogProjection.entries(from: events, matchup: matchup))
    }

    func testDeathsDoorTriggeredLogLine() {
        let event = ActionEvent(
            id: 1,
            kind: .effect,
            effectKind: .deathsDoorTriggered,
            actorName: "Hero",
            abilityName: "Death's Door",
            targetID: "hero",
            targetName: "Hero",
            amount: 0,
            keyword: .deathsDoor
        )
        XCTAssertEqual(BattleLogReducer.line(for: event, matchup: sampleMatchup()), "Hero is on Death's Door.")
    }

    func testDeathsDoorExpiredLogLine() {
        let event = ActionEvent(
            id: 1,
            kind: .effect,
            effectKind: .deathsDoorExpired,
            actorName: "Hero",
            abilityName: "Death's Door",
            targetID: "hero",
            targetName: "Hero",
            amount: 0,
            keyword: .deathsDoor
        )
        XCTAssertEqual(BattleLogReducer.line(for: event, matchup: sampleMatchup()), "Hero's Death's Door fades.")
    }

    private func sampleMatchup() -> BattleMatchup {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, abilities: [])
        return BattleMatchup(hero: hero, pet: pet, enemy: enemy)
    }
}

import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleLogReducerTests {
    @Test func lineForActionFormatsRepresentativeCases() throws {
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Block",
                dealt: 0,
                damageKeyword: .physical,
                targetName: "Enemy",
                appliedEffectSummaries: []
            ) == "Hero uses Block."
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Slash",
                dealt: 3,
                damageKeyword: .physical,
                targetName: "Enemy",
                appliedEffectSummaries: []
            ) == "Hero uses Slash for 3 Physical damage to Enemy."
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Smite",
                dealt: 0,
                damageKeyword: .holy,
                targetName: "Hero",
                appliedEffectSummaries: ["restore 3 Health"]
            ) == "Hero uses Smite on Hero and restore 3 Health."
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Fireball",
                dealt: 3,
                damageKeyword: .burn,
                targetName: "Enemy",
                appliedEffectSummaries: ["applies Burning"]
            ) == "Hero uses Fireball for 3 Burn damage to Enemy and applies Burning."
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Heat Wave",
                dealt: 0,
                damageKeyword: .burn,
                targetName: "Enemy",
                appliedEffectSummaries: ["applies Burning", "gain Block"]
            ) == "Hero uses Heat Wave on Enemy and applies Burning, gain Block."
        )
    }

    @Test func entriesReduceAndSyncIncrementally() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, abilities: [])
        let matchup = BattleMatchup(hero: hero, companion: companion, enemy: enemy)

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
        try #expect(entries.map(\.text) == [
            "Hero and Companion face Enemy.",
            "Hero uses Slash for 3 Physical damage to Enemy.",
            "Enemy takes 2 Burn damage.",
            "Enemy is defeated."
        ])

        let firstBatch = BattleLogReducer.entries(from: [events[0]], startingAt: 0, matchup: matchup)
        let secondBatch = BattleLogReducer.entries(from: Array(events.prefix(3)), startingAt: 1, matchup: matchup)
        try #expect(firstBatch + secondBatch == BattleLogReducer.entries(from: Array(events.prefix(3)), matchup: matchup))

        var projection = BattleLogProjection()
        projection.sync(events: [events[0]], matchup: matchup)
        projection.sync(events: Array(events.prefix(2)), matchup: matchup)
        try #expect(
            projection.entries
                == BattleLogProjection.entries(from: Array(events.prefix(2)), matchup: matchup)
        )
    }

    @Test func deathsDoorLogLines() throws {
        let triggered = ActionEvent(
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
        try #expect(BattleLogReducer.line(for: triggered, matchup: sampleMatchup()) == "Hero is on Death's Door.")

        let expired = ActionEvent(
            id: 2,
            kind: .effect,
            effectKind: .deathsDoorExpired,
            actorName: "Hero",
            abilityName: "Death's Door",
            targetID: "hero",
            targetName: "Hero",
            amount: 0,
            keyword: .deathsDoor
        )
        try #expect(BattleLogReducer.line(for: expired, matchup: sampleMatchup()) == "Hero's Death's Door fades.")
    }

    private func sampleMatchup() -> BattleMatchup {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, abilities: [])
        return BattleMatchup(hero: hero, companion: companion, enemy: enemy)
    }
}

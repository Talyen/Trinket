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

    @Test func entriesReduceMilestonesStatusAndAbilityEvents() throws {
        let events = sampleEvents(includeDefeat: true)
        let entries = BattleLogReducer.entries(from: events)
        try #expect(entries.map(\.text) == [
            "Hero and Companion face Enemy.",
            "Hero uses Slash for 3 Physical damage to Enemy.",
            "Enemy takes 2 Burn damage.",
            "Enemy is defeated.",
        ])
    }

    @Test func incrementalEntriesAndProjectionMatchFullReduce() throws {
        let events = sampleEvents(includeDefeat: false)

        let full = BattleLogReducer.entries(from: events)
        let firstBatch = BattleLogReducer.entries(from: [events[0]], startingAt: 0)
        let secondBatch = BattleLogReducer.entries(from: events, startingAt: 1)
        try #expect(firstBatch + secondBatch == full)

        var projection = BattleLogProjection()
        projection.sync(events: [events[0]])
        projection.sync(events: events)
        try #expect(projection.entries == BattleLogProjection.entries(from: events))
    }

    @Test func battleStartLogUsesNamesCapturedByEvent() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, abilities: [])
        let replacementEnemy = Combatant(
            id: "replacement-enemy",
            name: "Replacement Enemy",
            role: .enemy,
            maxHealth: 10,
            abilities: []
        )
        var battle = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tracksLog: false,
            dealOpeningHand: false
        )

        battle.roster.enemy = CombatantRuntime(combatant: replacementEnemy)
        battle.syncLog()

        try #expect(battle.log.first?.text == "Hero and Companion face Enemy.")
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
        try #expect(BattleLogReducer.line(for: triggered) == "Hero is on Death's Door.")

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
        try #expect(BattleLogReducer.line(for: expired) == "Hero's Death's Door fades.")
    }

    private func sampleEvents(includeDefeat: Bool) -> [ActionEvent] {
        let enemyID = "enemy"
        var events: [ActionEvent] = [
            ActionEvent(
                id: 1,
                kind: .milestone,
                actorName: "",
                abilityName: "",
                targetID: enemyID,
                targetName: "Enemy",
                amount: 0,
                keyword: .physical,
                milestone: .battleStarted(heroName: "Hero", companionName: "Companion")
            ),
            ActionEvent(
                id: 2,
                kind: .ability,
                actorName: "Hero",
                abilityName: "Slash",
                targetID: enemyID,
                targetName: "Enemy",
                amount: 3,
                keyword: .physical
            ),
            ActionEvent(
                id: 3,
                kind: .status,
                actorName: "Burn",
                abilityName: "Burn",
                targetID: enemyID,
                targetName: "Enemy",
                amount: 2,
                keyword: .burn
            ),
        ]
        if includeDefeat {
            events.append(
                ActionEvent(
                    id: 4,
                    kind: .milestone,
                    actorName: "",
                    abilityName: "",
                    targetID: enemyID,
                    targetName: "Enemy",
                    amount: 0,
                    keyword: .physical,
                    milestone: .enemyDefeated
                )
            )
        }
        return events
    }
}

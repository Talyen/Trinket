import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleLogReducerTests {
    @Test func `line for action formats representative cases`() throws {
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Block",
                dealt: 0,
                damageKeyword: .physical,
                targetName: "Enemy",
                appliedEffectSummaries: [],
            ) == "Hero uses Block.",
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Slash",
                dealt: 3,
                damageKeyword: .physical,
                targetName: "Enemy",
                appliedEffectSummaries: [],
            ) == "Hero uses Slash for 3 Physical damage to Enemy.",
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Smite",
                dealt: 0,
                damageKeyword: .holy,
                targetName: "Hero",
                appliedEffectSummaries: ["restore 3 Health"],
            ) == "Hero uses Smite and restore 3 Health.",
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Fireball",
                dealt: 3,
                damageKeyword: .burn,
                targetName: "Enemy",
                appliedEffectSummaries: ["applies Burning"],
            ) == "Hero uses Fireball for 3 Burn damage to Enemy and applies Burning.",
        )
        try #expect(
            BattleLogReducer.lineForAction(
                actorName: "Hero",
                abilityName: "Heat Wave",
                dealt: 0,
                damageKeyword: .burn,
                targetName: "Enemy",
                appliedEffectSummaries: ["applies Burning", "gain Block"],
            ) == "Hero uses Heat Wave and applies Burning, gain Block.",
        )
    }

    @Test func `entries reduce milestones status and ability events`() throws {
        let events = sampleEvents(includeDefeat: true)
        let entries = BattleLogReducer.entries(from: events)
        try #expect(entries.map(\.text) == [
            "Hero and Companion face Enemy.",
            "Hero uses Slash for 3 Physical damage to Enemy.",
            "Enemy takes 2 Burn damage.",
            "Enemy is defeated.",
        ])
    }

    @Test func `incremental entries and projection match full reduce`() throws {
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

    @Test func `battle start log uses names captured by event`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 10)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 10)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 10)
        let replacementEnemy = CombatantFixtures.combatant(id: "replacement-enemy", role: .enemy, maxHealth: 10)
        var battle = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            tracksLog: false,
            dealOpeningHand: false,
        )

        battle.roster.enemy = CombatantRuntime(combatant: replacementEnemy)
        battle.syncLog()

        try #expect(battle.log.first?.text == "Hero and Companion face Enemy.")
    }

    @Test func `deaths door log lines`() throws {
        let triggered = ActionEvent(
            id: 1,
            kind: .effect,
            effectKind: .deathsDoorTriggered,
            actorName: "Hero",
            abilityName: "Death's Door",
            targetID: "hero",
            targetName: "Hero",
            amount: 0,
            keyword: .deathsDoor,
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
            keyword: .deathsDoor,
        )
        try #expect(BattleLogReducer.line(for: expired) == "Hero's Death's Door fades.")
    }

    @Test func `control trigger log lines`() {
        let stunned = ActionEvent(
            id: 1,
            kind: .effect,
            effectKind: .controlTriggered,
            actorName: "Hero",
            abilityName: "Stunned",
            targetID: "enemy",
            targetName: "Enemy",
            amount: 0,
            keyword: .stun,
        )
        #expect(BattleLogReducer.line(for: stunned) == "Enemy is Stunned.")

        let frozen = ActionEvent(
            id: 2,
            kind: .effect,
            effectKind: .controlTriggered,
            actorName: "Hero",
            abilityName: "Frozen",
            targetID: "enemy",
            targetName: "Enemy",
            amount: 0,
            keyword: .freeze,
        )
        #expect(BattleLogReducer.line(for: frozen) == "Enemy is Frozen.")
    }

    @Test func `passive talent attribution log lines`() {
        let blockEvent = ActionEvent(
            id: 1,
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: "Knight",
            abilityName: "Oathbound",
            targetID: "hero",
            targetName: "Knight",
            amount: 2,
            keyword: .holy,
        )
        #expect(BattleLogReducer.line(for: blockEvent) == "Knight gains 2 Block (Oathbound).")

        let healEvent = ActionEvent(
            id: 2,
            kind: .effect,
            effectKind: .instantHeal,
            actorName: "Warlock",
            abilityName: "Bloodfire",
            targetID: "hero",
            targetName: "Warlock",
            amount: 2,
            keyword: .burn,
        )
        #expect(BattleLogReducer.line(for: healEvent) == "Warlock restores 2 Health (Bloodfire).")

        let thornsEvent = ActionEvent(
            id: 3,
            kind: .effect,
            effectKind: .thornsTriggered,
            actorName: "Shield Scarab",
            abilityName: "Spiked Shell",
            targetID: "enemy",
            targetName: "Goblin",
            amount: 3,
            keyword: .physical,
        )
        #expect(BattleLogReducer.line(for: thornsEvent) == "Shield Scarab deals 3 Physical damage to Goblin (Spiked Shell).")

        let cleanseEvent = ActionEvent(
            id: 4,
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: "Library Owl",
            abilityName: "Purifying Wisdom",
            targetID: "hero",
            targetName: "Hero",
            amount: 0,
            keyword: .poison,
        )
        #expect(BattleLogReducer.line(for: cleanseEvent) == "Hero Cleanses Poison (Purifying Wisdom).")
    }

    @Test func `Heal logs its actual ally recipient instead of the selected enemy`() {
        var battle = makeSupportBattle()
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 10 }
        let events = BattleTurnEngine.performAction(
            ability: .heal, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.roster.companion.currentHealth == 16)
        #expect(battle.roster.enemy.currentHealth == 100)
        let lines = BattleLogReducer.entries(from: events).map(\.text)
        #expect(lines.contains("Companion restores 6 Health (Heal)."))
        #expect(lines.contains("Hero uses Heal and restore 6 Health."))
        #expect(!lines.contains { $0.contains("Heal on Enemy") })
    }

    @Test func `support summary leaves Purge recipient to its committed effect line`() {
        var battle = makeSupportBattle()
        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)
        let ability = Ability(id: "purge", name: "Purge", tier: .skill, effects: [.purge(.block)])
        let events = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.enemy.activeEffects) == 0)
        let lines = BattleLogReducer.entries(from: events).map(\.text)
        #expect(lines.contains("Enemy's Block is Purged (Purge)."))
        #expect(!lines.contains { $0.contains("uses Purge on") })
    }

    @Test(arguments: [9, 11, 12], [false, true])
    func `Mana Potion logs only Mana actually restored`(initialMana: Int, automatic: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 12),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroMana: initialMana,
        )
        battle.appliesFightPacing = false
        let events: [ActionEvent] = if automatic {
            battle.withAutomaticPlay { context in
                BattleTurnEngine.performAction(
                    ability: .manaPotion, actor: context.hero, abilityTarget: context.enemy, context: &context,
                )
            }
        } else {
            BattleTurnEngine.performAction(
                ability: .manaPotion, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
            )
        }
        #expect(battle.roster.hero.currentMana == 12)
        let restored = 12 - initialMana
        let lines = BattleLogReducer.entries(from: events).map(\.text)
        #expect(lines == [restored > 0
                ? "Hero uses Mana Potion and restore \(restored) Mana."
                : "Hero uses Mana Potion."])
    }

    @Test(arguments: [false, true])
    func `direct Gold and Mana gains remain in the action summary without duplicate lines`(automatic: Bool) {
        var battle = makeSupportBattle()
        let ability = Ability(
            id: "supplies", name: "Supplies", tier: .skill,
            effects: [.resourceGain(.gold, 3), .resourceGain(.mana, 3)],
        )
        let events: [ActionEvent] = if automatic {
            battle.withAutomaticPlay { context in
                BattleTurnEngine.performAction(
                    ability: ability, actor: context.hero, abilityTarget: context.enemy, context: &context,
                )
            }
        } else {
            BattleTurnEngine.performAction(
                ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
            )
        }
        #expect(battle.gold == 3)
        #expect(battle.roster.hero.currentMana == 3)
        let gainEvents = events.filter { $0.effectKind == .resourceGain }
        #expect(gainEvents.count == 2)
        #expect(gainEvents.allSatisfy { BattleLogReducer.line(for: $0) == nil })
        let lines = BattleLogReducer.entries(from: events).map(\.text)
        #expect(lines.count == 1)
        #expect(lines.first?.contains("gain 3 Gold") == true)
        #expect(lines.first?.contains("restore 3 Mana") == true)
    }

    private func makeSupportBattle() -> BattleState {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 5),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroMana: 0,
        )
        battle.appliesFightPacing = false
        return battle
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
                milestone: .battleStarted(heroName: "Hero", companionName: "Companion"),
            ),
            ActionEvent(
                id: 2,
                kind: .ability,
                actorName: "Hero",
                abilityName: "Slash",
                targetID: enemyID,
                targetName: "Enemy",
                amount: 3,
                keyword: .physical,
            ),
            ActionEvent(
                id: 3,
                kind: .status,
                actorName: "Burn",
                abilityName: "Burn",
                targetID: enemyID,
                targetName: "Enemy",
                amount: 2,
                keyword: .burn,
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
                    milestone: .enemyDefeated,
                ),
            )
        }
        return events
    }
}

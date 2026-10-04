import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleLogProjectionTests {
    @Test(arguments: [
        ("Block", 0, Keyword.physical, [String](), "Hero uses Block."),
        ("Slash", 3, .physical, [], "Hero uses Slash for 3 Physical damage to Enemy."),
        ("Smite", 0, .holy, ["restore 3 Health"], "Hero uses Smite and restore 3 Health."),
        ("Fireball", 3, .burn, ["applies Burning"], "Hero uses Fireball for 3 Burn damage to Enemy and applies Burning."),
        ("Heat Wave", 0, .burn, ["applies Burning", "gain Block"], "Hero uses Heat Wave and applies Burning, gain Block."),
    ])
    func `action summaries retain damage and effect wording`(
        name: String, amount: Int, keyword: Keyword, effects: [String], expected: String,
    ) {
        let event = ActionEvent(
            id: 1, kind: .ability, actorName: "Hero", abilityName: name,
            targetID: "enemy", targetName: "Enemy", amount: amount, keyword: keyword,
            appliedEffectSummaries: effects,
        )
        #expect(BattleLogProjection.line(for: event) == expected)
    }

    @Test func `entries reduce milestones status and ability events`() throws {
        let events = sampleEvents()
        let entries = BattleLogProjection.entries(from: events)
        try #expect(entries.map(\.text) == [
            "Hero and Companion face Enemy.",
            "Hero uses Slash for 3 Physical damage to Enemy.",
            "Enemy takes 2 Burn damage.",
            "Enemy is defeated.",
        ])
    }

    @Test func `interleaved action packets survive split updates and history resets`() {
        func event(_ kind: ActionEvent.Kind, action: Int, amount: Int, keyword: Keyword = .physical) -> ActionEvent {
            ActionEvent(
                id: action, actionID: action, kind: kind, actorID: "hero", actorName: "Hero",
                abilityID: "strike", abilityName: "Strike", targetID: "enemy", targetName: "Enemy",
                amount: amount, keyword: keyword,
            )
        }
        // Nested casts can use the same actor and ability while the outer action is unfinished.
        let events = [
            event(.abilityDamage, action: 1, amount: 2),
            event(.abilityDamage, action: 2, amount: 7),
            event(.ability, action: 2, amount: 7),
            event(.abilityDamage, action: 1, amount: 3),
            event(.abilityDamage, action: 1, amount: 4, keyword: .poison),
            event(.ability, action: 1, amount: 9),
        ]
        let expected = [
            "Hero uses Strike for 7 Physical damage to Enemy.",
            "Hero uses Strike for 5 Physical damage to Enemy and 4 Poison damage to Enemy.",
        ]
        var projection = BattleLogProjection()
        for count in 1 ... events.count {
            let prefix = Array(events.prefix(count))
            projection.sync(events: prefix)
            #expect(projection.entries == BattleLogProjection.entries(from: prefix))
        }
        #expect(projection.entries.map(\.text) == expected)
        #expect(projection.entries.map(\.id) == [2, 5])
        projection.sync(events: Array(events.prefix(1)))
        #expect(projection.entries.isEmpty)
        projection.sync(events: events)
        #expect(projection.entries.map(\.text) == expected)
        projection.rebuildFromScratch(events: Array(events.suffix(1)))
        #expect(projection.entries.map(\.text) == ["Hero uses Strike for 9 Physical damage to Enemy."])
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
        try #expect(BattleLogProjection.line(for: triggered) == "Hero is on Death's Door.")

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
        try #expect(BattleLogProjection.line(for: expired) == "Hero's Death's Door fades.")
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
        #expect(BattleLogProjection.line(for: stunned) == "Enemy is Stunned.")

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
        #expect(BattleLogProjection.line(for: frozen) == "Enemy is Frozen.")
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
        #expect(BattleLogProjection.line(for: blockEvent) == "Knight gains 2 Block (Oathbound).")

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
        #expect(BattleLogProjection.line(for: healEvent) == "Warlock restores 2 Health (Bloodfire).")

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
        #expect(BattleLogProjection.line(for: thornsEvent) == "Shield Scarab deals 3 Physical damage to Goblin (Spiked Shell).")

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
        #expect(BattleLogProjection.line(for: cleanseEvent) == "Hero Cleanses Poison (Purifying Wisdom).")
    }

    @Test func `Heal logs its actual ally recipient instead of the selected enemy`() {
        var battle = makeSupportBattle()
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 10 }
        let events = BattleTurnEngine.performAction(
            ability: .heal, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.roster.companion.currentHealth == 16)
        #expect(battle.roster.enemy.currentHealth == 100)
        let lines = BattleLogProjection.entries(from: events).map(\.text)
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
        let lines = BattleLogProjection.entries(from: events).map(\.text)
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
        let lines = BattleLogProjection.entries(from: events).map(\.text)
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
        #expect(gainEvents.allSatisfy { BattleLogProjection.line(for: $0) == nil })
        let lines = BattleLogProjection.entries(from: events).map(\.text)
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

    private func sampleEvents() -> [ActionEvent] {
        [
            ActionEvent(
                id: 1, kind: .milestone, actorName: "", abilityName: "",
                targetID: "enemy", targetName: "Enemy", amount: 0, keyword: .physical,
                milestone: .battleStarted(heroName: "Hero", companionName: "Companion"),
            ),
            ActionEvent(
                id: 2, kind: .ability, actorName: "Hero", abilityName: "Slash",
                targetID: "enemy", targetName: "Enemy", amount: 3, keyword: .physical,
            ),
            ActionEvent(
                id: 3, kind: .status, actorName: "Burn", abilityName: "Burn",
                targetID: "enemy", targetName: "Enemy", amount: 2, keyword: .burn,
            ),
            ActionEvent(
                id: 4, kind: .milestone, actorName: "", abilityName: "",
                targetID: "enemy", targetName: "Enemy", amount: 0, keyword: .physical, milestone: .enemyDefeated,
            ),
        ]
    }
}

import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleLogProjectionTests {
    @Test func `interleaved action packets survive split updates and history resets`() {
        func event(
            _ kind: ActionEvent.Kind,
            action: Int,
            amount: Int,
            keyword: Keyword = .physical,
            abilityID: String = "strike",
            abilityName: String = "Strike",
        ) -> ActionEvent {
            ActionEvent(
                id: action, actionID: action, kind: kind, actorID: "hero", actorName: "Hero",
                abilityID: abilityID, abilityName: abilityName, targetID: "enemy", targetName: "Enemy",
                amount: amount, keyword: keyword,
            )
        }
        // Nested casts can use the same actor and ability while the outer action is unfinished.
        let events = [
            event(.abilityDamage, action: 1, amount: 2),
            event(.abilityDamage, action: 1, amount: 3, abilityID: "", abilityName: "Everkeen"),
            event(.abilityDamage, action: 2, amount: 7),
            event(.ability, action: 2, amount: 7),
            event(.abilityDamage, action: 1, amount: 3),
            event(.abilityDamage, action: 1, amount: 4, keyword: .poison),
            event(.ability, action: 1, amount: 9),
        ]
        let expected = [
            "Hero deals 3 Physical damage to Enemy (Everkeen).",
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
        #expect(projection.entries.map(\.id) == [1, 3, 6])
        projection.sync(events: Array(events.prefix(1)))
        #expect(projection.entries.isEmpty)
        projection.sync(events: events)
        #expect(projection.entries.map(\.text) == expected)
        projection.rebuildFromScratch(events: Array(events.suffix(1)))
        #expect(projection.entries.map(\.text) == ["Hero uses Strike for 9 Physical damage to Enemy."])
    }

    @Test func `saturated damage and Health cost totals remain readable`() {
        let packets = [("enemy", Int.max), ("enemy", 1), ("hero", Int.max), ("hero", 1)]
        var events = packets.enumerated().map { id, packet in
            ActionEvent(
                id: id, actionID: 1, kind: .abilityDamage, actorID: "hero", actorName: "Hero",
                abilityID: "strike", abilityName: "Strike", targetID: packet.0,
                targetName: packet.0 == "hero" ? "Hero" : "Enemy",
                amount: packet.1, keyword: .physical,
            )
        }
        events.append(ActionEvent(
            id: 4, actionID: 1, kind: .ability, actorID: "hero", actorName: "Hero",
            abilityID: "strike", abilityName: "Strike", targetID: "enemy", targetName: "Enemy",
            amount: Int.max, keyword: .physical,
        ))
        #expect(BattleLogProjection.entries(from: events).map(\.text) == [
            "Hero uses Strike for \(Int.max) Physical damage to Enemy and loses \(Int.max) Health.",
        ])
    }

    @Test func `Heal logs its actual ally recipient instead of the selected enemy`() {
        var battle = makeSupportBattle()
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 10 }
        let events = battle.performTestAction(.heal)
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
        let events = battle.performTestAction(ability)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.enemy.activeEffects) == 0)
        let lines = BattleLogProjection.entries(from: events).map(\.text)
        #expect(lines.contains("Enemy's Block is Purged (Purge)."))
        #expect(!lines.contains { $0.contains("uses Purge on") })
    }

    @Test(arguments: [9, 11, 12])
    func `Mana Potion logs only Mana actually restored`(initialMana: Int) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 12),
            heroMana: initialMana, appliesFightPacing: false,
        )
        let events = battle.performTestAction(.manaPotion)
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
        let ability = Ability(id: "supplies", name: "Supplies", tier: .skill, effects: [.resourceGain(.gold, 3), .resourceGain(.mana, 3)])
        let events: [ActionEvent] = if automatic {
            battle.withAutomaticPlay { context in
                context.performTestAction(ability)
            }
        } else {
            battle.performTestAction(ability)
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
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 5),
            heroMana: 0, appliesFightPacing: false,
        )
    }

    @Test func `blood offering logs its health cost separately from enemy damage`() throws {
        var battle = makeActionDamageLogBattle()
        let before = battle.health(of: battle.hero)
        let events = battle.performTestAction(.bloodOffering)
        #expect(before - battle.health(of: battle.hero) == 2)
        let summary = try #require(events.last { $0.kind == .ability })
        let entries = BattleLogProjection.entries(from: events)
        let line = try #require(entries.first { $0.id == events.firstIndex(of: summary) })
        #expect(line.text.contains("1 Bleed damage to Enemy"))
        #expect(line.text.contains("loses 2 Health"))
        #expect(!line.text.contains("3 Bleed damage to Enemy"))
        var projection = BattleLogProjection()
        projection.sync(events: Array(events.dropLast()))
        projection.sync(events: events)
        #expect(projection.entries == entries)
    }

    @Test func `bloodthorn logs both damage types`() throws {
        var battle = makeActionDamageLogBattle()
        let events = battle.performTestAction(.bloodthorn)
        let summary = try #require(events.last { $0.kind == .ability })
        let line = try #require(BattleLogProjection.entries(from: events).first { $0.id == events.firstIndex(of: summary) })
        #expect(line.text.contains("2 Bleed damage to Enemy"))
        #expect(line.text.contains("1 Poison damage to Enemy"))
        #expect(!line.text.contains("4 Bleed damage"))
    }

    private func makeActionDamageLogBattle() -> BattleState {
        let profile = CombatModifierProfile.withTriggers { $0.criticalChanceBonus = -1 }
        return BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.bloodOffering, .bloodthorn], heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
    }
}

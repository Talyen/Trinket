import Testing
import TrinketCore
@testable import BattleEngine

@Suite("BattleCommandResultTests")
struct BattleCommandResultTests {
    @Test func `empty command result has empty collections`() {
        let empty = BattleCommandResult.empty
        #expect(empty.events.isEmpty)
        #expect(empty.playedCards.isEmpty)
        #expect(empty.actions.isEmpty)
        #expect(empty.combatantChanges.isEmpty)
    }

    @Test func `command result default memberwise initializer`() {
        let result = BattleCommandResult()
        #expect(result == BattleCommandResult.empty)
    }

    @Test func `combatant snapshot and change round trip`() {
        let snapshotBefore = BattleCombatantSnapshot(
            id: "hero",
            health: 100,
            maxHealth: 100,
            mana: 20,
            maxMana: 20,
            activeEffects: [],
        )
        let snapshotAfter = BattleCombatantSnapshot(
            id: "hero",
            health: 80,
            maxHealth: 100,
            mana: 15,
            maxMana: 20,
            activeEffects: [],
        )
        let change = BattleCombatantChange(
            eventID: 42,
            before: snapshotBefore,
            after: snapshotAfter,
        )

        #expect(change.eventID == 42)
        #expect(change.before == snapshotBefore)
        #expect(change.after == snapshotAfter)
        #expect(change.before.health == 100)
        #expect(change.after.health == 80)
    }

    @Test func `resolved damage and action initializers`() {
        let damage = BattleResolvedDamage(
            targetID: "enemy",
            keyword: .physical,
            impact: .landed(blocked: 0, healthLost: 15),
            isCritical: true,
        )
        let action = BattleResolvedAction(
            id: 1,
            actorID: "hero",
            abilityID: "slash",
            cardID: 10,
            isAttack: true,
            eventIDs: [1, 2],
            damage: [damage],
            startedAfterEventID: 0,
        )

        #expect(action.id == 1)
        #expect(action.damage.count == 1)
        #expect(action.damage.first?.targetID == "enemy")
        #expect(action.damage.first?.isCritical == true)
    }

    @Test func `command output records nested actions and card association cleanly`() {
        let output = BattleCommandOutput(recordActions: true)
        let card = BattleCard(id: 7, ability: .slash, owner: .hero)
        output.beginCard(card)

        output.beginAction(id: 1, actorID: "hero", abilityID: "slash", isAttack: true, afterEventID: 0)
        let event = ActionEvent(
            id: 1,
            actionID: 1,
            kind: .abilityDamage,
            actorID: "hero",
            actorName: "Hero",
            abilityID: "slash",
            abilityName: "Slash",
            targetID: "enemy",
            targetName: "Enemy",
            amount: 10,
            keyword: .physical,
        )
        output.append(event)
        output.recordDamage(BattleResolvedDamage(
            targetID: "enemy", keyword: .physical, impact: .landed(blocked: 0, healthLost: 10), isCritical: false,
        ))
        output.endAction()
        output.endCard()

        let result = output.result
        #expect(result.playedCards.map(\.id) == [7])
        #expect(result.events.map(\.id) == [1])
        #expect(result.actions.count == 1)
        #expect(result.actions.first?.cardID == 7)
        #expect(result.actions.first?.damage.count == 1)
    }
}

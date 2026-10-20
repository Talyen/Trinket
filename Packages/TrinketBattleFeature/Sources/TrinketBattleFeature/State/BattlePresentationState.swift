import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport

struct BattleCombatantPresentation: Equatable {
    let combatant: Combatant
    var health: Int
    var maxHealth: Int
    var mana: Int
    var maxMana: Int
    var borderAccentKeyword: Keyword?
}

struct BattlePresentationSnapshot: Equatable {
    let configurationID: UUID
    let hero: BattleCombatantPresentation
    let companion: BattleCombatantPresentation
    let enemy: BattleCombatantPresentation
    var hand: [BattleCard]
    let playableCardIDs: Set<Int>
    let isBattleOver: Bool

    init(configurationID: UUID, state: borrowing BattleState, acceptsCommands: Bool = true) {
        self.configurationID = configurationID
        let heroEffects = state.activeEffects(of: state.hero)
        let companionEffects = state.activeEffects(of: state.companion)
        hero = Self.combatant(
            state.hero,
            effects: heroEffects,
            in: state,
        )
        companion = Self.combatant(
            state.companion,
            effects: companionEffects,
            in: state,
        )
        enemy = Self.combatant(
            state.enemy,
            effects: state.activeEffects(of: state.enemy),
            in: state,
        )
        hand = state.hand.cards
        var playableIDs = Set<Int>()
        if acceptsCommands {
            for card in hand where state.isCardPlayable(card) {
                playableIDs.insert(card.id)
            }
        }
        playableCardIDs = playableIDs
        isBattleOver = state.isBattleOver
    }

    private static func combatant(
        _ combatant: Combatant,
        effects: [ActiveEffect],
        in state: borrowing BattleState,
    ) -> BattleCombatantPresentation {
        BattleCombatantPresentation(
            combatant: combatant,
            health: state.health(of: combatant),
            maxHealth: state.maxHealth(of: combatant),
            mana: state.mana(of: combatant),
            maxMana: state.maxMana(of: combatant),
            borderAccentKeyword: CombatantBorderAccent.keyword(
                from: effects,
                controlAccentRequiresPendingSkip: combatant.role != .enemy,
            ),
        )
    }
}

@MainActor
@Observable
final class BattlePresentationState {
    let cardPlayback = BattleCardPlaybackState()
    private(set) var configurationID: UUID?
    private(set) var hero: BattleCombatantPresentation?
    private(set) var companion: BattleCombatantPresentation?
    private(set) var enemy: BattleCombatantPresentation?
    private(set) var hand: [BattleCard] = []
    private(set) var playableCardIDs: Set<Int> = []
    private(set) var isBattleOver = false

    func consumeFinishingCard(id: Int) -> Bool {
        guard let index = hand.firstIndex(where: { $0.id == id }) else { return false }
        hand.remove(at: index)
        playableCardIDs.remove(id)
        return true
    }

    @ObservationIgnored private var fieldEventIDs: [String: [AnyKeyPath: Int]] = [:]

    func install(_ snapshot: BattlePresentationSnapshot, includeCombatants: Bool = true) {
        if configurationID != snapshot.configurationID {
            configurationID = snapshot.configurationID
        }
        if includeCombatants {
            fieldEventIDs.removeAll()
        }
        if includeCombatants, hero != snapshot.hero {
            hero = snapshot.hero
        }
        if includeCombatants, companion != snapshot.companion {
            companion = snapshot.companion
        }
        if includeCombatants, enemy != snapshot.enemy {
            enemy = snapshot.enemy
        }
        if hand != snapshot.hand {
            hand = snapshot.hand
        }
        if playableCardIDs != snapshot.playableCardIDs {
            playableCardIDs = snapshot.playableCardIDs
        }
        if isBattleOver != snapshot.isBattleOver {
            isBattleOver = snapshot.isBattleOver
        }
    }
}

extension BattlePresentationState {
    func apply(_ changes: [BattleCombatantChange]) {
        for change in changes {
            if let current = hero, current.combatant.id == change.after.id {
                hero = applying(change, to: current)
            } else if let current = companion, current.combatant.id == change.after.id {
                companion = applying(change, to: current)
            } else if let current = enemy, current.combatant.id == change.after.id {
                enemy = applying(change, to: current)
            }
        }
    }

    private func applying(_ change: BattleCombatantChange, to current: BattleCombatantPresentation) -> BattleCombatantPresentation {
        var result = current
        let before = project(change.before, combatant: current.combatant)
        let after = project(change.after, combatant: current.combatant)
        update(\.health, before: before, after: after, eventID: change.eventID, result: &result)
        update(\.maxHealth, before: before, after: after, eventID: change.eventID, result: &result)
        update(\.mana, before: before, after: after, eventID: change.eventID, result: &result)
        update(\.maxMana, before: before, after: after, eventID: change.eventID, result: &result)
        update(\.borderAccentKeyword, before: before, after: after, eventID: change.eventID, result: &result)
        return result
    }

    private func update(
        _ keyPath: WritableKeyPath<BattleCombatantPresentation, some Equatable>,
        before: BattleCombatantPresentation, after: BattleCombatantPresentation,
        eventID: Int, result: inout BattleCombatantPresentation,
    ) {
        // Nested actions can present after their parent. Older facts must not undo a later change.
        guard before[keyPath: keyPath] != after[keyPath: keyPath],
              eventID >= (fieldEventIDs[result.combatant.id]?[keyPath] ?? 0) else { return }
        result[keyPath: keyPath] = after[keyPath: keyPath]
        fieldEventIDs[result.combatant.id, default: [:]][keyPath] = eventID
    }

    private func project(_ snapshot: BattleCombatantSnapshot, combatant: Combatant) -> BattleCombatantPresentation {
        BattleCombatantPresentation(
            combatant: combatant, health: snapshot.health, maxHealth: snapshot.maxHealth,
            mana: snapshot.mana, maxMana: snapshot.maxMana,
            borderAccentKeyword: CombatantBorderAccent.keyword(
                from: snapshot.activeEffects, controlAccentRequiresPendingSkip: combatant.role != .enemy,
            ),
        )
    }
}

extension BattleState {
    borrowing func battlePresentationSnapshot(
        configurationID: UUID,
    ) -> BattlePresentationSnapshot {
        BattlePresentationSnapshot(
            configurationID: configurationID,
            state: self,
        )
    }
}

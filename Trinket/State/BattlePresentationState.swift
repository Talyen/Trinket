import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore

struct BattleCombatantPresentation: Equatable {
    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    /// Keyword for the single status border pulse, or `nil` for the neutral stroke.
    let borderAccentKeyword: Keyword?
}

struct BattlePresentationSnapshot: Equatable {
    let configurationID: UUID
    let hero: BattleCombatantPresentation
    let companion: BattleCombatantPresentation
    let enemy: BattleCombatantPresentation
    let hand: [BattleCard]
    /// Card IDs that may be cast with the current mana / phase. Stored on the
    /// projection so the hand lane does not observe live `BattleSession.state`.
    let playableCardIDs: Set<Int>
    let isBattleOver: Bool

    init(configurationID: UUID, state: BattleState) {
        self.configurationID = configurationID
        hero = Self.combatant(state.hero, in: state)
        companion = Self.combatant(state.companion, in: state)
        enemy = Self.combatant(state.enemy, in: state)
        hand = state.hand.cards
        playableCardIDs = Set(hand.filter { state.isCardPlayable($0) }.map(\.id))
        isBattleOver = state.isBattleOver
    }

    private static func combatant(
        _ combatant: Combatant,
        in state: BattleState
    ) -> BattleCombatantPresentation {
        BattleCombatantPresentation(
            combatant: combatant,
            health: state.health(of: combatant),
            maxHealth: state.maxHealth(of: combatant),
            mana: state.mana(of: combatant),
            maxMana: state.maxMana(of: combatant),
            borderAccentKeyword: CombatantBorderAccent.keyword(
                from: state.activeEffects(of: combatant)
            )
        )
    }
}

/// UI-facing projections are deliberately separate from the authoritative battle
/// value. SwiftUI observes only these small lanes instead of every simulation/log
/// mutation invalidating readers of the complete `BattleState`.
@MainActor
@Observable
final class BattlePresentationState {
    private(set) var configurationID: UUID?
    private(set) var hero: BattleCombatantPresentation?
    private(set) var companion: BattleCombatantPresentation?
    private(set) var enemy: BattleCombatantPresentation?
    private(set) var hand: [BattleCard] = []
    private(set) var playableCardIDs: Set<Int> = []
    private(set) var isBattleOver = false

    var isReady: Bool {
        configurationID != nil && hero != nil && companion != nil && enemy != nil
    }

    func install(_ snapshot: BattlePresentationSnapshot) {
        if configurationID != snapshot.configurationID {
            configurationID = snapshot.configurationID
        }
        if hero != snapshot.hero {
            hero = snapshot.hero
        }
        if companion != snapshot.companion {
            companion = snapshot.companion
        }
        if enemy != snapshot.enemy {
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

    func clear() {
        configurationID = nil
        hero = nil
        companion = nil
        enemy = nil
        hand = []
        playableCardIDs = []
        isBattleOver = false
    }
}

import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport

struct BattleCombatantPresentation: Equatable {
    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    /// Keyword for the single status border pulse, or `nil` for the neutral stroke.
    let borderAccentKeyword: Keyword?
    /// Persistent buff aura (e.g. Shadowstep shimmer), independent of border accent.
    let buffAuraKind: CombatantBuffAuraKind?
}

struct BattlePresentationSnapshot: Equatable {
    let configurationID: UUID
    let hero: BattleCombatantPresentation
    let companion: BattleCombatantPresentation
    let enemy: BattleCombatantPresentation
    let hand: [BattleCard]
    /// Card IDs that may be cast with the current mana / phase. Stored on the
    /// projection so the hand lane does not observe the live simulation store.
    let playableCardIDs: Set<Int>
    /// Party owners with an unconsumed Stun/Freeze action skip, mapped to that keyword.
    /// Independent of border accent so Death's Door does not hide hand control FX.
    /// Post-skip linger does not appear here — cards stay playable during linger.
    let ownerControlSkipKeywords: [BattleParticipant: Keyword]
    let isBattleOver: Bool

    init(configurationID: UUID, state: borrowing BattleState) {
        self.configurationID = configurationID
        let heroEffects = state.activeEffects(of: state.hero)
        let companionEffects = state.activeEffects(of: state.companion)
        hero = Self.combatant(state.hero, effects: heroEffects, in: state)
        companion = Self.combatant(state.companion, effects: companionEffects, in: state)
        enemy = Self.combatant(state.enemy, effects: state.activeEffects(of: state.enemy), in: state)
        hand = state.hand.cards
        playableCardIDs = Set(hand.filter { state.isCardPlayable($0) }.map(\.id))
        ownerControlSkipKeywords = Self.ownerControlSkipKeywords(
            heroEffects: heroEffects,
            companionEffects: companionEffects
        )
        isBattleOver = state.isBattleOver
    }

    private static func combatant(
        _ combatant: Combatant,
        effects: [ActiveEffect],
        in state: borrowing BattleState
    ) -> BattleCombatantPresentation {
        BattleCombatantPresentation(
            combatant: combatant,
            health: state.health(of: combatant),
            maxHealth: state.maxHealth(of: combatant),
            mana: state.mana(of: combatant),
            maxMana: state.maxMana(of: combatant),
            borderAccentKeyword: CombatantBorderAccent.keyword(
                from: effects,
                controlAccentRequiresPendingSkip: combatant.role != .enemy
            ),
            buffAuraKind: CombatantBuffAura.kind(from: effects)
        )
    }

    private static func ownerControlSkipKeywords(
        heroEffects: [ActiveEffect],
        companionEffects: [ActiveEffect]
    ) -> [BattleParticipant: Keyword] {
        var keywords: [BattleParticipant: Keyword] = [:]
        if let control = heroEffects.first(where: \.isAwaitingActionSkip) {
            keywords[.hero] = control.keyword
        }
        if let control = companionEffects.first(where: \.isAwaitingActionSkip) {
            keywords[.companion] = control.keyword
        }
        return keywords
    }
}

/// UI-facing projections are deliberately separate from the authoritative battle
/// value. SwiftUI observes only these small lanes instead of every simulation/log
/// mutation invalidating readers of the complete engine value.
@MainActor
@Observable
final class BattlePresentationState {
    private(set) var configurationID: UUID?
    private(set) var hero: BattleCombatantPresentation?
    private(set) var companion: BattleCombatantPresentation?
    private(set) var enemy: BattleCombatantPresentation?
    private(set) var hand: [BattleCard] = []
    private(set) var playableCardIDs: Set<Int> = []
    private(set) var ownerControlSkipKeywords: [BattleParticipant: Keyword] = [:]
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
        if ownerControlSkipKeywords != snapshot.ownerControlSkipKeywords {
            ownerControlSkipKeywords = snapshot.ownerControlSkipKeywords
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
        ownerControlSkipKeywords = [:]
        isBattleOver = false
    }
}

extension BattleState {
    borrowing func battlePresentationSnapshot(configurationID: UUID) -> BattlePresentationSnapshot {
        BattlePresentationSnapshot(configurationID: configurationID, state: self)
    }
}

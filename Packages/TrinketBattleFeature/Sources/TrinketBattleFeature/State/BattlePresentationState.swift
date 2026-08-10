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

    init(configurationID: UUID, state: BattleState) {
        self.configurationID = configurationID
        hero = Self.combatant(state.hero, in: state)
        companion = Self.combatant(state.companion, in: state)
        enemy = Self.combatant(state.enemy, in: state)
        hand = state.hand.cards
        playableCardIDs = Set(hand.filter { state.isCardPlayable($0) }.map(\.id))
        ownerControlSkipKeywords = Self.ownerControlSkipKeywords(in: state)
        isBattleOver = state.isBattleOver
    }

    private static func combatant(
        _ combatant: Combatant,
        in state: BattleState
    ) -> BattleCombatantPresentation {
        let isParty = combatant.role != .enemy
        let effects = state.activeEffects(of: combatant)
        return BattleCombatantPresentation(
            combatant: combatant,
            health: state.health(of: combatant),
            maxHealth: state.maxHealth(of: combatant),
            mana: state.mana(of: combatant),
            maxMana: state.maxMana(of: combatant),
            borderAccentKeyword: CombatantBorderAccent.keyword(
                from: effects,
                controlAccentRequiresPendingSkip: isParty
            ),
            buffAuraKind: CombatantBuffAura.kind(from: effects)
        )
    }

    private static func ownerControlSkipKeywords(
        in state: BattleState
    ) -> [BattleParticipant: Keyword] {
        var keywords: [BattleParticipant: Keyword] = [:]
        for owner in [BattleParticipant.hero, .companion] {
            let combatant = state.roster[owner].combatant
            if let control = state.activeEffects(of: combatant)
                .first(where: \.isAwaitingActionSkip) {
                keywords[owner] = control.keyword
            }
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

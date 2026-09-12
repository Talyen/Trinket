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
    let borderAccentKeyword: Keyword?
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
        playableCardIDs = acceptsCommands ? Set(hand.filter { state.isCardPlayable($0) }.map(\.id)) : []
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

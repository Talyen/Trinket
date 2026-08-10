import Observation
import SwiftUI
import TrinketContent

@MainActor
@Observable
final class BattleInteractionState {
    /// Manual hand press/drag — owned by BattleView via onCardInteractionChanged.
    var suppressCombatantTaps = false
    /// When set, the matching hand card mirrors the tap-lift rise before Auto play.
    var autoLiftCardID: Int?

    /// Blocks combatant detail taps for manual hand interaction or Auto tap-lift.
    var blocksCombatantTaps: Bool {
        suppressCombatantTaps || autoLiftCardID != nil
    }
}

struct BattleCombatantProjectionPane: View {
    enum Role {
        case hero
        case companion
        case enemy
    }

    let presentation: BattlePresentationState
    let role: Role
    let hapticsEnabled: Bool
    let onCombatantTap: (Combatant) -> Void

    private var snapshot: BattleCombatantPresentation? {
        switch role {
        case .hero:
            presentation.hero
        case .companion:
            presentation.companion
        case .enemy:
            presentation.enemy
        }
    }

    var body: some View {
        if let snapshot {
            BattleCombatantPane(
                combatant: snapshot.combatant,
                health: snapshot.health,
                maxHealth: snapshot.maxHealth,
                mana: snapshot.mana,
                maxMana: snapshot.maxMana,
                borderAccentKeyword: snapshot.borderAccentKeyword,
                buffAuraKind: snapshot.buffAuraKind,
                hapticsEnabled: hapticsEnabled,
                recoilDirection: role == .enemy ? .up : .down,
                onCombatantTap: { onCombatantTap(snapshot.combatant) }
            )
        }
    }
}

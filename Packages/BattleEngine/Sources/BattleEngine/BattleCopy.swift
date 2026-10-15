import Foundation
import TrinketCore

/// Resources remain unresolved until the player-facing surface supplies its locale.
enum BattleCopy {
    static func list(_ resources: [LocalizedStringResource]) -> LocalizedStringResource {
        resources.dropFirst().reduce(resources.first ?? L10n.duration_empty) { L10n.list_pair($0, $1) }
    }

    static func flagSummary(_ effect: Effect) -> LocalizedStringResource? {
        switch effect {
        case .nextHolyStrike: L10n.flag_holy
        case .nextStrikeDouble: L10n.flag_double
        case .playNextCardTwice: L10n.flag_twice
        case .evadeNextHit: L10n.flag_evade
        case .nextStrikeCritical: L10n.flag_critical
        case .nextStrikeLeech: L10n.flag_leech
        case let .nextStrikeDamageKeywordOverride(keyword):
            keyword == .holy ? L10n.flag_avatar : L10n.flag_keyword(keyword.nameResource)
        case .partyDamageBonus: L10n.flag_party
        case .freezeNextAttacker: L10n.flag_freeze
        default: nil
        }
    }
}

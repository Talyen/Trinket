import Foundation

public extension DamageCondition {
    func localizedClause(locale: Locale) -> LocalizedGameText {
        let resource: LocalizedStringResource = switch self {
        case .enemyBleeding: L10n.condition_enemybleeding
        case .enemyBurning: L10n.condition_enemyburning
        case .enemyNotBurning: L10n.condition_enemynotburning
        case .enemyPoisoned: L10n.condition_enemypoisoned
        case .enemyFrozen: L10n.condition_enemyfrozen
        case .enemyStunned: L10n.condition_enemystunned
        case .enemyStunnedOrFrozen: L10n.condition_enemystunnedorfrozen
        case .enemyMarked: L10n.condition_enemymarked
        case .enemyLowerHealthThanActor: L10n.condition_enemylowerhealththanactor
        case .allyBelowHalfHealth: L10n.condition_allybelowhalfhealth
        case .allyMissingHealth: L10n.condition_allymissinghealth
        case .enemyHasBuff: L10n.condition_enemyhasbuff
        case .enemyHasBlock: L10n.condition_enemyhasblock
        case .enemyFullHealth: L10n.condition_enemyfullhealth
        case .actorHasTwoBlock: L10n.condition_actorhastwoblock
        case .actorGainedGoldThisTurn: L10n.condition_actorgainedgoldthisturn
        case .firstTurn: L10n.condition_firstturn
        }
        return LocalizedGameText(resource, locale: locale)
    }
}

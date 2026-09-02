import TrinketContent
import TrinketCore

package extension DefensePoolEngine {
    static func shouldIgnoreBlock(
        keyword: Keyword?,
        sourceTriggers: CombatTraitTriggers,
        sourceActorID: String?,
        in context: BattleState?,
    ) -> Bool {
        guard let keyword else { return false }
        if keyword == .holy {
            if sourceTriggers.holyIgnoresBlock || sourceTriggers.holyIgnoresBlockAndDodge {
                return true
            }
            if let sourceActorID, let context,
               let src = context.roster.combatant(for: sourceActorID) {
                let partyUnbroken = (src.role != .enemy) && CombatTriggerEngine.livingPartyTriggers(in: context).unbrokenVow
                if sourceTriggers.unbrokenVow || partyUnbroken,
                   Self.blockPoints(in: context.roster.activeEffects(for: src.combatant)) > 0 {
                    return true
                }
            }
        }
        if keyword == .burn, sourceTriggers.burnIgnoresBlockAndMitigation {
            return true
        }
        return false
    }

    static func shouldIgnoreBlock(
        keyword: Keyword?,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Bool {
        guard let sourceActorID else { return false }
        return shouldIgnoreBlock(
            keyword: keyword,
            sourceTriggers: context.modifiers(for: sourceActorID).triggers,
            sourceActorID: sourceActorID,
            in: context,
        )
    }

    static func shouldIgnoreDodge(
        keyword: Keyword?,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Bool {
        guard let keyword, keyword == .holy, let sourceActorID else { return false }
        let srcTriggers = context.modifiers(for: sourceActorID).triggers
        if srcTriggers.holyIgnoresBlockAndDodge {
            return true
        }
        guard let src = context.roster.combatant(for: sourceActorID) else { return false }
        let partyUnbroken = (src.role != .enemy) && CombatTriggerEngine.livingPartyTriggers(in: context).unbrokenVow
        if srcTriggers.unbrokenVow || partyUnbroken,
           Self.blockPoints(in: context.roster.activeEffects(for: src.combatant)) > 0 {
            return true
        }
        return false
    }
}

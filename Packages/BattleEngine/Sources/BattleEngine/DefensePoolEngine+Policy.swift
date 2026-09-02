import TrinketContent
import TrinketCore

package extension DefensePoolEngine {
    static func shouldIgnoreBlock(
        keyword: Keyword?,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Bool {
        guard let keyword, let sourceActorID else { return false }
        let srcTriggers = context.modifiers(for: sourceActorID).triggers
        if srcTriggers.holyIgnoresBlockAndDodge, keyword == .holy {
            return true
        }
        if srcTriggers.holyIgnoresBlockAndDodge {
            return true
        }
        if srcTriggers.holyIgnoresBlock, keyword == .holy {
            return true
        }
        if keyword == .burn, srcTriggers.burnIgnoresBlockAndMitigation {
            return true
        }
        return false
    }

    static func shouldIgnoreDodge(
        keyword: Keyword?,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Bool {
        guard let keyword, let sourceActorID else { return false }
        let srcTriggers = context.modifiers(for: sourceActorID).triggers
        if srcTriggers.holyIgnoresBlockAndDodge, keyword == .holy {
            return true
        }
        return false
    }

    static func effectiveBlockPoints(
        for combatant: Combatant,
        sourceKeyword: Keyword?,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Int {
        let base = blockPoints(in: context.roster.activeEffects(for: combatant))
        guard base > 0 else { return 0 }
        if shouldIgnoreBlock(keyword: sourceKeyword, sourceActorID: sourceActorID, in: context) {
            return 0
        }
        if let sourceActorID {
            let srcTriggers = context.modifiers(for: sourceActorID).triggers
            let partyUnbroken = CombatTriggerEngine.livingPartyTriggers(in: context).unbrokenVow
            if srcTriggers.unbrokenVow || partyUnbroken, base > 0 {
                return 0
            }
        }
        return base
    }
}

package extension CombatTriggerEngine {
    static func applyDoT(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool = true,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        switch keyword {
        case .bleed:
            // swiftformat:disable:next redundantReturn - explicit return clarifies switch arm
            return DoTApplicator.applyBleed(
                potency: potency,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: dealImmediateDamage,
                suppressAffixReactions: true,
                in: &context,
            )
        default:
            // swiftformat:disable:next redundantReturn - explicit return clarifies switch arm
            return context.applyDecayingDoT(
                keyword: keyword,
                potency: potency,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: dealImmediateDamage,
                suppressAffixReactions: true,
            )
        }
    }
}

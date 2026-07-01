import Foundation

/// Builds the player-facing combat-log lines for a battle. Centralizes the
/// "Hero uses Slash for 3 Physical damage to Enemy and applies Burning."
/// formatting that used to live inline in `BattleState.performAction`.
enum BattleLogBuilder {
    /// Builds the log line emitted when an actor uses an ability.
    ///
    /// - When the ability dealt damage and/or applied any effects, the line
    ///   reads `"<actor> uses <ability> for <N> <keyword> damage to <target>"`
    ///   followed by `" and <effects>"` if any.
    /// - When the ability did neither, the line falls back to a shortened
    ///   `"<actor> uses <ability>."` to avoid empty noise in the log.
    static func lineForAction(
        actorName: String,
        abilityName: String,
        dealt: Int,
        damageKeyword: Keyword,
        targetName: String,
        appliedEffectSummaries: [String]
    ) -> String {
        let hadDamage = dealt > 0
        let hadEffects = !appliedEffectSummaries.isEmpty

        if !hadDamage && !hadEffects {
            return "\(actorName) uses \(abilityName)."
        }

        let prefix: String
        if hadDamage {
            prefix = "\(actorName) uses \(abilityName) for \(dealt) \(damageKeyword.rawValue) damage to \(targetName)"
        } else {
            prefix = "\(actorName) uses \(abilityName) on \(targetName)"
        }

        if hadEffects {
            return prefix + " and " + appliedEffectSummaries.joined(separator: ", ") + "."
        }
        return prefix + "."
    }
}

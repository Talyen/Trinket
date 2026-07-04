import Foundation
import TrinketCore
import TrinketContent

/// Reduces the append-only `ActionEvent` stream into player-facing combat-log
/// lines. This is the single source of truth for log formatting.
public enum BattleLogReducer {
    public static func entries(
        from events: [ActionEvent],
        matchup: BattleMatchup
    ) -> [LogEntry] {
        entries(from: events, startingAt: 0, matchup: matchup)
    }

    /// Appends log lines for events at and after `startIndex`. `LogEntry.id`
    /// matches the event's index in the full stream.
    public static func entries(
        from events: [ActionEvent],
        startingAt startIndex: Int,
        matchup: BattleMatchup
    ) -> [LogEntry] {
        guard startIndex < events.count else { return [] }
        return events[startIndex...].enumerated().compactMap { offset, event in
            let index = startIndex + offset
            guard let text = line(for: event, matchup: matchup) else { return nil }
            return LogEntry(id: index, text: text)
        }
    }

    public static func line(for event: ActionEvent, matchup: BattleMatchup) -> String? {
        switch event.kind {
        case .milestone:
            return milestoneLine(for: event, matchup: matchup)
        case .ability:
            return lineForAction(
                actorName: event.actorName,
                abilityName: event.abilityName,
                dealt: event.amount,
                damageKeyword: event.keyword,
                targetName: event.targetName,
                appliedEffectSummaries: event.appliedEffectSummaries
            )
        case .status:
            guard event.amount > 0 else { return nil }
            return "\(event.targetName) takes \(event.amount) \(event.keyword.rawValue) damage."
        case .effect:
            return effectLine(for: event)
        }
    }

    private static func effectLine(for event: ActionEvent) -> String? {
        switch event.effectKind {
        case .deathsDoorTriggered:
            return "\(event.targetName) is on Death's Door."
        case .deathsDoorExpired:
            return "\(event.targetName)'s Death's Door fades."
        default:
            return nil
        }
    }

    private static func milestoneLine(for event: ActionEvent, matchup: BattleMatchup) -> String? {
        switch event.milestone {
        case .battleStarted:
            return "\(matchup.hero.name) and \(matchup.pet.name) face \(matchup.enemy.name)."
        case .enemyDefeated:
            return "\(matchup.enemy.name) is defeated."
        case .partyDefeated:
            return "Your party has been defeated by \(matchup.enemy.name)."
        case nil:
            return nil
        }
    }

    /// Builds the log line emitted when an actor uses an ability.
    ///
    /// - When the ability dealt damage and/or applied any effects, the line
    ///   reads `"<actor> uses <ability> for <N> <keyword> damage to <target>"`
    ///   followed by `" and <effects>"` if any.
    /// - When the ability did neither, the line falls back to a shortened
    ///   `"<actor> uses <ability>."` to avoid empty noise in the log.
    public static func lineForAction(
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

import Foundation
import TrinketContent
import TrinketCore

/// Reduces the append-only `ActionEvent` stream into player-facing combat-log
/// lines. This is the single source of truth for log formatting.
public enum BattleLogReducer {
    public static func entries(
        from events: [ActionEvent]
    ) -> [LogEntry] {
        entries(from: events, startingAt: 0)
    }

    /// Appends log lines for events at and after `startIndex`. `LogEntry.id`
    /// matches the event's index in the full stream.
    public static func entries(
        from events: [ActionEvent],
        startingAt startIndex: Int
    ) -> [LogEntry] {
        guard startIndex < events.count else { return [] }
        var result: [LogEntry] = []
        result.reserveCapacity((events.count - startIndex + 1) / 2)
        for index in startIndex ..< events.count {
            let event = events[index]
            if let text = line(for: event) {
                result.append(LogEntry(id: index, text: text))
            }
        }
        return result
    }

    public static func line(for event: ActionEvent) -> String? {
        switch event.kind {
        case .milestone:
            return milestoneLine(for: event)
        case .ability:
            return lineForAction(
                actorName: event.actorName,
                abilityName: event.abilityName,
                dealt: event.amount,
                damageKeyword: event.keyword,
                targetName: event.targetName,
                appliedEffectSummaries: event.appliedEffectSummaries
            )
        case .abilityDamage:
            return nil
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
            "\(event.targetName) is on Death's Door."
        case .deathsDoorExpired:
            "\(event.targetName)'s Death's Door fades."
        case .shieldApplied where event.amount > 0 && !event.abilityName.isEmpty:
            "\(event.targetName) gains \(event.amount) Block (\(event.abilityName))."
        case .instantHeal where event.amount > 0 && !event.abilityName.isEmpty:
            "\(event.targetName) restores \(event.amount) Health (\(event.abilityName))."
        case .thornsTriggered where event.amount > 0 && !event.abilityName.isEmpty:
            "\(event.actorName) deals \(event.amount) \(event.keyword.rawValue) damage to \(event.targetName) (\(event.abilityName))."
        case .thornsTriggered where event.amount > 0:
            "\(event.actorName) reflects \(event.amount) \(event.keyword.rawValue) damage to \(event.targetName)."
        case .cleanseApplied where !event.abilityName.isEmpty:
            "\(event.targetName) Cleanses \(event.keyword.rawValue) (\(event.abilityName))."
        case .purgeApplied where !event.abilityName.isEmpty:
            "\(event.targetName)'s \(event.keyword.rawValue) is Purged (\(event.abilityName))."
        case .hemorrhageTriggered where event.amount > 0:
            "\(event.targetName) suffers \(event.amount) Bleed damage from Hemorrhage."
        default:
            nil
        }
    }

    private static func milestoneLine(for event: ActionEvent) -> String? {
        switch event.milestone {
        case let .battleStarted(heroName, companionName):
            "\(heroName) and \(companionName) face \(event.targetName)."
        case .enemyDefeated:
            "\(event.targetName) is defeated."
        case .partyDefeated:
            "Your party has been defeated by \(event.targetName)."
        case nil:
            nil
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

        if !hadDamage, !hadEffects {
            return "\(actorName) uses \(abilityName)."
        }

        let mainAction = if hadDamage {
            "\(actorName) uses \(abilityName) for \(dealt) \(damageKeyword.rawValue) damage to \(targetName)"
        } else {
            "\(actorName) uses \(abilityName) on \(targetName)"
        }

        if hadEffects {
            let effectsText = appliedEffectSummaries.joined(separator: ", ")
            return "\(mainAction) and \(effectsText)."
        }
        return "\(mainAction)."
    }
}

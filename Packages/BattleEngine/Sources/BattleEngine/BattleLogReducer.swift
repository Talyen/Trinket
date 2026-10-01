import Foundation
import TrinketContent
import TrinketCore

public enum BattleLogReducer {
    private struct ActionKey: Hashable {
        let actionID: Int
        let actorID: String
        let abilityID: String

        init(_ event: ActionEvent) {
            actionID = event.actionID
            actorID = event.actorID
            abilityID = event.abilityID
        }
    }

    private struct DamageKey: Hashable {
        let targetID: String
        let keyword: Keyword
    }

    public static func entries(
        from events: [ActionEvent],
    ) -> [LogEntry] {
        entries(from: events, startingAt: 0)
    }

    public static func entries(
        from events: [ActionEvent],
        startingAt startIndex: Int,
    ) -> [LogEntry] {
        guard startIndex < events.count else { return [] }
        // Include preceding packets when an incremental update starts at the action summary.
        let packets = Dictionary(grouping: events.filter {
            $0.kind == .abilityDamage && !$0.abilityID.isEmpty && $0.amount > 0
        }, by: ActionKey.init)
        var result: [LogEntry] = []
        result.reserveCapacity((events.count - startIndex + 1) / 2)
        for index in startIndex ..< events.count {
            let event = events[index]
            let text = if event.kind == .ability, let damage = packets[ActionKey(event)] {
                actionLine(for: event, damage: damage)
            } else {
                line(for: event)
            }
            if let text {
                result.append(LogEntry(id: index, text: text))
            }
        }
        return result
    }

    private static func actionLine(for event: ActionEvent, damage: [ActionEvent]) -> String {
        var order: [DamageKey] = []
        var amounts: [DamageKey: Int] = [:]
        var targetNames: [String: String] = [:]
        var healthCost = 0
        for packet in damage {
            if packet.targetID == event.actorID {
                healthCost += packet.amount
                continue
            }
            let key = DamageKey(targetID: packet.targetID, keyword: packet.keyword)
            if amounts[key] == nil {
                order.append(key)
            }
            amounts[key, default: 0] += packet.amount
            targetNames[packet.targetID] = packet.targetName
        }
        var text = "\(event.actorName) uses \(event.abilityName)"
        let damageClauses = order.map { key in
            "\(amounts[key, default: 0]) \(key.keyword.rawValue) damage to \(targetNames[key.targetID, default: event.targetName])"
        }
        if !damageClauses.isEmpty {
            text += " for " + damageClauses.joined(separator: " and ")
        }
        if healthCost > 0 {
            text += " and loses \(healthCost) Health"
        }
        if !event.appliedEffectSummaries.isEmpty {
            text += " and " + event.appliedEffectSummaries.joined(separator: ", ")
        }
        return text + "."
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
                appliedEffectSummaries: event.appliedEffectSummaries,
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
        case .controlTriggered:
            "\(event.targetName) is \(event.keyword.statusAlias ?? event.keyword.rawValue)."
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
        case .blockStripped where event.amount > 0:
            "\(event.actorName) removes \(event.amount) Block from \(event.targetName) (\(event.abilityName))."
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

    public static func lineForAction(
        actorName: String,
        abilityName: String,
        dealt: Int,
        damageKeyword: Keyword,
        targetName: String,
        appliedEffectSummaries: [String],
    ) -> String {
        let hadDamage = dealt > 0
        let hadEffects = !appliedEffectSummaries.isEmpty

        if !hadDamage, !hadEffects {
            return "\(actorName) uses \(abilityName)."
        }

        let mainAction = if hadDamage {
            "\(actorName) uses \(abilityName) for \(dealt) \(damageKeyword.rawValue) damage to \(targetName)"
        } else {
            "\(actorName) uses \(abilityName)"
        }

        if hadEffects {
            let effectsText = appliedEffectSummaries.joined(separator: ", ")
            return "\(mainAction) and \(effectsText)."
        }
        return "\(mainAction)."
    }
}

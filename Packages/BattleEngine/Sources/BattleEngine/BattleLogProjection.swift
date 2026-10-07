import TrinketCore

/// Projects an append-only event history. Damage packets precede their action
/// summary, including when nested actions interleave or sync splits an action.
public struct BattleLogProjection {
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

    public private(set) var entries: [LogEntry] = []
    private var loggedEventCount = 0
    private var pendingDamage: [ActionKey: [ActionEvent]] = [:]

    public init() {}

    public static func entries(from events: [ActionEvent]) -> [LogEntry] {
        var projection = Self()
        projection.sync(events: events)
        return projection.entries
    }

    public mutating func sync(events: [ActionEvent]) {
        if events.count < loggedEventCount {
            self = Self()
        }
        for index in loggedEventCount ..< events.count {
            let event = events[index]
            if event.kind == .abilityDamage, !event.abilityID.isEmpty, event.amount > 0 {
                pendingDamage[ActionKey(event), default: []].append(event)
            } else {
                let damage = event.kind == .ability ? pendingDamage.removeValue(forKey: ActionKey(event)) ?? [] : []
                if let text = Self.line(for: event, damage: damage) {
                    entries.append(LogEntry(id: index, text: text))
                }
            }
        }
        loggedEventCount = events.count
    }

    public mutating func rebuildFromScratch(events: [ActionEvent]) {
        self = Self()
        sync(events: events)
    }

    private static func actionLine(for event: ActionEvent, damage: [ActionEvent]) -> String {
        var totals: [ActionEvent] = []
        var healthCost = 0
        for packet in damage {
            if packet.targetID == event.actorID {
                healthCost = SaturatedArithmetic.saturatingAdd(healthCost, packet.amount)
            } else if let index = totals.firstIndex(where: { $0.targetID == packet.targetID && $0.keyword == packet.keyword }) {
                totals[index] = packet.with(amount: SaturatedArithmetic.saturatingAdd(totals[index].amount, packet.amount))
            } else {
                totals.append(packet)
            }
        }
        var text = "\(event.actorName) uses \(event.abilityName)"
        // Older summary-only events retain their aggregate damage fallback.
        let reported = damage.isEmpty && event.amount > 0 ? [event] : totals
        let damageClauses = reported.map {
            "\($0.amount) \($0.keyword.rawValue) damage to \($0.targetName)"
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

    static func line(for event: ActionEvent, damage: [ActionEvent] = []) -> String? {
        switch event.kind {
        case .milestone:
            return milestoneLine(for: event)
        case .ability:
            return actionLine(for: event, damage: damage)
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
}

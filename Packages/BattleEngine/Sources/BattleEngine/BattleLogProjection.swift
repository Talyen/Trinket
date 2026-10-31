import Foundation
import TrinketContent
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
                if Self.isVisible(event) {
                    entries.append(LogEntry(id: index, event: event, damage: damage))
                }
            }
        }
        loggedEventCount = events.count
    }

    private static func isVisible(_ event: ActionEvent) -> Bool {
        switch event.kind {
        case .milestone, .ability:
            true
        case .reaction:
            false
        case .abilityDamage:
            event.abilityID.isEmpty && !event.abilityName.isEmpty && event.amount > 0
        case .status:
            event.amount > 0
        case let .effect(outcome):
            switch outcome {
            case .deathsDoorTriggered, .deathsDoorExpired, .controlTriggered:
                true
            case .shieldApplied, .instantHeal, .leechHeal:
                event.amount > 0 && !event.abilityName.isEmpty
            case .thornsTriggered, .blockStripped, .damageReduced, .hemorrhageTriggered:
                event.amount > 0
            case .cleanseApplied, .purgeApplied:
                !event.abilityName.isEmpty
            default:
                false
            }
        }
    }
}

/// Retain committed facts; format only when the log is displayed, in its current locale.
public struct LogEntry: Identifiable, Equatable {
    public let id: Int
    private let event: ActionEvent
    private let damage: [ActionEvent]
    private let healthCost: Int

    init(id: Int, event: ActionEvent, damage: [ActionEvent]) {
        self.id = id
        self.event = event
        let report = event.kind == .ability ? Self.damageReport(event: event, damage: damage) : (damage: [], healthCost: 0)
        self.damage = report.damage
        healthCost = report.healthCost
    }

    public func localizedText(locale: Locale) -> String {
        let actor = ContentCopy.resource(event.actorName)
        let target = ContentCopy.resource(event.targetName)
        let ability = ContentCopy.resource(event.abilityName)
        let keyword = event.keyword.nameResource
        let resources: [LocalizedStringResource]
        switch event.kind {
        case .reaction:
            resources = []
        case .ability:
            var parts = [L10n.log_use(actor, ability)]
            parts.append(contentsOf: damage.lazy.map {
                L10n.log_damage(actor, $0.amount, $0.keyword.nameResource, ContentCopy.resource($0.targetName), ability)
            })
            if healthCost > 0 {
                parts.append(L10n.log_cost(actor, healthCost))
            }
            let effects = localizedEffects(locale: locale)
            if !effects.isEmpty {
                parts.append(L10n.log_applies(actor, BattleCopy.list(effects)))
            }
            resources = parts
        case .abilityDamage:
            resources = [L10n.log_damage(actor, event.amount, keyword, target, ability)]
        case .status:
            resources = [L10n.log_status(target, event.amount, keyword)]
        case let .milestone(milestone):
            switch milestone {
            case let .battleStarted(hero, companion):
                resources = [L10n.log_start(ContentCopy.resource(hero), ContentCopy.resource(companion), target)]
            case .enemyDefeated: resources = [L10n.log_defeated(target)]
            case .partyDefeated: resources = [L10n.log_party_defeated(target)]
            }
        case let .effect(outcome):
            switch outcome {
            case .deathsDoorTriggered: resources = [L10n.log_door(target)]
            case .deathsDoorExpired: resources = [L10n.log_door_fades(target)]
            case .controlTriggered: resources = [L10n.log_control(
                    target,
                    ContentCopy.resource(event.keyword.statusName),
                )]
            case .shieldApplied: resources = [L10n.log_block(target, event.amount, ability)]
            case .instantHeal, .leechHeal: resources = [L10n.log_heal(target, event.amount, ability)]
            case .thornsTriggered:
                resources = event.abilityName.isEmpty ? [L10n.log_reflect(actor, event.amount, keyword, target)]
                    : [L10n.log_damage(actor, event.amount, keyword, target, ability)]
            case .cleanseApplied: resources = [L10n.log_cleanse(target, keyword, ability)]
            case .purgeApplied: resources = [L10n.log_purge(target, keyword, ability)]
            case .blockStripped: resources = [L10n.log_strip(actor, event.amount, target, ability)]
            case .damageReduced: resources = [L10n.log_reduced(actor, event.amount, ability)]
            case .hemorrhageTriggered: resources = [L10n.log_hemorrhage(target, event.amount)]
            default: resources = []
            }
        }
        return resources.lazy.map { LocalizedGameText($0, locale: locale).text }.joined(separator: "\n")
    }

    private func localizedEffects(locale: Locale) -> [LocalizedStringResource] {
        event.appliedEffects.map { effect -> LocalizedStringResource in
            if case let .resourceGain(.gold, amount) = effect {
                return event.stealsGold ? L10n.log_steal_gold(amount) : L10n.log_gain_gold(amount)
            }
            return LocalizedStringResource(String.LocalizationValue(stringLiteral: EffectPresentation.localizedDescription(
                for: effect,
                locale: locale,
            ).markedText))
        }
    }

    private static func damageReport(event: ActionEvent, damage: [ActionEvent]) -> (damage: [ActionEvent], healthCost: Int) {
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
        return (damage.isEmpty && event.amount > 0 ? [event] : totals, healthCost)
    }
}

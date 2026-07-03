import Foundation

/// The view-facing shape of a battle event. Produced by
/// `ActionEventFormatter.display(for:)` so the model (`ActionEvent`) stays
/// free of presentation logic. The view picks a color, icon, and animation
/// from the `keyword` and `emphasis` fields.
struct ActionEventDisplay: Equatable {
    let emphasis: Emphasis
    let keyword: Keyword
    let text: String
    let secondaryText: String?

    enum Emphasis: Equatable {
        case damage
        case status
        case heal
        case buff
        case resourceGain
        case cleanse
        case purge
        case prevention
        case dodge
        case shieldAbsorbed
        case generic
    }
}

/// Pure functions that convert an `ActionEvent` into an `ActionEventDisplay`.
/// Centralizes the "Hero does 3 Physical damage to Enemy" formatting that
/// used to live on `ActionEvent.floatingText` so the model stays
/// presentation-free and the formatting can grow independently.
enum ActionEventFormatter {
    /// Returns the display model for `event`. Pure function.
    static func display(for event: ActionEvent) -> ActionEventDisplay {
        switch event.kind {
        case .ability:
            return amountDisplay(emphasis: .damage, event: event, prefix: "-")
        case .status:
            return ActionEventDisplay(
                emphasis: .status,
                keyword: event.keyword,
                text: "-\(event.amount) \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .effect:
            return displayForEffect(event)
        case .milestone:
            return ActionEventDisplay(
                emphasis: .generic,
                keyword: event.keyword,
                text: "",
                secondaryText: nil
            )
        }
    }

    private static func displayForEffect(_ event: ActionEvent) -> ActionEventDisplay {
        guard let effectKind = event.effectKind else {
            return ActionEventDisplay(
                emphasis: .generic,
                keyword: event.keyword,
                text: event.keyword.rawValue,
                secondaryText: nil
            )
        }
        return displayForEffectKind(effectKind, event: event)
    }

    private static func displayForEffectKind(_ effectKind: ActionEvent.EffectKind, event: ActionEvent) -> ActionEventDisplay {
        switch effectKind {
        case .instantHeal:
            return signedAmountDisplay(emphasis: .heal, event: event, prefix: "+")
        case .resourceGain:
            return signedAmountDisplay(emphasis: .resourceGain, event: event, prefix: "+")
        case .leechHeal:
            return signedAmountDisplay(emphasis: .heal, event: event, prefix: "+")
        case .shieldApplied:
            return signedAmountDisplay(emphasis: .buff, event: event, prefix: "+")
        case .mitigationApplied:
            return mitigationAppliedDisplay(for: event)
        case .shieldAbsorbed:
            return signedAmountDisplay(emphasis: .shieldAbsorbed, event: event, prefix: "-")
        case .preventionSkipped, .preventionApplied, .preventionTriggered:
            return preventionDisplay(for: effectKind, event: event)
        case .cleanseApplied:
            return cleanseDisplay(for: event)
        case .purgeApplied:
            return purgeDisplay(for: event)
        case .leechApplied:
            return leechAppliedDisplay(for: event)
        case .mitigationHalved:
            return mitigationHalvedDisplay(for: event)
        case .dodgeApplied:
            return dodgeDisplay(for: event)
        }
    }

    private static func mitigationAppliedDisplay(for event: ActionEvent) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: .buff,
            keyword: event.keyword,
            text: "+\(Int(Double(event.amount)))% \(event.keyword.rawValue)",
            secondaryText: nil
        )
    }

    private static func preventionDisplay(
        for effectKind: ActionEvent.EffectKind,
        event: ActionEvent
    ) -> ActionEventDisplay {
        switch effectKind {
        case .preventionSkipped:
            return ActionEventDisplay(
                emphasis: .prevention,
                keyword: event.keyword,
                text: event.keyword.rawValue,
                secondaryText: nil
            )
        case .preventionApplied:
            return ActionEventDisplay(
                emphasis: .prevention,
                keyword: event.keyword,
                text: "+\(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .preventionTriggered:
            return ActionEventDisplay(
                emphasis: .prevention,
                keyword: event.keyword,
                text: "\(event.keyword.statusAlias ?? event.keyword.rawValue)!",
                secondaryText: nil
            )
        default:
            return ActionEventDisplay(
                emphasis: .generic,
                keyword: event.keyword,
                text: event.keyword.rawValue,
                secondaryText: nil
            )
        }
    }

    private static func cleanseDisplay(for event: ActionEvent) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: .cleanse,
            keyword: event.keyword,
            text: "Cleanse \(event.keyword.statusAlias ?? event.keyword.rawValue)",
            secondaryText: nil
        )
    }

    private static func purgeDisplay(for event: ActionEvent) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: .purge,
            keyword: event.keyword,
            text: "Purge \(event.keyword.rawValue)",
            secondaryText: nil
        )
    }

    private static func leechAppliedDisplay(for event: ActionEvent) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: .buff,
            keyword: event.keyword,
            text: "+\(event.amount)% \(event.keyword.rawValue)",
            secondaryText: nil
        )
    }

    private static func mitigationHalvedDisplay(for event: ActionEvent) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: .buff,
            keyword: event.keyword,
            text: "Halve \(event.keyword.rawValue)",
            secondaryText: nil
        )
    }

    private static func dodgeDisplay(for event: ActionEvent) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: .dodge,
            keyword: event.keyword,
            text: "Dodge",
            secondaryText: nil
        )
    }

    private static func amountDisplay(
        emphasis: ActionEventDisplay.Emphasis,
        event: ActionEvent,
        prefix: String
    ) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: emphasis,
            keyword: event.keyword,
            text: "\(prefix)\(event.amount)",
            secondaryText: nil
        )
    }

    private static func signedAmountDisplay(
        emphasis: ActionEventDisplay.Emphasis,
        event: ActionEvent,
        prefix: String
    ) -> ActionEventDisplay {
        ActionEventDisplay(
            emphasis: emphasis,
            keyword: event.keyword,
            text: "\(prefix)\(event.amount) \(event.keyword.rawValue)",
            secondaryText: nil
        )
    }
}

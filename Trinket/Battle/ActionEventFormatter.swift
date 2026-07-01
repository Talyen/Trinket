import Foundation

/// The view-facing shape of a battle event. Produced by
/// `ActionEventFormatter.display(for:)` so the model (`ActionEvent`) stays
/// free of presentation logic. The view picks a color, icon, and animation
/// from the `keyword` and `emphasis` fields.
struct ActionEventDisplay: Equatable {
    /// Visual emphasis category. The view can use this to override the
    /// keyword-based color (e.g. shield absorption looks "less aggressive"
    /// than direct damage even when the keyword is the same).
    let emphasis: Emphasis

    /// The keyword that originated the event, retained for keyword-based
    /// styling (`Keyword.visualStyle.color` and `.symbolName`).
    let keyword: Keyword

    /// Player-facing primary text shown as floating battle chrome
    /// (e.g. `"-3"`, `"+5 Health"`, `"Stunned!"`).
    let text: String

    /// Optional secondary line shown beneath the primary text when a view
    /// wants a two-line layout. Currently `nil` for every event; reserved
    /// for future multi-line presentations.
    let secondaryText: String?

    enum Emphasis: Equatable {
        /// Direct ability damage.
        case damage
        /// Status (DoT) tick damage.
        case status
        /// Healing — instant heal, leech heal.
        case heal
        /// Buff applied — shield, mitigation, leech.
        case buff
        /// Gold (or other resource) gained.
        case resourceGain
        /// Cleanse applied.
        case cleanse
        /// Stun/freeze applied, triggered, or skipped.
        case prevention
        /// Dodge — the attacker missed.
        case dodge
        /// Damage absorbed by an active shield.
        case shieldAbsorbed
        /// Fallback for events without a more specific category.
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
            return ActionEventDisplay(
                emphasis: .damage,
                keyword: event.keyword,
                text: "-\(event.amount)",
                secondaryText: nil
            )
        case .status:
            return ActionEventDisplay(
                emphasis: .status,
                keyword: event.keyword,
                text: "-\(event.amount) \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .effect:
            return displayForEffect(event)
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
        switch effectKind {
        case .instantHeal:
            return ActionEventDisplay(
                emphasis: .heal,
                keyword: event.keyword,
                text: "+\(event.amount) \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .resourceGain:
            return ActionEventDisplay(
                emphasis: .resourceGain,
                keyword: event.keyword,
                text: "+\(event.amount) \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .leechHeal:
            return ActionEventDisplay(
                emphasis: .heal,
                keyword: event.keyword,
                text: "+\(event.amount) \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .shieldApplied:
            return ActionEventDisplay(
                emphasis: .buff,
                keyword: event.keyword,
                text: "+\(event.amount) \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .mitigationApplied:
            return ActionEventDisplay(
                emphasis: .buff,
                keyword: event.keyword,
                text: "+\(Int(Double(event.amount)))% \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .shieldAbsorbed:
            return ActionEventDisplay(
                emphasis: .shieldAbsorbed,
                keyword: event.keyword,
                text: "-\(event.amount) \(event.keyword.rawValue)",
                secondaryText: nil
            )
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
        case .cleanseApplied:
            return ActionEventDisplay(
                emphasis: .cleanse,
                keyword: event.keyword,
                text: "Cleanse \(event.keyword.rawValue)",
                secondaryText: nil
            )
        case .dodgeApplied:
            return ActionEventDisplay(
                emphasis: .dodge,
                keyword: event.keyword,
                text: "Dodge",
                secondaryText: nil
            )
        }
    }
}

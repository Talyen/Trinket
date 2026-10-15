import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleAutoToggle: View {
    let battleSession: BattleSession
    let input: BattleViewInput

    var body: some View {
        Toggle(isOn: Binding(
            get: { battleSession.isAutoBattleEnabled },
            set: { enabled in input.perform { $0.isAutoBattleEnabled = enabled } },
        )) {
            Label(
                "Auto",
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
            )
        }
        // UIStyleCheck: allow - Native Toggle button semantics provide the toolbar's standard on/off control.
        .toggleStyle(.button)
        .tint(TrinketDesign.Colors.accent)
        .accessibilityIdentifier(AccessibilityID.Battle.autoBattleToggle)
    }
}

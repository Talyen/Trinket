import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleAutoToggle: View {
    let battleSession: BattleSession

    var body: some View {
        @Bindable var observedSession = battleSession
        Toggle(isOn: $observedSession.isAutoBattleEnabled) {
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

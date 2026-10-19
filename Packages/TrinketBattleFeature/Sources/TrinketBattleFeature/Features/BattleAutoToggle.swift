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
                String(localized: L10n.ui_battleautotoggle_auto_02862),
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
            )
        }
        // UIStyleCheck: allow - Native Toggle button semantics provide the toolbar's standard on/off control.
        .toggleStyle(.button)
        .tint(TrinketDesign.Colors.accent)
        .accessibilityIdentifier(AccessibilityID.Battle.autoBattleToggle)
    }
}

struct BattleAutoPauseNotice: View {
    let playManually: () -> Void
    let retreat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            Text(L10n.ui_battleview_auto_battle_paused)
                .trinketTypography(.rowTitle)
            Text(L10n.ui_battleview_auto_battle_paused_message)
                .trinketTypography(.body)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.Battle.autoBattlePauseMessage)
            ViewThatFits(in: .horizontal) {
                HStack { actions }
                VStack(alignment: .leading) { actions }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TrinketDesign.Spacing.medium)
        .trinketSurface(.secondary)
        .padding(.horizontal, TrinketDesign.Spacing.medium)
        .padding(.vertical, TrinketDesign.Spacing.small)
    }

    @ViewBuilder
    private var actions: some View {
        Button(action: playManually) {
            Text(L10n.ui_battleview_play_manually)
        }
        .trinketPrimaryActionButton()
        .accessibilityIdentifier(AccessibilityID.Battle.autoBattlePlayManually)
        Button(role: .destructive, action: retreat) {
            Text(L10n.ui_battleview_retreat_e6e5c)
        }
        .trinketSecondaryActionButton(tint: TrinketDesign.Colors.destructive)
        .accessibilityIdentifier(AccessibilityID.Battle.retreat)
    }
}

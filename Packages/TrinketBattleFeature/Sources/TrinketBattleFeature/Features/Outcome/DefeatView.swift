import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct DefeatView: View {
    let enemyName: String
    var primaryButtonTitle: String = "Retry"
    let onPrimaryAction: () -> Bool

    var body: some View {
        BattleOutcomeShell(
            title: "Defeat",
            subtitle: "\(enemyName) has defeated your party.",
            titleAccessibilityIdentifier: "Defeat",
            content: { EmptyView() },
            primaryButtonTitle: primaryButtonTitle,
            primaryButtonAccessibilityIdentifier: "\(primaryButtonTitle) Button",
            primaryButtonTint: TrinketDesign.Colors.destructive,
            onPrimaryAction: onPrimaryAction
        )
    }
}

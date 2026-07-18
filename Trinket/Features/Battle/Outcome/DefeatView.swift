import SwiftUI
import TrinketDesignSystem

struct DefeatView: View {
    let enemyName: String
    var primaryButtonTitle: String = "Retry"
    let onPrimaryAction: () -> Void

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

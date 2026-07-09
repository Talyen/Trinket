import SwiftUI
import TrinketDesignSystem

struct DefeatView: View {
    let enemyName: String
    var infoTitle: String = "Lost Progress"
    var infoMessage: String = "Experience and rewards are lost in defeat."
    var primaryButtonTitle: String = "Battle Again"
    let onPrimaryAction: () -> Void

    var body: some View {
        BattleOutcomeShell(
            symbolName: "xmark.seal.fill",
            symbolColor: TrinketDesign.Colors.destructive,
            title: "Defeat",
            subtitle: "\(enemyName) has defeated your party.",
            titleAccessibilityIdentifier: "Defeat",
            content: {
                BattleOutcomeInfoSection(
                    title: infoTitle,
                    message: infoMessage
                )
            },
            primaryButtonTitle: primaryButtonTitle,
            primaryButtonAccessibilityIdentifier: "Battle Again Button",
            primaryButtonTint: TrinketDesign.Colors.destructive,
            onPrimaryAction: onPrimaryAction
        )
    }
}

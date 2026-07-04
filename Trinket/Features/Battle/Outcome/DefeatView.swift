import SwiftUI
import TrinketDesignSystem

struct DefeatView: View {
    let enemyName: String
    let onBattleAgain: () -> Void

    var body: some View {
        BattleOutcomeShell(
            symbolName: "xmark.seal.fill",
            symbolColor: TrinketDesign.Colors.destructive,
            title: "Defeat",
            subtitle: "\(enemyName) has defeated your party.",
            titleAccessibilityIdentifier: "Defeat",
            content: {
                BattleOutcomeInfoSection(
                    title: "Lost Progress",
                    message: "Experience and rewards are lost in defeat."
                )
            },
            primaryButtonTitle: "Battle Again",
            primaryButtonAccessibilityIdentifier: "Battle Again Button",
            primaryButtonTint: TrinketDesign.Colors.destructive,
            onPrimaryAction: onBattleAgain
        )
    }
}

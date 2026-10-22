import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleOutcomeRewardRow: View {
    let icon: GameIcon
    let tint: Color
    let text: String

    var body: some View {
        Label {
            GameLabel(text, balanced: true)
                .trinketTypography(.secondaryBody)
        } icon: {
            GameIconImage(icon)
                .foregroundStyle(tint)
        }
    }
}

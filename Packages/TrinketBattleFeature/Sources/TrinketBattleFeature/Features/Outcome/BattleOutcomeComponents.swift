import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleOutcomeRewardRow: View {
    let icon: GameIcon
    let tint: Color
    let text: String

    var body: some View {
        Label {
            Text(balanced: text)
                .trinketTypography(.secondaryBody)
        } icon: {
            GameIconImage(icon)
                .foregroundStyle(tint)
        }
    }
}

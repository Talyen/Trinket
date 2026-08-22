import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleOutcomeRewardRow: View {
    let symbolName: String
    let tint: Color
    let text: String

    var body: some View {
        Label {
            Text(balanced: text)
                .trinketTypography(.secondaryBody)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
        }
    }
}

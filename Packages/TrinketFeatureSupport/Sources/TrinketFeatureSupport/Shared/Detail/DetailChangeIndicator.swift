import SwiftUI
import TrinketDesignSystem

public struct DetailChangeIndicator: Equatable, Sendable {
    public let icon: GameIcon
    public let tint: Color
    public let accessibilityLabel: String

    public init(icon: GameIcon, tint: Color, accessibilityLabel: String) {
        self.icon = icon
        self.tint = tint
        self.accessibilityLabel = accessibilityLabel
    }
}

struct DetailChangeIndicators: View {
    let indicators: [DetailChangeIndicator]

    var body: some View {
        ForEach(Array(indicators.enumerated()), id: \.offset) { _, indicator in
            GameIconImage(indicator.icon)
                .foregroundStyle(indicator.tint)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(indicator.accessibilityLabel)
        }
    }
}

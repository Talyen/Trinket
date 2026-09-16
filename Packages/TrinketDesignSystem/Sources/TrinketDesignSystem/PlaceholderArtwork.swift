import SwiftUI
import TrinketCore

public struct PlaceholderArtwork: View {
    private let color: Color
    private let icon: GameIcon
    @ScaledMetric private var iconSize: CGFloat

    public init(
        _ style: TrinketDesign.CardPlaceholderStyle,
        iconPointSize: CGFloat = TrinketDesign.Layout.cardPlaceholderIconPointSize,
        relativeTo textStyle: Font.TextStyle = .title,
    ) {
        self.init(color: style.color, icon: style.icon, iconPointSize: iconPointSize, relativeTo: textStyle)
    }

    public init(
        _ style: Keyword.VisualStyle,
        iconPointSize: CGFloat = TrinketDesign.Layout.cardPlaceholderIconPointSize,
        relativeTo textStyle: Font.TextStyle = .title,
    ) {
        self.init(color: style.color, icon: style.icon, iconPointSize: iconPointSize, relativeTo: textStyle)
    }

    private init(
        color: Color,
        icon: GameIcon,
        iconPointSize: CGFloat,
        relativeTo textStyle: Font.TextStyle,
    ) {
        self.color = color
        self.icon = icon
        _iconSize = ScaledMetric(wrappedValue: iconPointSize, relativeTo: textStyle)
    }

    public var body: some View {
        ZStack {
            color.opacity(TrinketDesign.Opacity.placeholderWash)

            GameIconImage(icon, renderingMode: .hierarchical)
                // UIStyleCheck: allow - Game icon glyph sizing, not copy
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

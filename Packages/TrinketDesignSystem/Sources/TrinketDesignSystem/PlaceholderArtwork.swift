import SwiftUI
import TrinketCore

public struct PlaceholderArtwork: View {
    private let color: Color
    private let symbolName: String
    @ScaledMetric private var iconSize: CGFloat

    public init(_ style: TrinketDesign.CardPlaceholderStyle) {
        self.init(
            color: style.color,
            symbolName: style.symbolName,
            iconPointSize: TrinketDesign.Metrics.cardPlaceholderIconPointSize,
            relativeTo: .title,
        )
    }

    public init(
        _ style: TrinketDesign.CardPlaceholderStyle,
        iconPointSize: CGFloat,
        relativeTo textStyle: Font.TextStyle,
    ) {
        self.init(color: style.color, symbolName: style.symbolName, iconPointSize: iconPointSize, relativeTo: textStyle)
    }

    public init(_ style: Keyword.VisualStyle) {
        self.init(
            color: style.color,
            symbolName: style.symbolName,
            iconPointSize: TrinketDesign.Metrics.cardPlaceholderIconPointSize,
            relativeTo: .title,
        )
    }

    public init(
        _ style: Keyword.VisualStyle,
        iconPointSize: CGFloat,
        relativeTo textStyle: Font.TextStyle,
    ) {
        self.init(color: style.color, symbolName: style.symbolName, iconPointSize: iconPointSize, relativeTo: textStyle)
    }

    private init(
        color: Color,
        symbolName: String,
        iconPointSize: CGFloat,
        relativeTo textStyle: Font.TextStyle,
    ) {
        self.color = color
        self.symbolName = symbolName
        _iconSize = ScaledMetric(wrappedValue: iconPointSize, relativeTo: textStyle)
    }

    public var body: some View {
        ZStack {
            color.opacity(0.18)

            Image(systemName: symbolName)
                // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

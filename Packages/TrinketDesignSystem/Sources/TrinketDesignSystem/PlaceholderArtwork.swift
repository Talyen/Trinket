import SwiftUI
import TrinketCore

/// Tinted symbol fallback shown when prepared artwork is unavailable.
///
/// The single owner for card and pane artwork placeholders; sizing scales with
/// Dynamic Type so placeholders never fall behind surrounding text.
public struct PlaceholderArtwork: View {
    private let color: Color
    private let symbolName: String
    @ScaledMetric private var iconSize: CGFloat

    /// Card-scale placeholder (base 38pt, scaling with `.title`).
    public init(_ style: TrinketDesign.CardPlaceholderStyle) {
        self.init(
            color: style.color,
            symbolName: style.symbolName,
            iconPointSize: TrinketDesign.Metrics.cardPlaceholderIconPointSize,
            relativeTo: .title
        )
    }

    /// Pane-scale placeholder with an explicit icon role (combatant panes).
    public init(
        _ style: TrinketDesign.CardPlaceholderStyle,
        iconPointSize: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) {
        self.init(color: style.color, symbolName: style.symbolName, iconPointSize: iconPointSize, relativeTo: textStyle)
    }

    /// Card-scale keyword-art placeholder.
    public init(_ style: Keyword.VisualStyle) {
        self.init(
            color: style.color,
            symbolName: style.symbolName,
            iconPointSize: TrinketDesign.Metrics.cardPlaceholderIconPointSize,
            relativeTo: .title
        )
    }

    /// Large pane-scale keyword-art placeholder (talent tree headers).
    public init(
        _ style: Keyword.VisualStyle,
        iconPointSize: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) {
        self.init(color: style.color, symbolName: style.symbolName, iconPointSize: iconPointSize, relativeTo: textStyle)
    }

    private init(
        color: Color,
        symbolName: String,
        iconPointSize: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) {
        self.color = color
        self.symbolName = symbolName
        _iconSize = ScaledMetric(wrappedValue: iconPointSize, relativeTo: textStyle)
    }

    public var body: some View {
        ZStack {
            color.opacity(0.18)

            Image(systemName: symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

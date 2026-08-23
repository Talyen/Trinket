import SwiftUI
import TrinketCore
import TrinketDesignSystem

private struct ShineTextModifier: ViewModifier {
    let colors: [Color]

    func body(content: Content) -> some View {
        if colors.isEmpty {
            content
        } else {
            let band = colors + [TrinketDesign.Colors.Overlay.paper]
            let looped = band + band
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let phase = TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate)
                content
                    .foregroundStyle(
                        LinearGradient(
                            colors: looped,
                            startPoint: UnitPoint(x: phase - 1, y: 0.5),
                            endPoint: UnitPoint(x: phase + 1, y: 0.5)
                        )
                    )
                    .shadow(color: colors[0].opacity(0.62), radius: 5)
            }
        }
    }
}

/// Red stops shared by corruption text and border shines, derived from the theme's destructive token.
public enum CorruptionShine {
    public static let textColors: [Color] = [
        TrinketDesign.Colors.destructive,
        TrinketDesign.Colors.destructive.opacity(0.55),
    ]
    public static let borderColors: [Color] = [
        TrinketDesign.Colors.destructive,
    ]
}

/// Ember stops for Unique items — card borders and every affix line.
public enum UniqueShine {
    public static let textColors: [Color] = [
        TrinketDesign.Colors.warning,
        TrinketDesign.Colors.warning.opacity(0.55),
    ]
    public static let borderColors: [Color] = [
        TrinketDesign.Colors.warning,
    ]
}

private func keywordShineColors(_ keywords: Set<Keyword>) -> [Color] {
    Keyword.allCases
        .filter(keywords.contains)
        .flatMap { [$0.visualStyle.color, $0.visualStyle.secondaryColor] }
}

public extension View {
    func keywordShine(_ keywords: Set<Keyword>) -> some View {
        colorShine(keywordShineColors(keywords))
    }

    /// Animated traveling text shine through arbitrary colors.
    func colorShine(_ colors: [Color]) -> some View {
        modifier(ShineTextModifier(colors: colors))
    }

    /// Corruption-red shimmer for marked affix names.
    func corruptionShine() -> some View {
        colorShine(CorruptionShine.textColors)
    }

    /// Ember shimmer for Unique names and affixes while `isActive`.
    @ViewBuilder
    func uniqueShine(if isActive: Bool) -> some View {
        if isActive {
            colorShine(UniqueShine.textColors)
        } else {
            self
        }
    }
}

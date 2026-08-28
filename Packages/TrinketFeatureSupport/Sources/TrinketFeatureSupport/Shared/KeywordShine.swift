import SwiftUI
import TrinketCore
import TrinketDesignSystem

private struct ShineTextModifier: ViewModifier {
    let colors: [Color]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if colors.isEmpty {
            content
        } else {
            let band = colors + [TrinketDesign.Colors.Overlay.paper]
            let looped = band + band
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let phase = reduceMotion
                    ? 0
                    : TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate)
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

public enum CorruptionShine {
    public static let textColors: [Color] = [
        TrinketDesign.Colors.destructive,
        TrinketDesign.Colors.destructive.opacity(0.55),
    ]
    public static let borderColors: [Color] = [
        TrinketDesign.Colors.destructive,
    ]
}

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

    func colorShine(_ colors: [Color]) -> some View {
        modifier(ShineTextModifier(colors: colors))
    }

    func corruptionShine() -> some View {
        colorShine(CorruptionShine.textColors)
    }

    @ViewBuilder
    func uniqueShine(if isActive: Bool) -> some View {
        if isActive {
            colorShine(UniqueShine.textColors)
        } else {
            self
        }
    }
}

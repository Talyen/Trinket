import SwiftUI
import TrinketCore
import TrinketDesignSystem

private struct KeywordShineModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let keywords: Set<Keyword>

    func body(content: Content) -> some View {
        let ordered = Keyword.allCases.filter(keywords.contains)
        let colors = ordered.flatMap { [$0.visualStyle.color, $0.visualStyle.secondaryColor] }
        if colors.isEmpty {
            content
        } else {
            let band = colors + [TrinketDesign.Colors.Overlay.paper]
            let looped = band + band
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let period = TrinketMotion.Shine.keywordAffinityPeriod
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = reduceMotion
                    ? 0
                    : elapsed.truncatingRemainder(dividingBy: period) / period
                content
                    .foregroundStyle(
                        LinearGradient(
                            colors: looped,
                            startPoint: UnitPoint(x: reduceMotion ? 0 : phase - 1, y: 0.5),
                            endPoint: UnitPoint(x: reduceMotion ? 1 : phase + 1, y: 0.5)
                        )
                    )
                    .shadow(color: ordered[0].visualStyle.glowColor, radius: 5)
            }
        }
    }
}

public extension View {
    func keywordShine(_ keywords: Set<Keyword>) -> some View {
        modifier(KeywordShineModifier(keywords: keywords))
    }
}

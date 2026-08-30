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
            let base = colors.first ?? Keyword.physical.visualStyle.color
            let highlight = TrinketDesign.Colors.Overlay.paper
            let isSingle = colors.count <= 1
            let sweepColors: [Color] = isSingle
                ? [base.opacity(0.85), base, highlight, base, base.opacity(0.85)]
                : [base] + colors + colors.reversed() + [base]
            let sweepStops = seamlessShineStops(colors: sweepColors)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let phase = reduceMotion
                    ? 0
                    : TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate)
                content
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(stops: sweepStops),
                            startPoint: UnitPoint(x: -phase, y: 0.5),
                            endPoint: UnitPoint(x: 2 - phase, y: 0.5),
                        ),
                    )
            }
        }
    }
}

private func seamlessShineStops(colors: [Color]) -> [Gradient.Stop] {
    let periodSegmentCount = colors.count - 1
    return (0 ... 1).flatMap { period in
        colors.indices.map { index in
            let location = (
                Double(period) + Double(index) / Double(periodSegmentCount),
            ) / 2
            return Gradient.Stop(color: colors[index], location: location)
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

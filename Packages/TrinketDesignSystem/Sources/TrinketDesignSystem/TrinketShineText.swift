import SwiftUI

private struct ShineTextModifier: ViewModifier {
    let colors: [Color]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if colors.isEmpty {
            content
        } else {
            let sweepStops = textShineStops(colors: colors)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let phase = reduceMotion
                    ? 0
                    : context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: TrinketMotion.Shine.textLoopPeriod)
                    / TrinketMotion.Shine.textLoopPeriod
                content
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(stops: sweepStops),
                            startPoint: UnitPoint(x: 2 * phase - 2, y: 0.5),
                            endPoint: UnitPoint(x: 2 * phase + 2, y: 0.5),
                        ),
                    )
            }
        }
    }
}

private func textShineLoopColors(colors: [Color]) -> [Color] {
    var seen = Set<Color>()
    let unique = colors.filter { seen.insert($0).inserted }
    guard let first = unique.first else { return [] }
    let band = unique + [TrinketDesign.Colors.Overlay.paper]
    return band + band + [first]
}

private func textShineStops(colors: [Color]) -> [Gradient.Stop] {
    let looped = textShineLoopColors(colors: colors)
    guard looped.count > 1 else { return [] }
    let last = Double(looped.count - 1)
    return looped.enumerated().map { Gradient.Stop(color: $0.element, location: Double($0.offset) / last) }
}

public extension View {
    func trinketShineText(colors: [Color]) -> some View {
        modifier(ShineTextModifier(colors: colors))
    }
}

import SwiftUI
import TrinketCore
import TrinketDesignSystem

public struct KeywordShineBorder: View {
    public var shine: Shine
    public var cornerRadius: CGFloat = TrinketDesign.Corners.card
    public var lineWidth: CGFloat = 2
    public var isMotionActive: Bool = true

    public init(
        shine: Shine,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
        lineWidth: CGFloat = 2,
        isMotionActive: Bool = true,
    ) {
        self.shine = shine
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.isMotionActive = isMotionActive
    }

    public var body: some View {
        let colors = shine.borderColors ?? []
        Group {
            if colors.isEmpty {
                EmptyView()
            } else {
                BorderTimeline(
                    colors: colors,
                    cornerRadius: cornerRadius,
                    lineWidth: lineWidth,
                    isMotionActive: isMotionActive,
                )
            }
        }
    }
}

private struct BorderTimeline: View {
    let colors: [Color]
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let isMotionActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motionEnabled = isMotionActive && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !motionEnabled)) { context in
            let angle = motionEnabled
                ? TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate) * 360
                : 0
            KeywordShineBorderStroke(
                colors: colors,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                angle: angle,
                motionEnabled: motionEnabled,
            )
        }
        .allowsHitTesting(false)
        .animation(nil, value: isMotionActive)
    }
}

private struct KeywordShineBorderStroke: View {
    let colors: [Color]
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let angle: Double
    let motionEnabled: Bool

    var body: some View {
        let stops = gradientStops(for: colors)
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(TrinketDesign.Colors.panel, lineWidth: lineWidth)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: stops),
                        center: .center,
                        angle: .degrees(angle),
                    ),
                    lineWidth: lineWidth,
                )
        }
        .compositingGroup()
    }

    private func gradientStops(for colors: [Color]) -> [Gradient.Stop] {
        guard let base = colors.first else { return [] }
        if colors.count == 1 {
            return Shine.stops(for: base, motionEnabled: motionEnabled)
        }

        var looped = colors
        looped.append(looped[0])
        let count = looped.count - 1
        var stops: [Gradient.Stop] = []
        for i in 0 ... count {
            let loc = Double(i) / Double(count)
            stops.append(.init(color: looped[i], location: loc))
        }
        return stops
    }
}

public extension View {
    @ViewBuilder
    func shineBorder(
        _ shine: Shine,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
        lineWidth: CGFloat = 2,
        isMotionActive: Bool = true,
    ) -> some View {
        if !shine.isEmpty {
            overlay {
                KeywordShineBorder(
                    shine: shine,
                    cornerRadius: cornerRadius,
                    lineWidth: lineWidth,
                    isMotionActive: isMotionActive,
                )
            }
        } else {
            self
        }
    }
}

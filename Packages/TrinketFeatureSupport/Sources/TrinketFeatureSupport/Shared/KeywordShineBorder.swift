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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isMotionActive || colors.isEmpty)) { context in
            let angle = TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate) * 360
            KeywordShineBorderStroke(
                colors: colors,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                angle: angle,
                motionEnabled: isMotionActive,
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
        let list = colors.isEmpty ? [Keyword.physical.visualStyle.color] : colors
        let highlight = TrinketDesign.Colors.Overlay.paper

        if list.count == 1 {
            let base = list[0]
            if !motionEnabled {
                return [
                    .init(color: base, location: 0),
                    .init(color: base, location: 0.5),
                    .init(color: base, location: 1),
                ]
            }
            return [
                .init(color: base, location: 0),
                .init(color: base, location: 0.28),
                .init(color: highlight, location: 0.4),
                .init(color: base, location: 0.5),
                .init(color: base, location: 0.72),
                .init(color: base, location: 1),
            ]
        }

        var looped = list
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

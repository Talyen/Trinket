import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Reusable traveling card-border shine for keywords, Astral items, and loadout selection.
public struct KeywordShineBorder: View {
    public let keywords: [Keyword]
    public var cornerRadius: CGFloat = TrinketDesign.Corners.card
    public var lineWidth: CGFloat = 2
    public var isMotionActive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motionEnabled: Bool {
        isMotionActive && !reduceMotion
    }

    public init(
        keywords: [Keyword],
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
        lineWidth: CGFloat = 2,
        isMotionActive: Bool = true
    ) {
        self.keywords = keywords
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.isMotionActive = isMotionActive
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !motionEnabled)) { context in
            KeywordShineBorderStroke(
                keywords: keywords,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                angle: motionEnabled
                    ? TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate) * 360
                    : 0,
                motionEnabled: motionEnabled
            )
        }
        .allowsHitTesting(false)
    }
}

private struct KeywordShineBorderStroke: View {
    let keywords: [Keyword]
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let angle: Double
    let motionEnabled: Bool

    var body: some View {
        let stops = gradientStops(for: keywords)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: stops),
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: lineWidth
            )
    }

    private func gradientStops(for keywords: [Keyword]) -> [Gradient.Stop] {
        let list = keywords.isEmpty ? [Keyword.physical] : keywords
        let highlight = TrinketDesign.Colors.Overlay.paper.opacity(0.95)

        if list.count == 1 {
            let base = list[0].visualStyle.color
            if !motionEnabled {
                return [
                    .init(color: base.opacity(0.7), location: 0),
                    .init(color: base.opacity(0.85), location: 0.5),
                    .init(color: base.opacity(0.7), location: 1),
                ]
            }
            return [
                .init(color: base.opacity(0.22), location: 0),
                .init(color: base.opacity(0.65), location: 0.28),
                .init(color: highlight, location: 0.4),
                .init(color: base.opacity(0.9), location: 0.5),
                .init(color: base.opacity(0.28), location: 0.72),
                .init(color: base.opacity(0.22), location: 1),
            ]
        }

        var colors = list.map(\.visualStyle.color)
        colors.append(colors[0])
        let count = colors.count - 1
        var stops: [Gradient.Stop] = []
        for i in 0 ... count {
            let loc = Double(i) / Double(count)
            stops.append(.init(color: colors[i].opacity(0.75), location: loc))
        }
        stops.append(.init(color: highlight, location: 0.4))
        stops.sort { $0.location < $1.location }
        return stops
    }
}

public extension View {
    @ViewBuilder
    func keywordShineBorder(
        keywords: [Keyword]?,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
        lineWidth: CGFloat = 2,
        isMotionActive: Bool = true
    ) -> some View {
        if let keywords, !keywords.isEmpty {
            overlay {
                KeywordShineBorder(
                    keywords: keywords,
                    cornerRadius: cornerRadius,
                    lineWidth: lineWidth,
                    isMotionActive: isMotionActive
                )
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func keywordShineBorder(
        keyword: Keyword?,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
        lineWidth: CGFloat = 2,
        isMotionActive: Bool = true
    ) -> some View {
        if let keyword {
            keywordShineBorder(
                keywords: [keyword],
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                isMotionActive: isMotionActive
            )
        } else {
            self
        }
    }
}

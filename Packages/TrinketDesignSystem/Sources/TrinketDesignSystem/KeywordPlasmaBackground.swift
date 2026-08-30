import simd
import SwiftUI
import TrinketCore

public struct KeywordPlasmaBackground: View {
    public struct Source {
        public let keywords: [Keyword]
        public let focalPoint: UnitPoint

        public init(keywords: [Keyword], focalPoint: UnitPoint) {
            self.keywords = keywords
            self.focalPoint = focalPoint
        }
    }

    let keywords: [Keyword]
    let focalYOffset: CGFloat
    let isMotionActive: Bool
    let sources: [Source]?

    @State private var startDate = Date()

    public init(
        keywords: [Keyword],
        focalYOffset: CGFloat = 75,
        isMotionActive: Bool = true,
    ) {
        self.keywords = keywords
        self.focalYOffset = focalYOffset
        self.isMotionActive = isMotionActive
        sources = nil
    }

    public init(
        sources: [Source],
        isMotionActive: Bool = true,
    ) {
        precondition(sources.count <= 2, "KeywordPlasmaBackground supports at most 2 sources")
        keywords = []
        focalYOffset = 0
        self.isMotionActive = isMotionActive
        self.sources = Array(sources.prefix(2))
    }

    public var body: some View {
        if let sources {
            let active = sources.filter { !$0.keywords.isEmpty }
            if !active.isEmpty {
                multiSourceBody(active)
            }
        } else if !keywords.isEmpty {
            singleSourceBody
        }
    }

    private var singleSourceBody: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isMotionActive)) { timeline in
            GeometryReader { geometry in
                let time = Float(timeline.date.timeIntervalSince(startDate))
                let colors = colors(for: keywords)
                let focalCenter = CGPoint(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2 - focalYOffset,
                )
                let size = float2(Float(geometry.size.width), Float(geometry.size.height))
                let center = float2(Float(focalCenter.x), Float(focalCenter.y))

                Rectangle()
                    .fill(TrinketDesign.Colors.canvas)
                    .colorEffect(
                        ShaderLibrary.bundle(.module).shaderLiquidPlasma(
                            .float2(size.x, size.y),
                            .float(time),
                            .color(colors.primary),
                            .color(colors.secondary),
                            .float2(center.x, center.y),
                        ),
                    )
                    .blendMode(.plusLighter)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(TrinketMotion.Content.fade, value: keywords)
        .animation(nil, value: isMotionActive)
    }

    @ViewBuilder
    private func multiSourceBody(_ activeSources: [Source]) -> some View {
        if let firstSource = activeSources.first {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isMotionActive)) { timeline in
                GeometryReader { geometry in
                    let time = Float(timeline.date.timeIntervalSince(startDate))
                    let secondSource = activeSources.count == 2 ? activeSources[1] : firstSource
                    let firstColors = colors(for: firstSource.keywords)
                    let secondColors = colors(for: secondSource.keywords)
                    let size = float2(Float(geometry.size.width), Float(geometry.size.height))
                    let firstCenter = center(for: firstSource, in: geometry.size)
                    let secondCenter = center(for: secondSource, in: geometry.size)

                    Rectangle()
                        .fill(TrinketDesign.Colors.canvas)
                        .colorEffect(
                            ShaderLibrary.bundle(.module).shaderDualLiquidPlasma(
                                .float2(size.x, size.y),
                                .float(time),
                                .float(Float(activeSources.count)),
                                .color(firstColors.primary),
                                .color(firstColors.secondary),
                                .float2(firstCenter.x, firstCenter.y),
                                .color(secondColors.primary),
                                .color(secondColors.secondary),
                                .float2(secondCenter.x, secondCenter.y),
                            ),
                        )
                        .blendMode(.plusLighter)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(nil, value: isMotionActive)
        }
    }

    private func colors(for keywords: [Keyword]) -> (primary: Color, secondary: Color) {
        let primary = keywords.first?.visualStyle.color ?? TrinketDesign.Colors.accent
        let secondary = if keywords.count > 1 {
            keywords[1].visualStyle.color
        } else {
            keywords.first?.visualStyle.secondaryColor ?? primary
        }
        return (primary, secondary)
    }

    private func center(for source: Source, in size: CGSize) -> float2 {
        float2(
            Float(source.focalPoint.x * size.width),
            Float(source.focalPoint.y * size.height),
        )
    }
}

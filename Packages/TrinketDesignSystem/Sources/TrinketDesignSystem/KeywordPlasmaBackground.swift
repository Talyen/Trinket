import simd
import SwiftUI
import TrinketCore

public struct KeywordPlasmaBackground: View {
    let keywords: [Keyword]
    let focalYOffset: CGFloat
    let isMotionActive: Bool

    @State private var startDate = Date()

    public init(
        keywords: [Keyword],
        focalYOffset: CGFloat = 75,
        isMotionActive: Bool = true
    ) {
        self.keywords = keywords
        self.focalYOffset = focalYOffset
        self.isMotionActive = isMotionActive
    }

    public var body: some View {
        if keywords.isEmpty {
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isMotionActive)) { timeline in
                GeometryReader { geometry in
                    let time = Float(timeline.date.timeIntervalSince(startDate))
                    let primaryColor = keywords.first?.visualStyle.color ?? TrinketDesign.Colors.accent
                    let secondaryColor = if keywords.count > 1 {
                        keywords[1].visualStyle.color
                    } else {
                        keywords.first?.visualStyle.secondaryColor ?? primaryColor
                    }

                    let focalCenter = CGPoint(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2 - focalYOffset
                    )
                    let size = float2(Float(geometry.size.width), Float(geometry.size.height))
                    let center = float2(Float(focalCenter.x), Float(focalCenter.y))

                    Rectangle()
                        .fill(TrinketDesign.Colors.canvas)
                        .colorEffect(
                            ShaderLibrary.bundle(.module).shaderLiquidPlasma(
                                .float2(size.x, size.y),
                                .float(time),
                                .color(primaryColor),
                                .color(secondaryColor),
                                .float2(center.x, center.y)
                            )
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
    }
}

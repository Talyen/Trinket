import SwiftUI
import TrinketCore
import TrinketDesignSystem

private struct KeywordShineModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let keywords: Set<Keyword>
    @State private var shinePhase = false

    func body(content: Content) -> some View {
        let ordered = Keyword.allCases.filter(keywords.contains)
        let colors = ordered.flatMap { [$0.visualStyle.color, $0.visualStyle.secondaryColor] }
        if colors.isEmpty {
            content
        } else {
            content
                .foregroundStyle(
                    LinearGradient(
                        colors: colors + [TrinketDesign.Colors.Overlay.paper] + colors,
                        startPoint: UnitPoint(x: reduceMotion ? 0 : (shinePhase ? 1.35 : -0.35), y: 0.5),
                        endPoint: UnitPoint(x: reduceMotion ? 1 : (shinePhase ? 2.35 : 0.65), y: 0.5)
                    )
                )
                .shadow(color: ordered[0].visualStyle.glowColor, radius: 5)
                .task {
                    guard !reduceMotion else { return }
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                        shinePhase = true
                    }
                }
                .onDisappear { shinePhase = false }
        }
    }
}

public extension View {
    func keywordShine(_ keywords: Set<Keyword>) -> some View {
        modifier(KeywordShineModifier(keywords: keywords))
    }
}

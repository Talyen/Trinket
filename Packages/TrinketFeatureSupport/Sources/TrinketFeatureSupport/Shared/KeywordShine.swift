import SwiftUI
import TrinketCore

public extension View {
    func keywordShine(_ keywords: Set<Keyword>) -> some View {
        shineText(keywords.isEmpty ? .none : .keywordSet(keywords))
    }

    func colorShine(_ colors: [Color]) -> some View {
        shineText(colors.isEmpty ? .none : .colors(colors))
    }

    func corruptionShine() -> some View {
        shineText(.corruption)
    }

    @ViewBuilder
    func uniqueShine(if isActive: Bool) -> some View {
        if isActive {
            shineText(.unique)
        } else {
            self
        }
    }
}

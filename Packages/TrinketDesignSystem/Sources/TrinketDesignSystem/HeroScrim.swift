import SwiftUI

/// Full-bleed hero readability scrims — route art overlays through these roles instead of raw black/RGB.
public enum HeroScrimRole: Sendable {
    case homesteadOverview
    case homesteadDetail
    case detailHeader
    case chapter
}

public enum OnArtTextEmphasis: Sendable {
    case title
    case eyebrow
}

public enum TrinketHeroScrim {
    public static func colors(for role: HeroScrimRole) -> [Color] {
        let warm = TrinketDesign.Colors.Overlay.heroWarm
        switch role {
        case .homesteadOverview, .homesteadDetail, .chapter:
            // Keep full-bleed collection and journey heroes on the Homestead overview treatment.
            return [Color.clear, warm.opacity(0.88)]
        case .detailHeader:
            return [Color.clear, TrinketDesign.Colors.Overlay.detailHeroScrim]
        }
    }

    public static func gradient(
        for role: HeroScrimRole,
        startPoint: UnitPoint = .top,
        endPoint: UnitPoint = .bottom
    ) -> LinearGradient {
        LinearGradient(colors: colors(for: role), startPoint: startPoint, endPoint: endPoint)
    }
}

public extension View {
    /// Paper foreground + ink shadows for titles and eyebrows drawn over hero art.
    func trinketOnArtText(_ emphasis: OnArtTextEmphasis = .title) -> some View {
        modifier(OnArtTextModifier(emphasis: emphasis))
    }
}

private struct OnArtTextModifier: ViewModifier {
    let emphasis: OnArtTextEmphasis

    func body(content: Content) -> some View {
        let paper = TrinketDesign.Colors.Overlay.paper
        let ink = TrinketDesign.Colors.Overlay.ink
        switch emphasis {
        case .title:
            content
                .foregroundStyle(paper)
                .shadow(color: ink.opacity(0.95), radius: 1, y: 1)
                .shadow(color: ink.opacity(0.48), radius: 5, y: 2)
        case .eyebrow:
            content
                .foregroundStyle(paper.opacity(0.78))
                .shadow(color: ink.opacity(0.7), radius: 1, y: 1)
        }
    }
}

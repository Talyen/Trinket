import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public extension ChapterTheme {
    var tint: Color {
        switch self {
        case .forest:
            TrinketDesign.Colors.chapterForest
        case .dungeon:
            TrinketDesign.Colors.chapterDungeon
        case .desert:
            TrinketDesign.Colors.chapterDesert
        case .tundra:
            TrinketDesign.Colors.chapterTundra
        case .crimsonVale:
            TrinketDesign.Colors.keywordBleed
        case .sunAbbey:
            TrinketDesign.Colors.keywordHoly
        case .shatteredPass:
            TrinketDesign.Colors.keywordStun
        }
    }
}

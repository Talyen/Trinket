import SwiftUI
import TrinketContent
import TrinketDesignSystem

extension ChapterTheme {
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
        }
    }
}

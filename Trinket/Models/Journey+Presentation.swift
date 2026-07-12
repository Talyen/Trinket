import SwiftUI
import TrinketContent
import TrinketDesignSystem

extension ChapterTheme {
    var tint: Color {
        switch self {
        case .verdantForest:
            TrinketDesign.Colors.chapterVerdant
        }
    }
}

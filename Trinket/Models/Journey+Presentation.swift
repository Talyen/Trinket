import SwiftUI
import TrinketCore


extension ChapterTheme {
    var tint: Color {
        switch self {
        case .verdantForest:
            return Color.green
        }
    }

    var secondaryTint: Color {
        switch self {
        case .verdantForest:
            return Color.mint
        }
    }
}

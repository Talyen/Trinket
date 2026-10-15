import Foundation

enum SpiresProgress {
    static func clampedClearedFloors(highestCleared: Int, floorCount: Int) -> Int {
        min(highestCleared, floorCount)
    }

    static func floorsText(cleared: Int, total: Int) -> String {
        String(localized: L10n.ui_progress_floors(cleared, total))
    }
}

import Foundation

#if DEBUG
public extension AccessibilityID {
    enum BattleTransitionLab {
        public static let entry = "Battle Transitions Lab"
        public static let controls = "Battle Transitions Controls"
        public static let preset = "Battle Transition Preset"
        public static let replayEntry = "Replay Battle Entry"
        public static let replayDirectExit = "Replay Direct Battle Exit"
        public static let replayVictoryReturn = "Replay Victory Return"
        public static let playFullJourney = "Play Full Battle Journey"
        public static let picker = "Battle Lab Stage Picker"
        public static let enterBattle = "Enter Lab Battle"
        public static let returnToStages = "Return to Lab Stages"
        public static let showVictory = "Show Lab Victory"
        public static let lootAll = "Collect Lab Loot"
        public static let stageDetail = "Battle Lab Stage Detail"

        public static func stageRow(_ id: String) -> String {
            "Battle Lab Stage Row \(id)"
        }

        public static func stageArtwork(_ id: String) -> String {
            "Battle Lab Stage Artwork \(id)"
        }

        public static let reset = "Reset Battle Transitions"
    }
}
#endif

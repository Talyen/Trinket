import Foundation
import TrinketCore

public extension GameContent {
    static var mysteryEvents: [MysteryEvent] {
        MysteryEventPool.all
    }

    static func mysteryEvent(matching id: String) -> MysteryEvent? {
        MysteryEventPool.mysteryEvent(matching: id)
    }

    static func pickMysteryEvent() -> MysteryEvent {
        MysteryEventPool.pickMysteryEvent()
    }
}

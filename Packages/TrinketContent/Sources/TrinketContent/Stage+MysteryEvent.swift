public extension Stage {
    var mysteryEvent: MysteryEvent? {
        if let eventID = encounter.mysteryEventID {
            return GameContent.mysteryEvent(matching: eventID)
        }
        guard let eventID = encounter.recruitEventID else { return nil }
        return GameContent.recruitEvent(matching: eventID)
    }
}

public extension Stage {
    /// Resolves the authored mystery or recruit event for this stage.
    ///
    /// This is catalog resolution, so it belongs in Content rather than the
    /// save-backed map presentation adapter.
    var mysteryEvent: MysteryEvent? {
        if let eventID = encounter.mysteryEventID {
            return GameContent.mysteryEvent(matching: eventID)
        }
        guard let eventID = encounter.recruitEventID else { return nil }
        return GameContent.recruitEvent(matching: eventID)
    }
}

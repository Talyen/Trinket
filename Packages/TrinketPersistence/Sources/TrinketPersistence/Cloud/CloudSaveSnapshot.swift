import TrinketContent

/// Cloud and local recovery share a value codec, not admission or repair policy.
/// The alias preserves the existing wire format and cloud call sites.
typealias CloudSaveSnapshot = PlayerSaveSnapshot

extension PlayerSaveSnapshot {
    /// Cloud imports reject unreadable maps before local repair can replace them.
    /// Session generation is device-local; commitCloudState stamps it on install.
    func restored() throws -> PlayerSave {
        guard !labyrinth.isMapPayloadUnreadable else { throw CloudSaveError.unsupportedSave }
        let save: PlayerSave
        do { save = try decodedSave() } catch { throw CloudSaveError.unsupportedSave }
        return try PlayerSaveSanitizer.sanitizeAndValidate(save)
    }

    /// Fresh-install tie-break input: whether either side holds real player
    /// progress. Contracts offers are excluded deliberately (regenerable
    /// board state, not progress); talents are included (spent points).
    var hasProgress: Bool {
        if starterSelection.phase != .chooseHero
            || !journey.completedStageIDs.isEmpty
            || !inventory.isEmpty
            || !homestead.nodeTiers.isEmpty
            || roster.gold > 0
            || !roster.unlockedTalents.isEmpty
            || labyrinth.hasEntered
            || !spires.highestClearedFloorBySpireID.isEmpty
            || contracts.highestWonEncounterLevel > 0 {
            return true
        }
        if let library, !library.isReadable || !library.progress.encounteredEnemyIDs.isEmpty
            || !library.progress.completedResearchIDs.isEmpty {
            return true
        }
        let voyage = PlayerVoyageState.decodePayload(voyagePayload)
        return voyage.activeRun != nil || voyage.isUnreadable
    }

    var campaignRank: Int {
        GameContent.chapters.flatMap(\.stages).enumerated()
            .filter { journey.completedStageIDs.contains($0.element.id) }
            .map { $0.offset + 1 }.max() ?? 0
    }
}

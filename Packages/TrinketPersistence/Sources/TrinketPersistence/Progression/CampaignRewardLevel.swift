import TrinketContent

enum CampaignRewardLevel {
    static func resolve(in save: PlayerSave, chapters: [Chapter] = GameContent.chapters) -> Int {
        let completedCampaign = chapters.flatMap(\.stages)
            .filter { save.journey.completedStageIDs.contains($0.id) && $0.encounter.isCombat }
            .map { StageCompletion.resolvedEncounterLevel(for: $0, in: chapters) }.max() ?? 0
        let clearedSpires = save.spires.highestClearedFloorBySpireID.values.map { $0 * 2 }.max() ?? 0
        let clearedLabyrinth = save.labyrinth.nodes.values
            .filter { $0.isCleared && $0.type.isCombat }
            .map { EncounterLevelResolver.labyrinthEnemyLevel(for: $0) }.max() ?? 0
        return min(40, max(1, save.contracts.highestWonEncounterLevel, completedCampaign, clearedSpires, clearedLabyrinth))
    }
}

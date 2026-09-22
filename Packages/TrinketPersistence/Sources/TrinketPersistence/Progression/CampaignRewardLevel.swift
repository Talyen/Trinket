import TrinketContent

enum CampaignRewardLevel {
    static func resolve(in save: PlayerSave, chapters: [Chapter] = GameContent.chapters) -> Int {
        if let stageID = save.journey.activeStageID,
           let stage = chapters.flatMap(\.stages).first(where: { $0.id == stageID }) {
            return StageCompletion.resolvedEncounterLevel(for: stage, in: chapters)
        }
        let authored = chapters.flatMap(\.stages).map { StageCompletion.resolvedEncounterLevel(for: $0, in: chapters) }.max()
        return authored ?? 1
    }
}

import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
extension PlayerSaveStore {
    func accessRestriction(for origin: PlayBattleOrigin?) -> StageMapMessage? {
        switch origin {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID) else {
                return StageMapMessage(title: "Stage Missing", message: "This stage is unavailable.")
            }
            if !contentAccess.allowsChapter(stage.chapterNumber) {
                return .fullGameRequired(.campaign(chapter: stage.chapterNumber))
            }
        case let .spire(spireID, floor):
            if !contentAccess.allowsSpireFloor(floor) {
                return .fullGameRequired(.spire(spireID, floor: floor))
            }
        case let .labyrinth(nodeID):
            guard let node = labyrinth.node(id: nodeID), let cluster = labyrinth.cluster(for: node.id) else {
                return StageMapMessage(title: "Path Missing", message: "This path is unavailable.")
            }
            if !contentAccess.allowsLabyrinthFloor(cluster.depthBand) {
                return .fullGameRequired(.labyrinth(floor: cluster.depthBand))
            }
        case .contract, .none:
            break
        }
        for id in [roster.activeHero.id, roster.activeCompanion.id] where !contentAccess.allowsCombatant(id) {
            return .fullGameRequired(.combatant(id))
        }
        return nil
    }

    func encounterAccessRestriction(for origin: PlayEncounterOrigin) -> StageMapMessage? {
        switch origin {
        case let .journey(stage): accessRestriction(for: .journey(stageID: stage.id))
        case let .labyrinth(nodeID): accessRestriction(for: PlayBattleOrigin.labyrinth(nodeID: nodeID))
        }
    }
}

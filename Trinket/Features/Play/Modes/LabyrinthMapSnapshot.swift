import TrinketAppState
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence

@MainActor
struct LabyrinthMapSnapshot {
    let state: PlayerLabyrinthState
    let events: [String: MysteryEvent]
    private let roster: PlayerRosterState
    private let worldSeed: UInt64
    private let access: ContentAccessPolicy

    init(playerSave: PlayerSaveStore, labyrinth: LabyrinthPlayMode, cluster: LabyrinthCluster) {
        state = playerSave.labyrinth
        roster = playerSave.roster
        worldSeed = playerSave.worldSeed
        access = playerSave.contentAccess
        events = Dictionary(uniqueKeysWithValues: LabyrinthMapPresentation.floorNodes(for: cluster, in: state).compactMap { node in
            labyrinth.previewMysteryEvent(for: node).map { (node.id, $0) }
        })
    }

    func recruitArtwork(for node: LabyrinthNode) -> EncounterArtReference? {
        LabyrinthMapPresentation.recruitEncounterArtReference(
            for: node,
            worldSeed: worldSeed,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs,
            access: access,
        )
    }

    func type(for node: LabyrinthNode) -> LabyrinthNodeType {
        LabyrinthMapPresentation.effectiveType(
            for: node,
            worldSeed: worldSeed,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs,
            access: access,
        )
    }
}

#if DEBUG
import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    func installPerformanceFixtures(
        mysteryEvent: String?, wantsHomesteadBuild: Bool, wantsStrongParty: Bool,
        wantsTalentFixture: Bool, wantsTalentPoint: Bool, wantsLabyrinthScroll: Bool,
        labyrinthNodeType: LabyrinthNodeType?, wantsTalentPair: Bool = false,
    ) {
        // "TRIN" in hex; retained fixture seed keeps map comparisons deterministic.
        let labyrinthFixtureSeed: UInt64 = 0x5452_494E
        _ = persistBatch(logging: "Performance fixtures") { save in
            if let event = mysteryEvent {
                save.journey.pinnedMysteryEventIDs["chapter-1-stage-2"] = event
                save.journey.mysteryOfferPayloads.removeValue(forKey: "chapter-1-stage-2")
            }
            if wantsHomesteadBuild {
                save.homestead.nodeTiers.removeValue(forKey: .wheatField)
            }
            if wantsStrongParty {
                // Maxed test party for late-Campaign frames.
                save.roster.progressions[save.roster.activeHeroID] = .at(level: 20)
                save.roster.progressions[save.roster.activeCompanionID] = .at(level: 20)
            }
            if wantsTalentFixture {
                let hero = save.roster.activeHeroID
                save.roster.progressions[hero] = wantsTalentPoint
                    ? .at(level: 2)
                    : CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
                save.roster.unlockedTalents[hero] = []
            }
            if wantsTalentPair {
                let companion = save.roster.activeCompanionID
                save.roster.progressions[companion] = CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
                save.roster.unlockedTalents[companion] = []
            }
            if wantsLabyrinthScroll {
                let map = LabyrinthGenerator.makeMap(seed: labyrinthFixtureSeed, floorCount: 3)
                save.labyrinth = PlayerLabyrinthState(
                    worldSeed: labyrinthFixtureSeed,
                    hasEntered: true,
                    clusters: map.clusters,
                    nodes: map.nodes,
                )
            }
            if let type = labyrinthNodeType {
                save.labyrinth = .freshStart
                save.labyrinth.ensureMap(seed: labyrinthFixtureSeed)
                guard let target = save.labyrinth.nodes.values.sorted(by: { $0.id < $1.id }).first(where: { $0.type == type })
                else { return }
                // Reveal everything except the target so the map scrolls fully.
                for id in save.labyrinth.nodes.keys {
                    save.labyrinth.nodes[id]?.isRevealed = true
                    save.labyrinth.nodes[id]?.isCleared = id != target.id
                }
            }
        }
    }
}
#endif

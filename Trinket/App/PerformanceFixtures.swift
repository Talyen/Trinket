#if DEBUG
import Foundation
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Disposable fixture state is installed before any measured interaction.
@MainActor
enum PerformanceFixtures {
    static func install(in state: AppState) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-performance-mystery-map"), let event = AppEnvironment.shared.mysteryRecruitEventID {
            _ = state.playerSave.persistBatch(logging: "Performance Mystery fixture") { save in
                save.journey.pinnedMysteryEventIDs["chapter-1-stage-2"] = event
                save.journey.mysteryOfferPayloads.removeValue(forKey: "chapter-1-stage-2")
            }
        }
        if arguments.contains("-performance-homestead-build") {
            _ = state.playerSave.persistBatch(logging: "Performance Homestead build fixture") { save in
                save.homestead.nodeTiers.removeValue(forKey: .wheatField)
            }
        }
        if arguments.contains("-performance-strong-party") {
            _ = state.playerSave.persistBatch(logging: "Performance late Campaign fixture") { save in
                save.roster.progressions[save.roster.activeHeroID] = .at(level: 20)
                save.roster.progressions[save.roster.activeCompanionID] = .at(level: 20)
            }
        }
        if arguments.contains("-performance-talent-reward") || arguments.contains("-performance-talent-point") {
            _ = state.playerSave.persistBatch(logging: "Performance talent fixture") { save in
                let hero = save.roster.activeHeroID
                save.roster.progressions[hero] = arguments.contains("-performance-talent-point")
                    ? .at(level: 2) : CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
                save.roster.unlockedTalents[hero] = []
            }
        }
        if arguments.contains("-performance-labyrinth-scroll") {
            _ = state.playerSave.persistBatch(logging: "Performance Labyrinth scrolling fixture") { save in
                let map = LabyrinthGenerator.makeMap(seed: 0x5452_494E, floorCount: 3)
                save.labyrinth = PlayerLabyrinthState(worldSeed: 0x5452_494E, hasEntered: true, clusters: map.clusters, nodes: map.nodes)
            }
        }
        guard let marker = arguments.firstIndex(of: "-performance-labyrinth-node"),
              arguments.indices.contains(marker + 1),
              let type = LabyrinthNodeType(rawValue: arguments[marker + 1])
        else { return }
        _ = state.playerSave.persistBatch(logging: "Performance Labyrinth fixture") { save in
            save.labyrinth = .freshStart
            save.labyrinth.ensureMap(seed: 0x5452_494E)
            guard let target = save.labyrinth.nodes.values.sorted(by: { $0.id < $1.id }).first(where: { $0.type == type }) else { return }
            for id in save.labyrinth.nodes.keys {
                save.labyrinth.nodes[id]?.isRevealed = true
                save.labyrinth.nodes[id]?.isCleared = id != target.id
            }
        }
    }
}
#endif

#if DEBUG
import Foundation
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Disposable fixture state is installed before any measured interaction.
@MainActor
enum PerformanceFixtures {
    /// "TRIN" in hex; shared world seed so labyrinth fixtures are deterministic.
    private static let labyrinthFixtureSeed: UInt64 = 0x5452_494E

    static func install(in state: AppState) {
        let arguments = ProcessInfo.processInfo.arguments
        // Capture per-fixture inputs first so all mutations below run in one
        // batch (previously up to six separate saves at launch).
        let mysteryEvent = arguments.contains("-performance-mystery-map")
            ? AppEnvironment.shared.mysteryRecruitEventID : nil
        let wantsHomesteadBuild = arguments.contains("-performance-homestead-build")
        let wantsStrongParty = arguments.contains("-performance-strong-party")
        let wantsTalentFixture = arguments.contains("-performance-talent-reward")
            || arguments.contains("-performance-talent-point")
        let wantsTalentPoint = arguments.contains("-performance-talent-point")
        let wantsLabyrinthScroll = arguments.contains("-performance-labyrinth-scroll")
        let labyrinthNodeType: LabyrinthNodeType? = {
            guard let marker = arguments.firstIndex(of: "-performance-labyrinth-node"),
                  arguments.indices.contains(marker + 1)
            else { return nil }
            return LabyrinthNodeType(rawValue: arguments[marker + 1])
        }()
        guard mysteryEvent != nil || wantsHomesteadBuild || wantsStrongParty
            || wantsTalentFixture || wantsLabyrinthScroll || labyrinthNodeType != nil
        else { return }

        // Failures are already logged and recorded by the store itself.
        _ = state.playerSave.persistBatch(logging: "Performance fixtures") { save in
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

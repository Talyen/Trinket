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

        state.playerSave.installPerformanceFixtures(
            mysteryEvent: mysteryEvent, wantsHomesteadBuild: wantsHomesteadBuild,
            wantsStrongParty: wantsStrongParty, wantsTalentFixture: wantsTalentFixture,
            wantsTalentPoint: wantsTalentPoint, wantsLabyrinthScroll: wantsLabyrinthScroll,
            labyrinthNodeType: labyrinthNodeType,
        )
    }
}
#endif

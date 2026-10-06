import Testing
import TrinketContent
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
enum SpiresTestSupport {
    /// Advances a fixture without launching combat or an outcome presentation.
    @discardableResult
    static func completeFloor(_ floor: SpireFloor, in state: PlaySession) -> Bool {
        let playerSave = state.playerSave
        let roster = playerSave.roster
        return playerSave.persistBatch(logging: "Test setup: complete Spire floor") { save in
            #expect(SpireCompletion.complete(
                floor: floor,
                hero: roster.activeHero,
                companion: roster.activeCompanion,
                save: &save,
                recordReceipt: { _ in },
            ) == .completed)
        }
    }
}

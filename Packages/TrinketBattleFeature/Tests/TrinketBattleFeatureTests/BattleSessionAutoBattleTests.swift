import Testing
import TrinketFeatureSupport
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionAutoBattleTests {
    @Test func autoBattlePlaysCardsInHandOrderUntilDisabled() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let expectedCardIDs = session.hand
            .filter { session.isCardPlayable($0) }
            .map(\.id)
        var playedCardIDs: [Int] = []

        session.isAutoBattleEnabled = true
        await session.driveAutoBattle(
            isCardCastActive: { false },
            isManualInteractionActive: { false },
            playCard: { card in
                let resolution = session.playCard(cardID: card.id)
                guard resolution.didCommit else { return false }
                playedCardIDs.append(card.id)
                if playedCardIDs.count == expectedCardIDs.count {
                    session.isAutoBattleEnabled = false
                }
                return true
            }
        )

        #expect(playedCardIDs == expectedCardIDs)
    }
}

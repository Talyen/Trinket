import BattleEngine
import Foundation
import Observation

struct BattleRecordedCardCast: Equatable {
    let id = UUID()
    let startedAt = Date()
    let card: BattleCard
    let index: Int
    let cardCount: Int
}

@MainActor
@Observable
final class BattleCardPlaybackState {
    var liftedCardID: Int?
    var isSuspended = false
    private(set) var cast: BattleRecordedCardCast?
    var delayOverride: Duration?

    func play(_ card: BattleCard, hand: [BattleCard], stagedCard: BattleCard?) {
        let cards = stagedCard.map { [$0] } ?? hand
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cast = BattleRecordedCardCast(card: card, index: index, cardCount: cards.count)
        liftedCardID = nil
    }

    func reset() {
        liftedCardID = nil
        cast = nil
    }
}

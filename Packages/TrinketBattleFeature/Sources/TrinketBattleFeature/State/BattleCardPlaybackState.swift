import BattleEngine
import Foundation
import Observation

struct BattleRecordedCardCast: Equatable, Identifiable {
    let id = UUID()
    var startedAt: Date
    var activationAt: Date
    var pausedAt: Date?
    let card: BattleCard
}

@MainActor
@Observable
final class BattleCardPlaybackState {
    private(set) var casts: [BattleRecordedCardCast] = []
    private(set) var isSuspended = false

    @discardableResult
    func append(_ card: BattleCard, at date: Date, activationAt: Date) -> UUID {
        let cast = BattleRecordedCardCast(startedAt: date, activationAt: activationAt, card: card)
        casts.append(cast)
        return cast.id
    }

    func retime(id: UUID, activationAt: Date) {
        guard let index = casts.firstIndex(where: { $0.id == id }) else { return }
        casts[index].activationAt = activationAt
    }

    func remove(id: UUID) {
        casts.removeAll { $0.id == id }
    }

    func setSuspended(_ suspended: Bool, at date: Date = .now) {
        guard isSuspended != suspended else { return }
        isSuspended = suspended
        for index in casts.indices {
            if suspended {
                casts[index].pausedAt = date
            } else if let paused = casts[index].pausedAt {
                casts[index].startedAt += date.timeIntervalSince(paused)
                casts[index].activationAt += date.timeIntervalSince(paused)
                casts[index].pausedAt = nil
            }
        }
    }

    func reset() {
        casts.removeAll()
    }
}

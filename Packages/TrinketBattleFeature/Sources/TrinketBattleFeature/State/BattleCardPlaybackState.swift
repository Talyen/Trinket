import BattleEngine
import Foundation
import Observation

struct BattleRecordedCardCast: Equatable, Identifiable {
    let id = UUID()
    var startedAt: Date
    var pausedAt: Date?
    let card: BattleCard
}

@MainActor
@Observable
final class BattleCardPlaybackState {
    private(set) var casts: [BattleRecordedCardCast] = []
    private(set) var isSuspended = false

    func append(_ cards: [BattleCard], at date: Date) {
        var start = max(date, (casts.last?.startedAt ?? date).addingTimeInterval(casts.isEmpty ? 0 : 0.32))
        for card in cards {
            casts.append(BattleRecordedCardCast(startedAt: start, card: card))
            start += 0.32
        }
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
                casts[index].pausedAt = nil
            }
        }
    }

    func reset() {
        casts.removeAll()
    }
}

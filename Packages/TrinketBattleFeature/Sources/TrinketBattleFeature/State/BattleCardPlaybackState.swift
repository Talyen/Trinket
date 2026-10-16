import BattleEngine
import Foundation
import Observation

struct BattleRecordedCardCast: Equatable, Identifiable {
    let id: UUID
    var startedAt: Date
    var activationAt: Date
    var pausedAt: Date?
    let card: BattleCard
    let isHandDeparture: Bool

    var departureEndAt: Date {
        activationAt.addingTimeInterval(
            BattleMotion.cardActivationDuration * (1 - Double(CardDissolveConfiguration().dissolveDuration)),
        )
    }

    func departureProgress(at date: Date) -> CGFloat {
        // Finish the artwork at swing; preserve the particle tail's authored speed.
        let date = pausedAt ?? date
        let dissolve = CardDissolveConfiguration().dissolveDuration
        if date < activationAt {
            let preparation = activationAt.timeIntervalSince(startedAt)
            guard preparation > 0 else { return 0 }
            return dissolve * CGFloat(max(0, date.timeIntervalSince(startedAt)) / preparation)
        }
        return min(1, dissolve + CGFloat(date.timeIntervalSince(activationAt) / BattleMotion.cardActivationDuration))
    }
}

@MainActor
@Observable
final class BattleCardPlaybackState {
    private(set) var casts: [BattleRecordedCardCast] = []
    private(set) var isSuspended = false

    var automaticCasts: [BattleRecordedCardCast] {
        casts.filter { !$0.isHandDeparture }
    }

    func handDeparture(id: UUID) -> BattleRecordedCardCast? {
        casts.first { $0.id == id && $0.isHandDeparture }
    }

    @discardableResult
    func append(
        _ card: BattleCard, at date: Date, activationAt: Date,
        id: UUID = UUID(), isHandDeparture: Bool = false,
    ) -> UUID {
        let cast = BattleRecordedCardCast(
            id: id, startedAt: date, activationAt: activationAt, card: card, isHandDeparture: isHandDeparture,
        )
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

import Foundation
import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func summarizeTimedDebuff(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first else { return nil }
        let durationSuffix = TimedBuffSummary.durationResource(in: stacks) { effect in
            effect.durationTurns > 0 ? effect.durationTurns : nil
        }
        switch active.effect {
        case .damageReductionPercent:
            let multiplier = stacks.reduce(1.0) { result, active in
                guard case let .damageReductionPercent(percent, _) = active.effect else { return result }
                return result * (1 - min(1, percent))
            }
            let percentInt = Int(((1 - multiplier) * 100).rounded())
            return EffectSummary(
                keyword: keyword,
                resource: L10n.summary_timeddebuffhandlers_86592dcd6c44(percentInt, durationSuffix),
            )
        case .damageReductionFlat:
            let amount = TimedBuffSummary.summedAmount(in: stacks) { effect in
                guard case let .damageReductionFlat(amount, _) = effect else { return nil }
                return amount
            }
            return EffectSummary(
                keyword: keyword,
                resource: L10n.summary_timeddebuffhandlers_6ba517693d06(amount, durationSuffix),
            )
        case .healingReductionPercent:
            let percent = stacks.reduce(0.0) { result, active in
                guard case let .healingReductionPercent(percent, _) = active.effect else { return result }
                return max(result, min(1, percent))
            }
            let percentInt = Int((percent * 100).rounded())
            return EffectSummary(
                keyword: keyword,
                resource: L10n.summary_timeddebuffhandlers_09c8078d2b51(percentInt, durationSuffix),
            )
        default:
            return nil
        }
    }
}

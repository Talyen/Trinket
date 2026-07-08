import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        let profile = modifiers(for: sourceID)
        switch effect {
        case let .shield(keyword, buffer, durationTicks):
            return .shield(
                keyword,
                buffer + profile.blockGainedBonus,
                durationTicks + profile.blockDurationBonus
            )
        case let .mitigation(keyword, percent, durationTicks):
            return .mitigation(
                keyword,
                percent + profile.armorGainedBonus,
                durationTicks + profile.armorDurationBonus
            )
        case let .leech(keyword, percent, durationTicks):
            return .leech(
                keyword,
                percent + profile.leechGainedBonus,
                durationTicks + profile.leechDurationBonus
            )
        default:
            return effect
        }
    }

    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTicks: Int
    ) {
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.append(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTicks: remainingTicks,
                    sourceActorID: sourceID
                )
            )
        }
    }

    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTicks: Int
    ) {
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.insert(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTicks: remainingTicks,
                    sourceActorID: sourceID
                ),
                at: 0
            )
        }
    }
}

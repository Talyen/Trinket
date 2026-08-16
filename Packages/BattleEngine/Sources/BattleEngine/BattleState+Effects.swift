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
        case let .shield(keyword, buffer):
            return .shield(
                keyword, buffer + profile.blockGainedBonus
            )
        case let .leech(keyword, percent, durationTurns):
            return .leech(
                keyword,
                percent,
                durationTurns + profile.leechDurationBonus
            )
        default:
            return effect
        }
    }

    mutating func applyBlock(
        _ amount: Int,
        to target: Combatant,
        source: Combatant,
        abilityName: String
    ) -> [ActionEvent] {
        let adjusted = adjustedOutgoingEffect(.shield(.block, amount), sourceID: source.id)
        guard case let .shield(keyword, buffer) = adjusted else { return [] }
        let applied = DefensePoolEngine.add(
            buffer,
            to: target,
            keyword: keyword,
            sourceActorID: source.id,
            in: &self
        )
        var events = [nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: applied,
            keyword: keyword
        )]
        events.append(contentsOf: CombatTriggerEngine.afterBlockGained(
            applied,
            by: target,
            in: &self
        ))
        return events
    }

    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTurns: Int
    ) {
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.append(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTurns: remainingTurns,
                    sourceActorID: sourceID
                )
            )
        }
    }

    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTurns: Int
    ) {
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.insert(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTurns: remainingTurns,
                    sourceActorID: sourceID
                ),
                at: 0
            )
        }
    }
}

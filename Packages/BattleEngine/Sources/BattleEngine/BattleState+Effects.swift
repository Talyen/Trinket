import TrinketContent
import TrinketCore

package struct BlockGain {
    package let applied: Int
    package let events: [ActionEvent]
}

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
                keyword, buffer + profile.blockGainedBonus,
            )
        default:
            return effect
        }
    }

    mutating func applyBlock(
        _ amount: Int,
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        applyOutgoingAdjustment: Bool = true,
    ) -> [ActionEvent] {
        applyBlockGain(
            amount,
            to: target,
            source: source,
            abilityName: abilityName,
            applyOutgoingAdjustment: applyOutgoingAdjustment,
        ).events
    }

    mutating func applyBlockGain(
        _ amount: Int,
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        applyOutgoingAdjustment: Bool = true,
    ) -> BlockGain {
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(target, in: self)
            || CombatTriggerEngine.preventsPurgedEffect(.shield(.block, amount), on: target, in: self) {
            return BlockGain(applied: 0, events: [])
        }
        let (keyword, buffer): (Keyword, Int)
        if applyOutgoingAdjustment,
           case let .shield(kw, buf) = adjustedOutgoingEffect(.shield(.block, amount), sourceID: source.id) {
            (keyword, buffer) = (kw, buf)
        } else {
            (keyword, buffer) = (.block, amount)
        }
        let applied = DefensePoolEngine.add(
            buffer,
            to: target,
            keyword: keyword,
            sourceActorID: source.id,
            applyFightPacing: applyOutgoingAdjustment,
            in: &self,
        )
        var events = [nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: applied,
            keyword: keyword,
        )]
        events.append(contentsOf: CombatTriggerEngine.afterBlockGained(
            applied,
            by: target,
            in: &self,
        ))
        return BlockGain(applied: applied, events: events)
    }

    mutating func interceptDebuff(_ effect: Effect, on target: Combatant) -> Bool {
        if CombatTriggerEngine.preventsDebuff(effect, on: target, in: self) {
            return true
        }
        guard effect.isRemovableDebuff,
              modifiers(for: target.id).triggers.blockFirstDebuffPerTurn,
              roster.runtime(for: target)?.faeWardBlockedThisTurn != true
        else { return false }
        roster.mutateRuntime(for: target) { $0.faeWardBlockedThisTurn = true }
        return true
    }

    @discardableResult
    mutating func insertEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTurns: Int,
        at index: Int? = nil,
        replacing matches: (Effect) -> Bool = { _ in false },
    ) -> Bool {
        guard !CombatTriggerEngine.preventsPurgedEffect(effect, on: target, in: self),
              !interceptDebuff(effect, on: target) else { return false }
        let effectID = consumeNextEffectID()
        let activeEffect = ActiveEffect(
            id: effectID,
            effect: effect,
            remainingTurns: remainingTurns,
            sourceActorID: sourceID,
        )
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.removeAll { matches($0.effect) }
            if let index {
                runtime.activeEffects.insert(activeEffect, at: index)
            } else {
                runtime.activeEffects.append(activeEffect)
            }
        }
        return true
    }

    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTurns: Int,
    ) {
        insertEffect(
            effect,
            to: target,
            sourceID: sourceID,
            remainingTurns: remainingTurns,
        )
    }

    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTurns: Int,
    ) {
        insertEffect(
            effect,
            to: target,
            sourceID: sourceID,
            remainingTurns: remainingTurns,
            at: 0,
        )
    }
}

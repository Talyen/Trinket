import TrinketContent
import TrinketCore

package enum BlockAmountBasis {
    case base, resolved
}

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
        amountBasis: BlockAmountBasis = .base,
        origin: ActionEvent.Origin = .automatic,
    ) -> [ActionEvent] {
        applyBlockGain(
            amount,
            to: target,
            source: source,
            abilityName: abilityName,
            amountBasis: amountBasis,
            origin: origin,
        ).events
    }

    mutating func applyBlockGain(
        _ amount: Int,
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        amountBasis: BlockAmountBasis = .base,
        origin: ActionEvent.Origin = .automatic,
    ) -> BlockGain {
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(target, in: self)
            || CombatTriggerEngine.preventsPurgedEffect(.shield(.block, amount), on: target, in: self) {
            return BlockGain(applied: 0, events: [])
        }
        let (keyword, buffer): (Keyword, Int)
        if amountBasis == .base,
           case let .shield(kw, buf) = adjustedOutgoingEffect(.shield(.block, amount), sourceID: source.id) {
            (keyword, buffer) = (kw, buf)
        } else {
            (keyword, buffer) = (.block, amount)
        }
        let (adjustedBuffer, spendsPreparation) = adjustedBlockGain(buffer, to: target)
        let applied = DefensePoolEngine.add(
            adjustedBuffer,
            to: target,
            keyword: keyword,
            sourceActorID: source.id,
            applyFightPacing: amountBasis == .base,
            in: &self,
        )
        if applied > 0, spendsPreparation {
            roster.mutateRuntime(for: target) {
                $0.talents.pending.nextBlockGainMultiplier = 1
                $0.talents.pending.nextBlockGainPreparedCardSerial = nil
            }
        }
        var events = [nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: applied,
            keyword: keyword,
            origin: origin,
        )]
        events.append(contentsOf: CombatTriggerEngine.afterBlockGained(
            applied,
            by: target,
            in: &self,
        ))
        return BlockGain(applied: applied, events: events)
    }

    private mutating func adjustedBlockGain(_ amount: Int, to target: Combatant) -> (Int, Bool) {
        let triggers = modifiers(for: target.id).triggers
        let belowHalf = roster.health(for: target) * 2 < roster.maxHealth(for: target)
        let healthMultiplier = belowHalf ? triggers.blockGainBelowHalfMultiplier : 1
        let pending = roster.runtime(for: target)?.talents.pending
        let prepared = pending?.nextBlockGainMultiplier ?? 1
        let spendsPreparation = prepared > 1 && CombatantTalentState.Pending.isLaterAbility(
            preparedCardSerial: pending?.nextBlockGainPreparedCardSerial,
            currentCardSerial: resolution.cardTalents?.playSerial,
        )
        let multiplier = healthMultiplier * (spendsPreparation ? prepared : 1)
        return (CombatRounding.scaled(amount, multiplier: multiplier), spendsPreparation)
    }

    mutating func interceptDebuff(_ effect: Effect, on target: Combatant) -> Bool {
        if CombatTriggerEngine.preventsDebuff(effect, on: target, in: self) {
            return true
        }
        guard effect.isRemovableDebuff,
              modifiers(for: target.id).triggers.blockFirstDebuffPerTurn,
              roster.runtime(for: target)?.talents.turn.blockedFaeWard != true
        else { return false }
        roster.mutateRuntime(for: target) { $0.talents.turn.blockedFaeWard = true }
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

    /// @discardableResult so existing fire-and-forget callers are untouched;
    /// new callers (like TimedDebuffHandler) should check the return instead
    /// of assuming the effect landed (ward/purge interception can refuse it).
    @discardableResult
    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTurns: Int,
    ) -> Bool {
        insertEffect(
            effect,
            to: target,
            sourceID: sourceID,
            remainingTurns: remainingTurns,
        )
    }

    @discardableResult
    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTurns: Int,
    ) -> Bool {
        insertEffect(
            effect,
            to: target,
            sourceID: sourceID,
            remainingTurns: remainingTurns,
            at: 0,
        )
    }
}

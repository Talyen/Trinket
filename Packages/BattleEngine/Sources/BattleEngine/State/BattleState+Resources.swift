import Foundation
import TrinketContent
import TrinketCore

package extension BattleState {
    @discardableResult
    mutating func grantGold(
        _ amount: Int,
        to combatant: Combatant,
        abilityID: String = "",
        abilityName: String,
        isTheft: Bool = false,
        isDirectCardGain: Bool = false,
        isLeechOverflow: Bool = false,
    ) async -> Int {
        guard amount > 0, goldFlow.gained < Int.max, roster.health(for: combatant) > 0 else { return 0 }
        if isLeechOverflow {
            resolution.enter(.leechOverflowGold)
        }
        defer {
            if isLeechOverflow {
                resolution.leave(.leechOverflowGold)
            }
        }
        let theftBonus = isTheft ? modifiers(for: combatant.id).triggers.goldStealFlatBonus : 0
        var granted = goldGranted(for: SaturatedArithmetic.saturatingAdd(amount, theftBonus), sourceActorID: combatant.id)
        if isTheft, granted > 0,
           roster.runtime(for: combatant)?.talents.pending.doubleNextGoldSteal == true {
            granted = SaturatedArithmetic.saturatingMul(granted, 2)
            roster.mutateRuntime(for: combatant) { $0.talents.pending.doubleNextGoldSteal = false }
        }
        if isTheft, granted > 0,
           modifiers(for: combatant.id).triggers.firstGoldTheftDoubleBattle,
           claimHeroTalent(.firstGoldTheftDouble, actorID: combatant.id, battle: true) {
            granted = SaturatedArithmetic.saturatingMul(granted, 2)
        }
        if isTheft, granted > 0,
           resolution.hasCriticalHit(by: combatant.id),
           modifiers(for: combatant.id).triggers.criticalGoldTheftBonus > 0,
           claimTalentAbility(.jackpot, actorID: combatant.id) {
            granted = SaturatedArithmetic.saturatingAdd(granted, modifiers(for: combatant.id).triggers.criticalGoldTheftBonus)
        }
        let previousEarned = goldFlow.gained
        granted = recordGoldGain(granted)
        guard granted > 0 else { return 0 }
        recordGoldHistory(granted, for: combatant, isTheft: isTheft)
        UniqueCombatEngine.gainedGold(granted, by: combatant, in: &self)
        let currentEarned = goldFlow.gained
        nextEvent(
            kind: .effect(.resourceGain),
            source: .init(combatant),
            abilityID: abilityID, abilityName: abilityName,
            target: combatant,
            amount: granted,
            keyword: .gold,
            origin: isDirectCardGain ? .direct : .automatic,
        )
        if isTheft {
            await CombatTriggerEngine.afterGoldTheft(by: combatant, amount: granted, in: &self)
        }
        await CombatTriggerEngine.afterGoldGained(
            granted: granted,
            previousEarned: previousEarned,
            currentEarned: currentEarned,
            combatant: combatant,
            in: &self,
        )
        return granted
    }

    private mutating func recordGoldHistory(_ amount: Int, for combatant: Combatant, isTheft: Bool) {
        let gainedAtTurn = turnCount
        let preparesDamage = isTheft && modifiers(for: combatant.id).triggers.gildedClaws
        roster.mutateRuntime(for: combatant) {
            $0.talents.history.lastGoldGainTurn = gainedAtTurn
            if preparesDamage {
                $0.talents.history.stolenGoldDamage = SaturatedArithmetic.saturatingAdd(
                    $0.talents.history.stolenGoldDamage, amount,
                )
            }
        }
    }

    func goldGranted(for amount: Int, sourceActorID: String) -> Int {
        let profile = modifiers(for: sourceActorID)
        var percent = max(0, profile.goldGainedPercent)
        let isPartySource = sourceActorID == roster.hero.id || sourceActorID == roster.companion.id
        if isPartySource {
            CombatTriggerEngine.forEachLivingAllyModifier(in: self) { profile in
                percent += max(0, profile.triggers.partyGoldGainedPercent)
            }
        }
        var scaled = CombatRounding.scaled(amount, multiplier: 1 + percent)
        if isPartySource,
           companionModifiers.triggers.goldDoubledWhileFullHealth,
           roster.companion.isAlive,
           roster.maxHealth(for: roster.companion.combatant) > 0,
           roster.health(for: roster.companion.combatant) == roster.maxHealth(for: roster.companion.combatant) {
            scaled = SaturatedArithmetic.saturatingMul(scaled, 2)
        }
        return SaturatedArithmetic.saturatingAdd(scaled, profile.goldGainedBonus)
    }

    @discardableResult
    mutating func restoreMana(_ amount: Int, to combatant: Combatant, isResolved: Bool = false, maximumGain: Int? = nil) -> Int {
        guard amount > 0, (maximumGain ?? .max) > 0,
              let participant = roster.participant(for: combatant), roster[participant].isAlive else { return 0 }
        let standalone = resolution.beginStandaloneRestoration()
        defer {
            if standalone {
                resolution.endStandaloneRestoration()
            }
        }
        let profile = modifiers(for: combatant.id)
        let deepRoots = profile.triggers.deepRoots &&
            roster[participant].activeEffects.contains { $0.effect.kind == .thorns }
        // Cadence caps constrain the amplified gain, including each doubling contribution.
        let requested = min(maximumGain ?? .max, requestedMana(amount, profile: profile, hasThorns: deepRoots, isResolved: isResolved))

        var total = 0
        var overflow = 0
        roster.mutateRuntime(for: combatant) { runtime in
            total = runtime.restoreMana(requested)
            overflow = max(0, requested - total)
        }
        if !isResolved, total > 0 {
            if profile.triggers.manaGainDoubleChancePercent > 0,
               BattleChance.succeeds(probability: profile.triggers.manaGainDoubleChancePercent, using: &rng) {
                applyDoubledMana(min(requested, maximumGain.map { $0 - total } ?? .max), for: combatant, total: &total, overflow: &overflow)
            }
            if profile.triggers.manaRestorationDoubleChancePercent > 0,
               claimTalentAbility(.arcaneReservoir, actorID: combatant.id),
               BattleChance.succeeds(probability: profile.triggers.manaRestorationDoubleChancePercent, using: &rng) {
                applyDoubledMana(min(requested, maximumGain.map { $0 - total } ?? .max), for: combatant, total: &total, overflow: &overflow)
            }
        }
        if overflow > 0 {
            applyManaOverflow(overflow, profile: profile, for: combatant)
        }
        return total
    }

    private func requestedMana(_ amount: Int, profile: CombatModifierProfile, hasThorns: Bool, isResolved: Bool) -> Int {
        guard amount > 0, !isResolved else { return amount }
        let bonus = SaturatedArithmetic.saturatingAdd(amount, profile.manaRestoredBonus)
        let scaled = CombatRounding.scaled(bonus, multiplier: 1 + profile.manaRestoredPercent)
        return SaturatedArithmetic.saturatingAdd(scaled, hasThorns ? 1 : 0)
    }

    private mutating func applyDoubledMana(
        _ requested: Int,
        for combatant: Combatant,
        total: inout Int,
        overflow: inout Int,
    ) {
        roster.mutateRuntime(for: combatant) { runtime in
            let doubled = runtime.restoreMana(requested)
            total += doubled
            overflow = SaturatedArithmetic.saturatingAdd(overflow, max(0, requested - doubled))
        }
    }

    private mutating func applyManaOverflow(_ overflow: Int, profile: CombatModifierProfile, for combatant: Combatant) {
        guard profile.triggers.livingConduit || profile.triggers.excessManaRestorationBlock else { return }
        roster.mutateRuntime(for: combatant) { runtime in
            if profile.triggers.livingConduit {
                runtime.talents.pending.manaOverflowThorns = SaturatedArithmetic.saturatingAdd(
                    runtime.talents.pending.manaOverflowThorns, overflow,
                )
            }
            if profile.triggers.excessManaRestorationBlock {
                let block = SaturatedArithmetic.saturatingMul(overflow, max(0, profile.triggers.excessManaRestorationBlockPerMana))
                runtime.talents.pending.manaOverflowBlock = SaturatedArithmetic.saturatingAdd(
                    runtime.talents.pending.manaOverflowBlock, block,
                )
            }
        }
    }

    mutating func restoreManaEmitting(
        _ amount: Int,
        to combatant: Combatant,
        abilityID: String = "",
        abilityName: String,
        source: Combatant? = nil,
        isResolved: Bool = false,
    ) async {
        let standalone = resolution.beginStandaloneRestoration()
        defer {
            if standalone {
                resolution.endStandaloneRestoration()
            }
        }
        let restored = restoreMana(amount, to: combatant, isResolved: isResolved)
        CombatTriggerEngine.consumeManaOverflowTalents(for: combatant, restoredMana: restored > 0, in: &self)
        guard restored > 0 else { return }

        nextEvent(
            kind: .effect(.resourceGain),
            source: .init(source ?? combatant),
            abilityID: abilityID, abilityName: abilityName,
            target: combatant,
            amount: restored,
            keyword: .mana,
        )
        await CombatTriggerEngine.afterGainMana(by: combatant, in: &self)
    }

    mutating func healEmitting(
        amount: Int,
        target: Combatant,
        source: Combatant,
        abilityID: String = "",
        abilityName: String,
        keyword: Keyword = .health,
        isDirectCardHeal: Bool = false,
    ) async {
        var request = HealRequest(
            amount: amount,
            target: target,
            sourceActorID: source.id,
            origin: .restoration(keyword), logAs: .instantHeal(
                source: .init(source),
                abilityID: abilityID,
                abilityName: abilityName,
                keyword: keyword,
            ),
        )
        request.isDirectCardHeal = isDirectCardHeal
        _ = await HealingEngine.resolveHeal(request, in: &self)
    }

    internal mutating func payMana(_ amount: Int, for combatant: Combatant) -> ManaPayment {
        guard let participant = roster.participant(for: combatant) else {
            return ManaPayment(payer: combatant, balanceBefore: 0, balanceAfter: 0)
        }
        let before = roster[participant].currentMana
        _ = roster[participant].spendMana(amount)
        return ManaPayment(payer: combatant, balanceBefore: before, balanceAfter: roster[participant].currentMana)
    }
}

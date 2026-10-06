import Foundation
import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func grantGoldEvent(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        isTheft: Bool = false,
        isDirectCardGain: Bool = false,
        isLeechOverflow: Bool = false,
    ) async -> [ActionEvent] {
        if isLeechOverflow {
            resolution.enter(.leechOverflowGold)
        }
        defer {
            if isLeechOverflow {
                resolution.leave(.leechOverflowGold)
            }
        }
        let theftBonus = isTheft && amount > 0 && roster.health(for: combatant) > 0
            ? modifiers(for: combatant.id).triggers.goldStealFlatBonus : 0
        let baseGold = goldGranted(for: SaturatedArithmetic.saturatingAdd(amount, theftBonus), sourceActorID: combatant.id)
        var granted = baseGold
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
        if isTheft, granted > 0, modifiers(for: combatant.id).triggers.gildedClaws {
            heroTalents.history[combatant.id, default: HeroTalentHistory()].stolenGoldDamage += granted
        }
        UniqueCombatEngine.gainedGold(granted, by: combatant, in: &self)
        let currentEarned = goldFlow.gained
        var events = [nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: combatant.name,
            abilityName: abilityName,
            target: combatant,
            amount: granted,
            keyword: .gold,
            origin: isDirectCardGain ? .direct : .automatic,
        )]
        if isTheft, granted > 0 {
            await events.append(contentsOf: CombatTriggerEngine.afterGoldTheft(by: combatant, in: &self))
        }
        await events.append(contentsOf: CombatTriggerEngine.goldGainTriggerEvents(
            granted: granted,
            previousEarned: previousEarned,
            currentEarned: currentEarned,
            combatant: combatant,
            in: &self,
        ))
        return events
    }

    func goldGranted(for amount: Int, sourceActorID: String) -> Int {
        let profile = modifiers(for: sourceActorID)
        var percent = max(0, profile.goldGainedPercent)
        let isPartySource = sourceActorID == roster.hero.id || sourceActorID == roster.companion.id
        if isPartySource {
            for profile in CombatTriggerEngine.livingAllyModifiers(in: self) {
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
    mutating func restoreMana(_ amount: Int, to combatant: Combatant) -> Int {
        let standalone = resolution.beginStandaloneRestoration()
        defer {
            if standalone {
                resolution.endStandaloneRestoration()
            }
        }
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let profile = modifiers(for: combatant.id)
        let deepRoots = amount > 0 && profile.triggers.deepRoots &&
            roster.activeEffects(for: combatant).contains { $0.effect.kind == .thorns }
        let requested = amount > 0
            ? SaturatedArithmetic.saturatingAdd(
                CombatRounding.scaled(
                    SaturatedArithmetic.saturatingAdd(amount, profile.manaRestoredBonus),
                    multiplier: 1 + profile.manaRestoredPercent,
                ), deepRoots ? 1 : 0,
            ) : amount
        let actual = runtime.restoreMana(requested)
        var total = actual
        var overflow = max(0, requested - actual)
        if actual > 0, profile.triggers.manaGainDoubleChancePercent > 0,
           BattleChance.succeeds(probability: profile.triggers.manaGainDoubleChancePercent, using: &rng) {
            let doubled = runtime.restoreMana(requested)
            total += doubled
            overflow = SaturatedArithmetic.saturatingAdd(overflow, max(0, requested - doubled))
        }
        if actual > 0, profile.triggers.manaRestorationDoubleChancePercent > 0,
           claimTalentAbility(.arcaneReservoir, actorID: combatant.id),
           BattleChance.succeeds(probability: profile.triggers.manaRestorationDoubleChancePercent, using: &rng) {
            let doubled = runtime.restoreMana(requested)
            total += doubled
            overflow = SaturatedArithmetic.saturatingAdd(overflow, max(0, requested - doubled))
        }
        if overflow > 0, profile.triggers.livingConduit {
            runtime.talents.pending.manaOverflowThorns = SaturatedArithmetic.saturatingAdd(
                runtime.talents.pending.manaOverflowThorns,
                overflow,
            )
        }
        if overflow > 0, profile.triggers.excessManaRestorationBlock {
            runtime.talents.pending.manaOverflowBlock = SaturatedArithmetic.saturatingAdd(
                runtime.talents.pending.manaOverflowBlock,
                overflow,
            )
        }
        roster.update(runtime)
        return total
    }

    mutating func restoreManaEmitting(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        actorName: String? = nil,
    ) async -> [ActionEvent] {
        let standalone = resolution.beginStandaloneRestoration()
        defer {
            if standalone {
                resolution.endStandaloneRestoration()
            }
        }
        let restored = restoreMana(amount, to: combatant)
        let overflowEvents = await CombatTriggerEngine.consumeManaOverflowTalents(
            for: combatant, restoredMana: restored > 0, in: &self,
        )
        guard restored > 0 else { return overflowEvents }
        var events: [ActionEvent] = []
        events.append(nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: actorName ?? combatant.name,
            abilityName: abilityName,
            target: combatant,
            amount: restored,
            keyword: .mana,
        ))
        await events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: combatant, in: &self))
        events.append(contentsOf: overflowEvents)
        return events
    }

    mutating func healEmitting(
        amount: Int,
        target: Combatant,
        source: Combatant,
        abilityName: String,
        keyword: Keyword = .health,
        isDirectCardHeal: Bool = false,
    ) async -> [ActionEvent] {
        var request = HealRequest(
            amount: amount,
            target: target,
            sourceActorID: source.id,
            origin: .restoration(keyword), logAs: .instantHeal(actorName: source.name, abilityName: abilityName, keyword: keyword),
        )
        request.isDirectCardHeal = isDirectCardHeal
        return await HealingEngine.resolveHeal(request, in: &self).events
    }

    internal mutating func payMana(_ amount: Int, for combatant: Combatant) -> ManaPayment {
        guard var runtime = roster.runtime(for: combatant) else {
            return ManaPayment(payer: combatant, balanceBefore: 0, balanceAfter: 0)
        }
        let before = runtime.currentMana
        _ = runtime.spendMana(amount)
        roster.update(runtime)
        return ManaPayment(payer: combatant, balanceBefore: before, balanceAfter: runtime.currentMana)
    }
}

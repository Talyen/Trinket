import Foundation
import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += goldGranted(for: amount, sourceActorID: sourceActorID)
    }

    mutating func grantGoldEvent(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        isTheft: Bool = false,
        isDirectCardGain: Bool = false,
    ) -> [ActionEvent] {
        let baseGold = goldGranted(for: amount, sourceActorID: combatant.id)
        let critical = baseGold > 0 && isDirectCardGain && CombatTriggerEngine.heroCardGoldCritical(source: combatant, in: &self)
        let granted = baseGold * (critical ? 2 : 1)
        let previousEarned = max(0, gold - initialGold)
        gold += granted
        if isTheft, granted > 0, modifiers(for: combatant.id).triggers.gildedClaws {
            heroTalents.history[combatant.id, default: HeroTalentHistory()].stolenGoldDamage += granted
        }
        UniqueCombatEngine.gainedGold(granted, by: combatant, in: &self)
        let currentEarned = max(0, gold - initialGold)
        var events = [nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: combatant.name,
            abilityName: abilityName,
            target: combatant,
            amount: granted,
            keyword: .gold,
            isCritical: critical,
        )]
        events.append(contentsOf: CombatTriggerEngine.goldGainTriggerEvents(
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
            percent += max(0, heroModifiers.triggers.partyGoldGainedPercent)
            percent += max(0, companionModifiers.triggers.partyGoldGainedPercent)
        }
        var scaled = CombatRounding.scaled(amount, multiplier: 1 + percent)
        if isPartySource,
           companionModifiers.triggers.goldDoubledWhileFullHealth,
           roster.companion.isAlive,
           roster.maxHealth(for: roster.companion.combatant) > 0,
           roster.health(for: roster.companion.combatant) == roster.maxHealth(for: roster.companion.combatant) {
            scaled *= 2
        }
        return scaled + profile.goldGainedBonus
    }

    @discardableResult
    mutating func restoreMana(_ amount: Int, to combatant: Combatant) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.restoreMana(amount)
        var total = actual
        if actual > 0, modifiers(for: combatant.id).triggers.manaGainDoubleChancePercent > 0,
           BattleChance.succeeds(probability: modifiers(for: combatant.id).triggers.manaGainDoubleChancePercent, using: &rng) {
            total += runtime.restoreMana(amount)
        }
        roster.update(runtime)
        return total
    }

    mutating func restoreManaEmitting(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        actorName: String? = nil,
    ) -> [ActionEvent] {
        let restored = restoreMana(amount, to: combatant)
        guard restored > 0 else { return [] }
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
        events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: combatant, in: &self))
        return events
    }

    mutating func healEmitting(
        amount: Int,
        target: Combatant,
        source: Combatant,
        abilityName: String,
        keyword: Keyword = .health,
        isDirectCardHeal: Bool = false,
    ) -> [ActionEvent] {
        var request = HealRequest(
            amount: amount,
            target: target,
            sourceActorID: source.id,
            logAs: .instantHeal(actorName: source.name, abilityName: abilityName, keyword: keyword),
        )
        request.isDirectCardHeal = isDirectCardHeal
        return HealingEngine.resolveHeal(request, in: &self).events
    }

    @discardableResult
    mutating func spendMana(_ amount: Int, for combatant: Combatant) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.spendMana(amount)
        roster.update(runtime)
        return actual
    }
}

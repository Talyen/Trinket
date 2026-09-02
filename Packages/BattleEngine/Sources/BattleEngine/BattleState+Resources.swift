import Foundation
import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += goldGranted(for: amount, sourceActorID: sourceActorID)
    }

    // swiftlint:disable:next function_body_length - resource spending and resulting events are one transaction
    mutating func grantGoldEvent(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
    ) -> [ActionEvent] {
        let granted = goldGranted(for: amount, sourceActorID: combatant.id)
        let previousEarned = max(0, gold - initialGold)
        gold += granted
        let currentEarned = max(0, gold - initialGold)
        var events = [nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: combatant.name,
            abilityName: abilityName,
            target: combatant,
            amount: granted,
            keyword: .gold,
        )]
        events.append(contentsOf: CombatTriggerEngine.healSelfAfterGoldGain(
            source: combatant,
            in: &self,
        ).events)

        let triggers = modifiers(for: combatant.id).triggers
        if triggers.onGainGoldDrawCardOncePerTurn,
           let owner = roster.participant(for: combatant),
           owner.isPartyMember,
           turnCadence.goldDrawOwners.insert(owner).inserted {
            let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &self)
            if drawn > 0 {
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: combatant.name,
                    abilityName: CombatTriggerEngine.triggerAbilityName(
                        "onGainGoldDrawCardOncePerTurn",
                        for: combatant,
                        fallback: "Golden Opportunity",
                        in: self,
                    ),
                    target: combatant,
                    amount: drawn,
                    keyword: .physical,
                ))
            }
        }
        if triggers.onGainGoldHealParty > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = roster[owner]
                guard member.isAlive, member.id != combatant.id else { continue }
                events.append(contentsOf: healEmitting(
                    amount: triggers.onGainGoldHealParty,
                    target: member.combatant,
                    source: combatant,
                    abilityName: CombatTriggerEngine.triggerAbilityName(
                        "onGainGoldHealParty",
                        for: combatant,
                        fallback: "Golden Recovery",
                        in: self,
                    ),
                ))
            }
        }
        if triggers.onGainGoldDoubleStatusEffectsNextCard {
            roster.mutateRuntime(for: combatant) { $0.pendingDoubleStatusNextCard = true }
        }
        if granted > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = roster[owner]
                guard member.isAlive else { continue }
                let percent = modifiers(for: member.id).triggers.goldGainBlockPercent
                if percent > 0 {
                    let block = Int((Double(granted) * percent).rounded(.down))
                    if block > 0 {
                        events.append(contentsOf: applyBlock(
                            block,
                            to: member.combatant,
                            source: member.combatant,
                            abilityName: CombatTriggerEngine.triggerAbilityName(
                                "goldGainBlockPercent",
                                for: member.combatant,
                                fallback: "Golden Guard",
                                in: self,
                            ),
                        ))
                    }
                    continue
                }
                let every = modifiers(for: member.id).triggers.blockPerGoldEarnedEvery
                guard every > 0 else { continue }
                let newlyGranted = currentEarned / every - previousEarned / every
                if newlyGranted > 0 {
                    events.append(contentsOf: applyBlock(
                        newlyGranted,
                        to: member.combatant,
                        source: member.combatant,
                        abilityName: CombatTriggerEngine.triggerAbilityName(
                            "blockPerGoldEarnedEvery",
                            for: member.combatant,
                            fallback: "Golden Guard",
                            in: self,
                        ),
                    ))
                }
            }
        }
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
    ) -> [ActionEvent] {
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(actorName: source.name, abilityName: abilityName, keyword: keyword),
            ),
            in: &self,
        )
        return outcome.events
    }

    @discardableResult
    mutating func spendMana(_ amount: Int, for combatant: Combatant) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.spendMana(amount)
        roster.update(runtime)
        return actual
    }
}

public extension BattleTurnEngine {
    static let manaEmpowermentCost = 3
    static let manaEmpowermentBonus = 1

    @discardableResult
    static func spendManaToEmpowerBurnOrFreezeIfNeeded(
        for ability: inout Ability,
        actor: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        guard ability.hasManaEmpowerableBurnOrFreezeDamage else { return [] }
        let empoweredKeyword = ability.damageComponents.first(where: \.isManaEmpowerableBurnOrFreezeDamage)?.keyword
        let repeats = ability.repeatsManaEmpowerment
            || (ability.hasManaEmpowerableBurnDamage
                && context.modifiers(for: actor.id).triggers.repeatManaEmpowerment)
        let triggers = context.modifiers(for: actor.id).triggers
        let isHealingCard = ability.keywords.contains(.health)
        let empowermentCost: Int = if isHealingCard, triggers.healingEmpowermentCostReduction > 0 {
            max(0, manaEmpowermentCost - triggers.healingEmpowermentCostReduction)
        } else if triggers.empowermentCostReduction > 0 {
            max(0, manaEmpowermentCost - triggers.empowermentCostReduction)
        } else {
            manaEmpowermentCost
        }
        var events: [ActionEvent] = []
        var purchases = 0
        let maxPurchases: Int = if empowermentCost == 0 {
            1
        } else {
            max(1, (context.roster.runtime(for: actor)?.maxMana ?? 1) / empowermentCost)
        }
        while purchases == 0 || repeats, purchases < maxPurchases {
            guard let runtime = context.roster.runtime(for: actor),
                  runtime.maxMana > 0,
                  runtime.currentMana >= empowermentCost
            else { break }
            let spent = context.spendMana(empowermentCost, for: actor)
            guard spent >= empowermentCost else { break }
            purchases += 1
            ability = ability.empoweredByMana(amount: manaEmpowermentBonus)
            events.append(contentsOf: CombatTriggerEngine.afterSpendMana(
                by: actor,
                amountSpent: spent,
                in: &context,
            ))
        }
        if purchases > 0, let empoweredKeyword {
            events.append(contentsOf: CombatTriggerEngine.drawOppositeElement(
                afterEmpowering: empoweredKeyword,
                by: actor,
                in: &context,
            ))
        }
        return events
    }
}

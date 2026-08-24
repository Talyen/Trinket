import Foundation
import TrinketContent
import TrinketCore

package extension BattleState {
    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += goldGranted(for: amount, sourceActorID: sourceActorID)
    }

    // swiftlint:disable:next function_body_length
    mutating func grantGoldEvent(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String
    ) -> [ActionEvent] {
        let granted = goldGranted(for: amount, sourceActorID: combatant.id)
        addGold(amount, sourceActorID: combatant.id)
        var events = [nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: combatant.name,
            abilityName: abilityName,
            target: combatant,
            amount: granted,
            keyword: .gold
        )]
        events.append(contentsOf: CombatTriggerEngine.healSelfAfterGoldGain(
            source: combatant,
            in: &self
        ).events)

        let triggers = modifiers(for: combatant.id).triggers
        // Golden Opportunity: gaining Gold draws 1 card (once per turn).
        if triggers.onGainGoldDrawCardOncePerTurn,
           let owner = roster.participant(for: combatant),
           owner.isPartyMember,
           goldDrawOwnersThisTurn.insert(owner).inserted {
            let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &self)
            if drawn > 0 {
                events.append(nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: combatant.name,
                    abilityName: "Golden Opportunity",
                    target: combatant,
                    amount: drawn,
                    keyword: .physical
                ))
            }
        }
        // Golden Recovery: gaining Gold restores 1 Health to the party.
        if triggers.onGainGoldHealParty > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = roster[owner]
                guard member.isAlive, member.id != combatant.id else { continue }
                events.append(contentsOf: healEmitting(
                    amount: triggers.onGainGoldHealParty,
                    target: member.combatant,
                    source: combatant,
                    abilityName: "Golden Recovery"
                ))
            }
        }
        // Golden Touch: gaining Gold doubles the status effects of your next card.
        if triggers.onGainGoldDoubleStatusEffectsNextCard {
            roster.mutateRuntime(for: combatant) { $0.pendingDoubleStatusNextCard = true }
        }
        // Golden Guard: 1 Block per N Gold earned this battle (party-wide gold).
        if granted > 0 {
            let previousEarned = max(0, gold - granted - initialGold)
            let currentEarned = max(0, gold - initialGold)
            for owner in [BattleParticipant.hero, .companion] {
                let member = roster[owner]
                guard member.isAlive else { continue }
                let every = modifiers(for: member.id).triggers.blockPerGoldEarnedEvery
                guard every > 0 else { continue }
                let newlyGranted = currentEarned / every - previousEarned / every
                if newlyGranted > 0 {
                    events.append(contentsOf: applyBlock(
                        newlyGranted,
                        to: member.combatant,
                        source: member.combatant,
                        abilityName: "Golden Guard"
                    ))
                }
            }
        }
        return events
    }

    /// Flat + percent bonuses applied to an outgoing gold grant (Lucky / Gilded).
    /// Companion talents apply party-wide: Haggler boosts all party Gold gains,
    /// and Flawless Bounty doubles them while the Lizard Scout is at full Health.
    func goldGranted(for amount: Int, sourceActorID: String) -> Int {
        let profile = modifiers(for: sourceActorID)
        var percent = max(0, profile.goldGainedPercent)
        let isPartySource = sourceActorID == roster.hero.id || sourceActorID == roster.companion.id
        if isPartySource {
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
        // Prismatic Spark: a chance to double Mana gained. The extra restore is silent
        // (no reaction re-trigger) so the doubled portion cannot loop into itself.
        if actual > 0, modifiers(for: combatant.id).triggers.manaGainDoubleChancePercent > 0,
           BattleChance.succeeds(probability: modifiers(for: combatant.id).triggers.manaGainDoubleChancePercent, using: &rng) {
            total += runtime.restoreMana(amount)
        }
        roster.update(runtime)
        return total
    }

    /// Restores mana, emits a `.resourceGain` event, and runs `afterGainMana` reactions.
    mutating func restoreManaEmitting(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        actorName: String? = nil
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
            keyword: .mana
        ))
        events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: combatant, in: &self))
        return events
    }

    /// Heals `target` from `source` and emits an `.instantHeal` event.
    mutating func healEmitting(
        amount: Int,
        target: Combatant,
        source: Combatant,
        abilityName: String,
        keyword: Keyword = .health
    ) -> [ActionEvent] {
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(actorName: source.name, abilityName: abilityName, keyword: keyword)
            ),
            in: &self
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
    /// Mana spent per +1 Burn/Freeze empowerment on a card play.
    static let manaEmpowermentCost = 3
    /// Burn/Freeze damage added per empowerment purchase.
    static let manaEmpowermentBonus = 1

    /// Spends `manaEmpowermentCost` Mana to raise Burn/Freeze damage numbers on `ability` by
    /// `manaEmpowermentBonus` when the actor can afford it.
    @discardableResult
    static func spendManaToEmpowerBurnOrFreezeIfNeeded(
        for ability: inout Ability,
        actor: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        guard ability.hasManaEmpowerableBurnOrFreezeDamage else { return [] }
        let empoweredKeyword = ability.damageComponents.first(where: \.isManaEmpowerableBurnOrFreezeDamage)?.keyword
        let repeats = ability.id == "meteor"
            || (ability.hasManaEmpowerableBurnDamage
                && context.modifiers(for: actor.id).triggers.repeatManaEmpowerment)
        // Spell Channeling / Efficient Care: talent Mana-empowerment cost reductions.
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
        while purchases == 0 || repeats {
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
                in: &context
            ))
        }
        if purchases > 0, let empoweredKeyword {
            events.append(contentsOf: CombatTriggerEngine.drawOppositeElement(
                afterEmpowering: empoweredKeyword,
                by: actor,
                in: &context
            ))
        }
        return events
    }
}

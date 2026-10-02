import TrinketContent
import TrinketCore

package extension BattleState {
    func talentEffectSummaries(of combatant: Combatant) -> [EffectSummary] {
        guard let runtime = roster.runtime(for: combatant), runtime.isAlive else { return [] }
        let pending = runtime.talents.pending.effectSummaries(
            criticalAppliesToParty: modifiers(for: combatant.id).triggers.onDodgeNextPartyHitGuaranteedCritical,
            partyCardDamageBonus: resolution.pendingPartyCardDamage(from: combatant.id),
            partyDamageBonus: resolution.pendingPartyDamage(for: combatant.id),
        )
        return pending + timedEffectSummaries(runtime.talents)
            + preparedEffectSummaries(heroTalents.history[combatant.id])
            + uniqueEffectSummaries(of: combatant)
    }

    private func timedEffectSummaries(_ talents: CombatantTalentState) -> [EffectSummary] {
        let timed = talents.timed
        var summaries: [EffectSummary] = []
        let dodge = talents.dodgeChanceBonus(atTurn: turnCount)
        if dodge > 0 {
            summaries.append(EffectSummary(keyword: .dodge, text: "Dodge Up: +\(Int((dodge * 100).rounded()))% Dodge chance."))
        }
        if talents.turn.negativeStatusImmune {
            summaries.append(EffectSummary(
                keyword: .cleanse,
                text: "Perfect Purity: Immune to debuffs until next turn.",
            ))
        }
        if !talents.turn.negativeStatusImmune, talents.turn.cleansedKeywordProtection.contains(.poison) {
            summaries.append(EffectSummary(keyword: .poison, text: "Poison cannot affect you until next turn."))
        }
        if timed.damage.amount > 0, turnCount < timed.damage.expiresAtTurn {
            summaries.append(EffectSummary(keyword: .physical, text: "Damage Up: +\(Int((timed.damage.amount * 100).rounded()))% damage."))
        }
        if let blessing = timed.lingeringBlessing, blessing.turnsRemaining > 0 {
            summaries.append(EffectSummary(
                keyword: .health,
                text: "Lingering Blessing: Restore \(blessing.amount) Health each round for \(blessing.turnsRemaining) rounds.",
            ))
        }
        return summaries
    }

    private func preparedEffectSummaries(_ history: HeroTalentHistory?) -> [EffectSummary] {
        guard let history else { return [] }
        var summaries: [EffectSummary] = []
        summaries.append(
            .dodge,
            when: history.dodgeGrowth > 0,
            text: "Improving Odds: +\(history.dodgeGrowth)% Dodge chance until you Dodge.",
        )
        summaries.append(
            .physical,
            when: history.stolenGoldDamage > 0,
            text: "Gilded Claws: Your next damaging card deals \(history.stolenGoldDamage) additional damage.",
        )
        summaries.append(
            .holy,
            when: history.blindingReduction > 0,
            text: "Blinding Light: Your next attack deals \(history.blindingReduction) less damage.",
        )
        summaries.append(
            .bleed,
            when: history.preparations.contains(.bleedDamage),
            text: "Redline: Your next Physical card deals 2 additional Bleed damage.",
        )
        summaries.append(
            .poison,
            when: history.preparations.contains(.doublePoison),
            text: "Unstable Culture: Your next Poison attack deals double damage.",
        )
        summaries.append(
            .physical,
            when: history.preparations.contains(.ignorePhysicalBlock),
            text: "Blind Spot: Your next Physical attack ignores enemy Block.",
        )
        return summaries
    }
}

private extension CombatantTalentState.Pending {
    func effectSummaries(criticalAppliesToParty: Bool, partyCardDamageBonus: Int, partyDamageBonus: Int = 0) -> [EffectSummary] {
        let criticalTarget = criticalAppliesToParty ? "party hit" : "attack"
        var summaries: [EffectSummary] = []
        summaries.append(.physical, when: doubleDamageAfterDodge, text: "Prepared Strike: Your next attack deals double damage.")
        summaries.append(
            .physical,
            when: guaranteedCriticalAfterDodge,
            text: "Prepared Critical: Your next \(criticalTarget) is a guaranteed Critical Hit.",
        )
        summaries.append(
            .physical,
            when: basicGuaranteedCritical,
            text: "Prepared Basic: Your next Basic attack is a guaranteed Critical Hit.",
        )
        summaries.append(
            .physical,
            when: damageAfterDodge > 0,
            text: "Prepared Strike: Your next attack deals \(damageAfterDodge) additional damage.",
        )
        summaries.append(
            .bleed,
            when: bleedAfterDodge > 0,
            text: "Prepared Bleed: Your next attack deals \(bleedAfterDodge) additional Bleed damage.",
        )
        appendCardPreparations(to: &summaries, partyCardDamageBonus: partyCardDamageBonus, partyDamageBonus: partyDamageBonus)
        appendAttackBonuses(to: &summaries)
        return summaries + healingPreparationSummaries() + additionalPreparationSummaries()
    }

    private func appendCardPreparations(to summaries: inout [EffectSummary], partyCardDamageBonus: Int, partyDamageBonus: Int) {
        let preparedDamage = cardDamageBonus + feintStrikeDamageBonus
        summaries.append(
            .physical,
            when: partyCardDamageBonus > 0,
            text: "Feint Strike: The party’s next card deals \(partyCardDamageBonus) additional damage.",
        )
        summaries.append(
            .physical,
            when: partyDamageBonus > 0,
            text: "Sniff Out: Your next attack deals \(partyDamageBonus) additional damage.",
        )
        summaries.append(
            .physical,
            when: preparedDamage > 0,
            text: "Prepared Damage: Your next attack deals \(preparedDamage) additional damage.",
        )
        summaries.append(
            .physical,
            when: cardDamagePercent > 0,
            text: "Prepared Damage: Your next attack deals \(Int((cardDamagePercent * 100).rounded()))% more damage.",
        )
        summaries.append(.physical, when: nextHitBonus > 0, text: "Prepared Hit: Your next attack deals \(nextHitBonus) additional damage.")
        summaries.append(
            .holy,
            when: nextAttackHolyBonus > 0,
            text: "Holy Infusion: Your next attack deals \(nextAttackHolyBonus) additional Holy damage.",
        )
        summaries.append(.holy, when: doubleNextHolyAttack, text: "Smite the Wicked: Your next Holy attack deals double damage.")
        summaries.append(.poison, when: doubleNextPoisonAttack, text: "Toxic Transfusion: Your next Poison attack deals double damage.")
        summaries.append(.poison, when: doubleNextPoisonDamage, text: "Toxic Backlash: Your next Poison damage is doubled.")
        summaries.append(.bleed, when: doubleNextBleedDamage, text: "Shatterpoint: The next Bleed damage is doubled.")
        summaries.append(.bleed, when: guaranteedBleedCritical, text: "Noxious Reaction: Your next Bleed attack Critically Hits.")
        summaries.append(.gold, when: doubleNextGoldSteal, text: "Escape Fund: Your next Gold steal is doubled.")
        summaries.append(
            .physical,
            when: nextPhysicalDamageBonus > 0,
            text: "Your next Physical attack deals \(nextPhysicalDamageBonus) additional damage.",
        )
        summaries.append(
            .mana,
            when: nextManaEmpowerDiscount > 0,
            text: "Your next Mana empowerment costs \(nextManaEmpowerDiscount) less Mana.",
        )
    }

    private func appendAttackBonuses(to summaries: inout [EffectSummary]) {
        let nextBurnAttackPercent = nextBurnAttackPercent?.value ?? 0
        let nextBurnDamageBonus = nextBurnDamageBonus?.value ?? 0
        let nextPoisonDamageBonus = nextPoisonDamageBonus?.value ?? 0
        let criticalBonus = (nextAttackCriticalBonus?.value ?? 0) + (nextCleanseCriticalBonus?.value ?? 0)
        summaries.append(
            .burn,
            when: nextBurnAttackPercent > 0,
            text: "Your next Burn attack deals \(Int((nextBurnAttackPercent * 100).rounded()))% more damage.",
        )
        summaries.append(
            .bleed,
            when: nextBleedDamageBonus > 0,
            text: "Your next Bleed attack deals \(nextBleedDamageBonus) additional damage.",
        )
        summaries.append(
            .burn,
            when: nextBurnDamageBonus > 0,
            text: "Your next Burn attack deals \(nextBurnDamageBonus) additional damage.",
        )
        summaries.append(
            .poison,
            when: nextPoisonDamageBonus > 0,
            text: "Your next Poison attack deals \(nextPoisonDamageBonus) additional damage.",
        )
        summaries.append(
            .physical,
            when: criticalBonus > 0,
            text: "Your next attack has +\(Int((criticalBonus * 100).rounded()))% Critical Hit chance.",
        )
        summaries.append(.physical, when: nextAttackGuaranteedCritical != nil, text: "Cracked Guard: Your next attack Critically Hits.")
        summaries.append(
            .physical,
            when: basicCriticalBonus > 0,
            text: "Prepared Basic: Your next Basic attack has +\(Int((basicCriticalBonus * 100).rounded()))% Critical Hit chance.",
        )
        summaries.append(
            .physical,
            when: attackBonusOnFullHealth > 0,
            text: "Prepared Strike: Your next attack deals \(attackBonusOnFullHealth) additional damage.",
        )
    }

    private func healingPreparationSummaries() -> [EffectSummary] {
        let healing = healingEchoes.reduce(0) { $0 + $1.amount }
        guard healing > 0 else { return [] }
        return [EffectSummary(keyword: .health, text: "Living Archive: Restore \(healing) Health next round.")]
    }

    private func additionalPreparationSummaries() -> [EffectSummary] {
        var summaries: [EffectSummary] = []
        summaries.append(.bleed, when: doubleNextBleedAttack != nil, text: "Redline: Your next Bleed attack deals double damage.")
        summaries.append(.stun, when: nextStunAttackDouble != nil, text: "Quaking Carapace: Your next Stun attack deals double damage.")
        summaries.append(
            .physical,
            when: doubleNextPhysicalAttack != nil,
            text: "Feigned Miss: Your next Physical attack deals double damage.",
        )
        summaries.append(.holy, when: nextHolyHitDouble != nil, text: "Sun-Struck Shell: Your next Holy damage is doubled.")
        summaries.append(.physical, when: doubleNextAttackAfterDeathsDoor, text: "Phoenix Vigor: Your next attack deals double damage.")
        summaries.append(.freeze, when: nextFreezeIgnoresBlock != nil, text: "Winter’s Wake: Your next Freeze attack ignores enemy Block.")
        summaries.append(.physical, when: nextAttackIgnoresBlock != nil, text: "Your next attack ignores enemy Block.")
        summaries.append(.physical, when: nextStunPreparedCritical != nil, text: "Stolen Thunder: Your next attack Critically Hits.")
        appendMagnitudePreparations(to: &summaries)
        return summaries
    }

    private func appendMagnitudePreparations(to summaries: inout [EffectSummary]) {
        let overchargePercent = overchargePercent?.value ?? 0
        let nextIncomingDamageMultiplier = nextIncomingDamageMultiplier?.value ?? 1
        summaries.append(
            .physical,
            when: overchargePercent > 0,
            text: "Overcharge: Your next attack deals \(Int((overchargePercent * 100).rounded()))% more damage.",
        )
        summaries.append(
            .bleed,
            when: nextBleedAttackMultiplier != nil,
            text: "Nimble Fang: Your next Bleed attack deals \(Int((((nextBleedAttackMultiplier?.value ?? 1) - 1) * 100).rounded()))% more damage.",
        )
        summaries.append(
            .physical,
            when: nextPhysicalAttackMultiplier != nil,
            text: "Phantom Counter: Your next Physical attack deals \(Int((((nextPhysicalAttackMultiplier?.value ?? 1) - 1) * 100).rounded()))% more damage.",
        )
        summaries.append(
            .physical,
            when: nextCriticalHitMultiplier != nil,
            text: "Perfect Tempo: Your next Critical Hit deals \(Int((((nextCriticalHitMultiplier?.value ?? 1) - 1) * 100).rounded()))% more damage.",
        )
        summaries.append(
            .physical,
            when: nextManaSpendAttackBonus != nil,
            text: "Aetherial Flow: Your next attack deals \(nextManaSpendAttackBonus?.value ?? 0) additional damage.",
        )
        summaries.append(
            .block,
            when: nextBlockGainMultiplier != nil,
            text: "Your next Block gain is increased by \(Int((((nextBlockGainMultiplier?.value ?? 1) - 1) * 100).rounded()))%.",
        )
        summaries.append(
            .block,
            when: nextIncomingDamageMultiplier < 1,
            text: "Warded Roost: Your next incoming damage is reduced by \(Int(((1 - nextIncomingDamageMultiplier) * 100).rounded()))%.",
        )
        summaries.append(
            .physical,
            when: nextOutgoingAttackMultiplier < 1,
            text: "Weaken Soul: Your next attack deals \(Int(((1 - nextOutgoingAttackMultiplier) * 100).rounded()))% less damage.",
        )
        summaries.append(
            .dodge,
            when: nextAttackMissChance > 0,
            text: "\(nextAttackMissAbilityName ?? "Blinding Light"): Your next attack has a \(Int((nextAttackMissChance * 100).rounded()))% chance to miss.",
        )
    }
}

private extension [EffectSummary] {
    /// Inactive preparations must not format descriptions or allocate summary entries.
    mutating func append(_ keyword: Keyword, when active: Bool, text: @autoclosure () -> String) {
        guard active else { return }
        append(EffectSummary(keyword: keyword, text: text()))
    }
}

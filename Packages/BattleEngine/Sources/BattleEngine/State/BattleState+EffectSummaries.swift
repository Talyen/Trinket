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
                text: "Perfect Purity: Negative status effects cannot affect you until next turn.",
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
        let prepared: [(Bool, Keyword, String)] = [
            (history.dodgeGrowth > 0, .dodge, "Improving Odds: +\(history.dodgeGrowth)% Dodge chance until you Dodge."),
            (
                history.stolenGoldDamage > 0,
                .physical,
                "Gilded Claws: Your next damaging card deals \(history.stolenGoldDamage) additional damage.",
            ),
            (history.blindingReduction > 0, .holy, "Blinding Light: Your next attack deals \(history.blindingReduction) less damage."),
            (history.preparations.contains(.bleedDamage), .bleed, "Redline: Your next Physical card deals 2 additional Bleed damage."),
            (history.preparations.contains(.doublePoison), .poison, "Unstable Culture: Your next Poison attack deals double damage."),
            (history.preparations.contains(.ignorePhysicalBlock), .physical, "Blind Spot: Your next Physical attack ignores enemy Block."),
        ]
        return prepared.compactMap { active, keyword, text in
            active ? EffectSummary(keyword: keyword, text: text) : nil
        }
    }
}

private extension CombatantTalentState.Pending {
    func effectSummaries(criticalAppliesToParty: Bool, partyCardDamageBonus: Int, partyDamageBonus: Int = 0) -> [EffectSummary] {
        let criticalTarget = criticalAppliesToParty ? "party hit" : "attack"
        let prepared: [(Bool, Keyword, String)] = [
            (doubleDamageAfterDodge, .physical, "Prepared Strike: Your next attack deals double damage."),
            (guaranteedCriticalAfterDodge, .physical, "Prepared Critical: Your next \(criticalTarget) is a guaranteed Critical Hit."),
            (basicGuaranteedCritical, .physical, "Prepared Basic: Your next Basic attack is a guaranteed Critical Hit."),
            (damageAfterDodge > 0, .physical, "Prepared Strike: Your next attack deals \(damageAfterDodge) additional damage."),
            (bleedAfterDodge > 0, .bleed, "Prepared Bleed: Your next attack deals \(bleedAfterDodge) additional Bleed damage."),
            (partyCardDamageBonus > 0, .physical, "Feint Strike: The party’s next card deals \(partyCardDamageBonus) additional damage."),
            (
                partyDamageBonus > 0,
                .physical,
                "Sniff Out: Your next attack deals \(partyDamageBonus) additional damage.",
            ),
            (cardDamageBonus > 0, .physical, "Prepared Damage: Your next attack deals \(cardDamageBonus) additional damage."),
            (
                cardDamagePercent > 0,
                .physical,
                "Prepared Damage: Your next attack deals \(Int((cardDamagePercent * 100).rounded()))% more damage.",
            ),
            (nextHitBonus > 0, .physical, "Prepared Hit: Your next attack deals \(nextHitBonus) additional damage."),
            (nextAttackHolyBonus > 0, .holy, "Holy Infusion: Your next attack deals \(nextAttackHolyBonus) additional Holy damage."),
            (doubleNextHolyAttack, .holy, "Smite the Wicked: Your next Holy attack deals double damage."),
            (doubleNextPoisonAttack, .poison, "Toxic Transfusion: Your next Poison attack deals double damage."),
            (doubleNextPoisonDamage, .poison, "Toxic Backlash: Your next Poison damage is doubled."),
            (doubleNextBleedDamage, .bleed, "Shatterpoint: The next Bleed damage is doubled."),
            (guaranteedBleedCritical, .bleed, "Noxious Reaction: Your next Bleed attack Critically Hits."),
            (doubleNextGoldSteal, .gold, "Escape Fund: Your next Gold steal is doubled."),
            (nextPhysicalDamageBonus > 0, .physical, "Your next Physical attack deals \(nextPhysicalDamageBonus) additional damage."),
            (nextManaEmpowerDiscount > 0, .mana, "Your next Mana empowerment costs \(nextManaEmpowerDiscount) less Mana."),
            (nextBurnAttackPercent > 0, .burn, "Your next Burn attack deals \(Int((nextBurnAttackPercent * 100).rounded()))% more damage."),
            (nextBleedDamageBonus > 0, .bleed, "Your next Bleed attack deals \(nextBleedDamageBonus) additional damage."),
            (nextBurnDamageBonus > 0, .burn, "Your next Burn attack deals \(nextBurnDamageBonus) additional damage."),
            (nextPoisonDamageBonus > 0, .poison, "Your next Poison attack deals \(nextPoisonDamageBonus) additional damage."),
            (
                nextAttackCriticalBonus > 0,
                .physical,
                "Your next attack has +\(Int((nextAttackCriticalBonus * 100).rounded()))% Critical Hit chance.",
            ),
            (nextAttackGuaranteedCritical, .physical, "Cracked Guard: Your next attack Critically Hits."),
            (
                basicCriticalBonus > 0,
                .physical,
                "Prepared Basic: Your next Basic attack has +\(Int((basicCriticalBonus * 100).rounded()))% Critical Hit chance.",
            ),
            (
                attackBonusOnFullHealth > 0,
                .physical,
                "Prepared Strike: Your next attack deals \(attackBonusOnFullHealth) additional damage.",
            ),
        ]
        var summaries = prepared.compactMap { active, keyword, text in
            active ? EffectSummary(keyword: keyword, text: text) : nil
        }
        let healing = healingEchoes.reduce(0) { $0 + $1.amount }
        if healing > 0 {
            summaries.append(EffectSummary(keyword: .health, text: "Living Archive: Restore \(healing) Health next round."))
        }
        return summaries
    }
}

import TrinketContent
import TrinketCore

extension BattleState {
    func talentEffectSummaries(of combatant: Combatant) -> [EffectSummary] {
        guard let runtime = roster.runtime(for: combatant), runtime.isAlive else { return [] }
        let pending = runtime.talents.pending.effectSummaries(
            criticalAppliesToParty: modifiers(for: combatant.id).triggers.onDodgeNextPartyHitGuaranteedCritical,
            partyCardDamageBonus: resolution.pendingPartyCardDamage(from: combatant.id),
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
            (history.falseOpening, .dodge, "False Opening: +5% Dodge chance until your next turn."),
            (history.dodgeGrowth > 0, .dodge, "Improving Odds: +\(history.dodgeGrowth)% Dodge chance until you Dodge."),
            (
                history.stolenGoldDamage > 0,
                .physical,
                "Gilded Claws: Your next damaging card deals \(history.stolenGoldDamage) additional damage.",
            ),
            (history.blindingReduction > 0, .holy, "Blinding Light: Your next attack deals \(history.blindingReduction) less damage."),
            (history.preparedHeal, .health, "Measured Dose: Your next card that restores Health restores 1 additional Health."),
            (history.preparedGold, .gold, "House Credit: Your next card that grants Gold grants 1 additional Gold."),
            (history.preparedPhysical, .physical, "Improvised Assault: Your next Physical card deals 2 additional damage."),
            (history.preparations.contains(.bleedDamage), .bleed, "Redline: Your next Physical card deals 2 additional Bleed damage."),
            (history.preparations.contains(.poisonDamage), .poison, "Perfect Purity: Your next attack deals 2 additional Poison damage."),
            (history.preparations.contains(.doublePoison), .poison, "Unstable Culture: Your next Poison card deals double Poison damage."),
            (history.preparations.contains(.ignorePhysicalBlock), .physical, "Blind Spot: Your next Physical card ignores enemy Block."),
            (history.preparations.contains(.stealGold), .gold, "Paid in Full: Your next Physical card steals 2 Gold."),
        ]
        return prepared.compactMap { active, keyword, text in
            active ? EffectSummary(keyword: keyword, text: text) : nil
        }
    }
}

private extension CombatantTalentState.Pending {
    func effectSummaries(criticalAppliesToParty: Bool, partyCardDamageBonus: Int) -> [EffectSummary] {
        let criticalTarget = criticalAppliesToParty ? "party hit" : "attack"
        let prepared: [(Bool, Keyword, String)] = [
            (doubleDamageAfterDodge, .physical, "Prepared Strike: Your next attack deals double damage."),
            (guaranteedCriticalAfterDodge, .physical, "Prepared Critical: Your next \(criticalTarget) is a guaranteed Critical Hit."),
            (basicGuaranteedCritical, .physical, "Prepared Basic: Your next Basic attack is a guaranteed Critical Hit."),
            (doubleStatusNextCard, .poison, "Golden Touch: Your next card deals double Poison, Bleed, and Burn damage."),
            (damageAfterDodge > 0, .physical, "Prepared Strike: Your next attack deals \(damageAfterDodge) additional damage."),
            (bleedAfterDodge > 0, .bleed, "Prepared Bleed: Your next attack deals \(bleedAfterDodge) additional Bleed damage."),
            (partyCardDamageBonus > 0, .physical, "Feint Strike: The party’s next card deals \(partyCardDamageBonus) additional damage."),
            (cardDamageBonus > 0, .physical, "Prepared Damage: Your next attack deals \(cardDamageBonus) additional damage."),
            (
                cardDamagePercent > 0,
                .physical,
                "Prepared Damage: Your next attack deals \(Int((cardDamagePercent * 100).rounded()))% more damage.",
            ),
            (nextHitBonus > 0, .physical, "Prepared Hit: Your next attack deals \(nextHitBonus) additional damage."),
            (nextAttackHolyBonus > 0, .holy, "Holy Infusion: Your next attack deals \(nextAttackHolyBonus) additional Holy damage."),
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

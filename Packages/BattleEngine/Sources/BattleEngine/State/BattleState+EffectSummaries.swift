import Foundation
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
            + preparedEffectSummaries(runtime.talents.history)
            + uniqueEffectSummaries(of: combatant)
    }

    private func timedEffectSummaries(_ talents: CombatantTalentState) -> [EffectSummary] {
        let timed = talents.timed
        var summaries: [EffectSummary] = []
        let dodge = talents.dodgeChanceBonus(atTurn: turnCount)
        if dodge > 0 {
            summaries.append(EffectSummary(
                keyword: .dodge,
                resource: L10n.summary_battlestate_effectsummaries_1d22931030c3(CombatRounding.rounded((dodge * 100).rounded())),
            ))
        }
        if talents.turn.negativeStatusImmune {
            summaries.append(EffectSummary(
                keyword: .cleanse,
                resource: L10n.summary_battlestate_effectsummaries_76cc8eb6266f,
            ))
        }
        if !talents.turn.negativeStatusImmune {
            for keyword in talents.turn.cleansedKeywordProtection.sorted(by: { $0.rawValue < $1.rawValue }) {
                summaries.append(EffectSummary(
                    keyword: keyword,
                    resource: L10n.summary_battlestate_effectsummaries_e7633bc9777a(keyword.nameResource),
                ))
            }
        }
        if talents.turn.blockGainPrevented {
            summaries.append(EffectSummary(keyword: .holy, resource: L10n.summary_battlestate_effectsummaries_28ffa132d413))
        }
        let canonicalLocale = Locale(identifier: "en")
        let purgedBuffs = talents.turn.purgedEffectProtection.compactMap { kind in
            purgedBuffName(kind).map { (resource: $0, sortKey: LocalizedGameText($0, locale: canonicalLocale).text) }
        }.sorted { $0.sortKey < $1.sortKey }.map(\.resource)
        if !purgedBuffs.isEmpty {
            summaries.append(EffectSummary(
                keyword: .purge,
                resource: L10n.summary_battlestate_effectsummaries_5a57edb4d329(BattleCopy.list(purgedBuffs)),
            ))
        }
        if timed.damage.amount > 0, turnCount < timed.damage.expiresAtTurn {
            summaries.append(EffectSummary(
                keyword: .physical,
                resource: L10n
                    .summary_battlestate_effectsummaries_75aa7414e689(CombatRounding.rounded((timed.damage.amount * 100).rounded())),
            ))
        }
        if let blessing = timed.lingeringBlessing, blessing.turnsRemaining > 0 {
            summaries.append(EffectSummary(
                keyword: .health,
                resource: L10n.summary_battlestate_effectsummaries_4c5c3a3e9a71(blessing.amount, blessing.turnsRemaining),
            ))
        }
        return summaries
    }

    private func purgedBuffName(_ kind: EffectKind) -> LocalizedStringResource? {
        switch kind {
        case .shield: L10n.summary_battlestate_effectsummaries_211d0bb8cf4f
        case .thorns: L10n.summary_battlestate_effectsummaries_d20c5a45f302
        case .criticalChanceBonus: L10n.summary_battlestate_effectsummaries_4f9a966fb271
        case .restoreManaOnHit: L10n.summary_battlestate_effectsummaries_8039fda759c2
        case .damageKeywordOverride: L10n.summary_battlestate_effectsummaries_6ef0eec57426
        case .nextHolyStrike: L10n.summary_battlestate_effectsummaries_b96a31dfc751
        case .nextStrikeDouble: L10n.summary_battlestate_effectsummaries_f6148c61d5e8
        case .playNextCardTwice: L10n.summary_battlestate_effectsummaries_3463093c2b5c
        case .nextBurnBonus: L10n.summary_battlestate_effectsummaries_786cb2fa9e35
        case .evadeNextHit: L10n.summary_battlestate_effectsummaries_3643dd816bb8
        case .maximumManaBonus: L10n.summary_battlestate_effectsummaries_504389fe260c
        case .nextStrikeCritical: L10n.summary_battlestate_effectsummaries_fd3ca4dcb7ab
        case .nextStrikeLeech: L10n.summary_battlestate_effectsummaries_5392d836018d
        case .nextStrikeDamageKeywordOverride: L10n.summary_battlestate_effectsummaries_22f2841b72e5
        case .partyDamageBonus: L10n.summary_battlestate_effectsummaries_3fc6722054ba
        case .freezeNextAttacker: L10n.summary_battlestate_effectsummaries_92e5596a3512
        case .onHitDamage: L10n.summary_battlestate_effectsummaries_3e1cf6602265
        case .avatar: L10n.summary_battlestate_effectsummaries_ca8e826d9c2e
        default: nil
        }
    }

    private func preparedEffectSummaries(_ history: CombatantTalentHistory) -> [EffectSummary] {
        var summaries: [EffectSummary] = []
        summaries.appendAmount(.dodge, history.dodgeGrowth, resource: L10n.summary_battlestate_effectsummaries_21b62c8cbffa)
        summaries.appendAmount(.physical, history.stolenGoldDamage, resource: L10n.summary_battlestate_effectsummaries_155a41841bc9)
        summaries.appendAmount(.holy, history.blindingReduction, resource: L10n.summary_battlestate_effectsummaries_8406c44f9158)
        summaries.append(
            .bleed,
            when: history.preparations.contains(.bleedDamage),
            resource: L10n.summary_battlestate_effectsummaries_031a8695b433,
        )
        summaries.append(
            .poison,
            when: history.preparations.contains(.doublePoison),
            resource: L10n.summary_battlestate_effectsummaries_b769ca6798ae,
        )
        summaries.append(
            .physical,
            when: history.preparations.contains(.ignorePhysicalBlock),
            resource: L10n.summary_battlestate_effectsummaries_6e538b28b50c,
        )
        return summaries
    }

    private func uniqueEffectSummaries(of combatant: Combatant) -> [EffectSummary] {
        guard let runtime = roster.runtime(for: combatant) else { return [] }
        let state = runtime.uniques
        var summaries: [EffectSummary] = []
        summaries.appendPercent(.dodge, state.wrenflightDodge, resource: L10n.summary_battlestate_effectsummaries_67548e4830cc)
        summaries.append(
            .physical,
            when: state.patientEdgeReady,
            resource: L10n.summary_battlestate_effectsummaries_b193bce3b9f8,
        )
        summaries.append(
            .poison,
            when: state.viperReady,
            resource: L10n.summary_battlestate_effectsummaries_0bdf6333f6e4,
        )
        summaries.append(
            .poison,
            when: state.wildheartReady,
            resource: L10n.summary_battlestate_effectsummaries_315c178423c3,
        )
        summaries.appendAmount(.holy, state.goldDamage, resource: L10n.summary_battlestate_effectsummaries_db3926475fe7)
        return summaries
    }
}

private extension CombatantTalentState.Pending {
    func effectSummaries(criticalAppliesToParty: Bool, partyCardDamageBonus: Int, partyDamageBonus: Int = 0) -> [EffectSummary] {
        let criticalTarget = criticalAppliesToParty ? L10n.summary_battlestate_effectsummaries_73aacda6ed7a : L10n
            .summary_battlestate_effectsummaries_fca30679635b
        var summaries: [EffectSummary] = []
        summaries.append(.physical, when: doubleDamageAfterDodge, resource: L10n.summary_battlestate_effectsummaries_292d229ab591)
        summaries.append(
            .physical,
            when: guaranteedCriticalAfterDodge,
            resource: L10n.summary_battlestate_effectsummaries_3b9581cc412f(criticalTarget),
        )
        summaries.append(
            .physical,
            when: basicGuaranteedCritical,
            resource: L10n.summary_battlestate_effectsummaries_3531028230c1,
        )
        summaries.appendAmount(.physical, damageAfterDodge, resource: L10n.summary_battlestate_effectsummaries_e51d9d3d269a)
        summaries.appendAmount(.bleed, bleedAfterDodge, resource: L10n.summary_battlestate_effectsummaries_d6d71d8a3214)
        let preparedDamage = SaturatedArithmetic.saturatingAdd(cardDamageBonus, feintStrikeDamageBonus)
        let nextAttackDamageBonus = nextAttackDamageBonus?.value ?? 0
        summaries.appendAmount(.physical, partyCardDamageBonus, resource: L10n.summary_battlestate_effectsummaries_7d576ea97f2e)
        summaries.appendAmount(.physical, partyDamageBonus, resource: L10n.summary_battlestate_effectsummaries_34190d7944be)
        summaries.appendAmount(.physical, preparedDamage, resource: L10n.summary_battlestate_effectsummaries_06b908595f62)
        summaries.appendPercent(.physical, cardDamagePercent, resource: L10n.summary_battlestate_effectsummaries_d295c94dcb1f)
        summaries.appendAmount(.physical, nextHitBonus, resource: L10n.summary_battlestate_effectsummaries_0b644211f94a)
        summaries.appendAmount(.holy, nextAttackHolyBonus, resource: L10n.summary_battlestate_effectsummaries_03aee9c88ab4)
        summaries.append(.holy, when: doubleNextHolyAttack, resource: L10n.summary_battlestate_effectsummaries_6552f2f0d34b)
        summaries.append(.poison, when: doubleNextPoisonAttack, resource: L10n.summary_battlestate_effectsummaries_8e9180740904)
        summaries.append(.poison, when: doubleNextPoisonDamage, resource: L10n.summary_battlestate_effectsummaries_53c61953e638)
        summaries.append(.bleed, when: doubleNextBleedDamage, resource: L10n.summary_battlestate_effectsummaries_4bb46a6be256)
        summaries.append(
            .bleed,
            when: guaranteedBleedCritical?.value == true,
            resource: L10n.summary_battlestate_effectsummaries_cb6939b701fc,
        )
        summaries.append(.gold, when: doubleNextGoldSteal, resource: L10n.summary_battlestate_effectsummaries_1e1f899e0668)
        summaries.appendPreparedAmount(.physical, nextPhysicalDamageBonus, resource: L10n.summary_battlestate_effectsummaries_2958f6f8a886)
        summaries.appendAmount(.gold, nextAttackDamageBonus, resource: L10n.summary_battlestate_effectsummaries_0cd41331d925)
        summaries.appendAmount(.mana, nextManaEmpowerDiscount, resource: L10n.summary_battlestate_effectsummaries_a8bf5a1d7814)

        appendAttackBonuses(to: &summaries)
        let healing = healingEchoes.reduce(0) { SaturatedArithmetic.saturatingAdd($0, $1.amount) }
        summaries.appendAmount(.health, healing, resource: L10n.summary_battlestate_effectsummaries_a6c30d506ff6)
        appendAdditionalPreparations(to: &summaries)
        return summaries
    }

    private func appendAttackBonuses(to summaries: inout [EffectSummary]) {
        let nextBurnAttackPercent = nextBurnAttackPercent?.value ?? 0
        let nextBurnDamageBonus = nextBurnDamageBonus?.value ?? 0
        let nextPoisonDamageBonus = SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(nextPoisonDamageBonus?.value ?? 0, nextToxicRemedyDamageBonus?.value ?? 0),
            nextLeechCriticalPoisonAttackBonus?.value ?? 0,
        )
        let nextBleedDamageBonus = SaturatedArithmetic.saturatingAdd(
            nextBleedDamageBonus?.value ?? 0,
            nextDodgeBleedAttackBonus?.value ?? 0,
        )
        let criticalBonus = (nextAttackCriticalBonus?.value ?? 0) + (nextCleanseCriticalBonus?.value ?? 0)
        summaries.appendPercent(.burn, nextBurnAttackPercent, resource: L10n.summary_battlestate_effectsummaries_97d3897e9898)
        summaries.appendAmount(.bleed, nextBleedDamageBonus, resource: L10n.summary_battlestate_effectsummaries_3b4993948f20)
        summaries.appendAmount(.burn, nextBurnDamageBonus, resource: L10n.summary_battlestate_effectsummaries_943d50431989)
        summaries.appendAmount(.poison, nextPoisonDamageBonus, resource: L10n.summary_battlestate_effectsummaries_1fcd76ac104a)
        summaries.appendPercent(.physical, criticalBonus, resource: L10n.summary_battlestate_effectsummaries_672f9a146c54)
        summaries.append(
            .physical,
            when: nextAttackGuaranteedCritical != nil,
            resource: L10n.summary_battlestate_effectsummaries_70675ddb6ef1,
        )
        summaries.appendPercent(.physical, basicCriticalBonus, resource: L10n.summary_battlestate_effectsummaries_19a8737b7c22)
        summaries.appendPreparedAmount(.physical, attackBonusOnFullHealth, resource: L10n.summary_battlestate_effectsummaries_e51d9d3d269a)
    }

    private func appendAdditionalPreparations(to summaries: inout [EffectSummary]) {
        summaries.appendPreparedAmount(.stun, nextDodgeStunAttackBonus, resource: L10n.summary_prepared_stun_attack_damage)
        summaries.appendPreparedAmount(.freeze, nextDodgeFreezeAttackBonus, resource: L10n.summary_prepared_freeze_attack_damage)
        summaries.appendPreparedAmount(.holy, nextPurgeHolyAttackBonus, resource: L10n.summary_prepared_holy_attack_damage)
        summaries.append(.bleed, when: doubleNextBleedAttack != nil, resource: L10n.summary_battlestate_effectsummaries_7340deb2cd68)
        summaries.append(.stun, when: nextStunAttackDouble != nil, resource: L10n.summary_battlestate_effectsummaries_d5bc64bc9bf9)
        summaries.append(
            .physical,
            when: doubleNextPhysicalAttack != nil,
            resource: L10n.summary_battlestate_effectsummaries_352adf9b122a,
        )
        summaries.append(.holy, when: nextHolyHitDouble != nil, resource: L10n.summary_battlestate_effectsummaries_f722041f3c1c)
        summaries.append(.physical, when: doubleNextAttackAfterDeathsDoor, resource: L10n.summary_battlestate_effectsummaries_9dc8204ddc95)
        summaries.append(.freeze, when: nextFreezeIgnoresBlock != nil, resource: L10n.summary_battlestate_effectsummaries_6f7bf645f094)
        summaries.append(.physical, when: nextAttackIgnoresBlock != nil, resource: L10n.summary_battlestate_effectsummaries_8f8f375bda71)
        summaries.append(.physical, when: nextStunPreparedCritical != nil, resource: L10n.summary_battlestate_effectsummaries_1468b273b1a7)
        let overchargePercent = overchargePercent?.value ?? 0
        let nextIncomingDamageMultiplier = nextIncomingDamageMultiplier?.value ?? 1
        summaries.appendPercent(.physical, overchargePercent, resource: L10n.summary_battlestate_effectsummaries_f5287ca2468b)
        summaries.appendPreparedMultiplier(
            .bleed,
            nextBleedAttackMultiplier,
            resource: L10n.summary_battlestate_effectsummaries_50369da7bf17,
        )
        summaries.appendPreparedMultiplier(
            .physical,
            nextPhysicalAttackMultiplier,
            resource: L10n.summary_battlestate_effectsummaries_5a2f1e053876,
        )
        summaries.appendPreparedMultiplier(
            .physical,
            nextCriticalHitMultiplier,
            resource: L10n.summary_battlestate_effectsummaries_9464195bf2a5,
        )
        summaries.appendPreparedAmount(.physical, nextManaSpendAttackBonus, resource: L10n.summary_battlestate_effectsummaries_464a634ebf36)
        appendDefensivePreparations(to: &summaries, incomingMultiplier: nextIncomingDamageMultiplier)
    }

    private func appendDefensivePreparations(to summaries: inout [EffectSummary], incomingMultiplier: Double) {
        summaries.appendPreparedMultiplier(.block, nextBlockGainMultiplier, resource: L10n.summary_battlestate_effectsummaries_18751f68cbcd)
        summaries.appendReduction(.block, incomingMultiplier, resource: L10n.summary_battlestate_effectsummaries_e410a469f407)
        summaries.appendReduction(.physical, nextOutgoingAttackMultiplier, resource: L10n.summary_battlestate_effectsummaries_95314c057098)
        summaries.appendReduction(.physical, concussionMultiplier, resource: L10n.summary_battlestate_effectsummaries_95314c057098)
        summaries.append(
            .dodge,
            when: nextAttackMissChance > 0,
            resource: L10n.summary_battlestate_effectsummaries_2240adc3884b(
                ContentCopy.resource(nextAttackMissAbilityName ?? "Blinding Light"),
                CombatRounding.rounded((nextAttackMissChance * 100).rounded()),
            ),
        )
    }
}

private extension [EffectSummary] {
    /// Inactive preparations must not format descriptions or allocate summary entries.
    mutating func append(_ keyword: Keyword, when active: Bool, resource: @autoclosure () -> LocalizedStringResource) {
        guard active else { return }
        append(EffectSummary(keyword: keyword, resource: resource()))
    }

    mutating func appendAmount(_ keyword: Keyword, _ amount: Int, resource: (Int) -> LocalizedStringResource) {
        guard amount > 0 else { return }
        append(EffectSummary(keyword: keyword, resource: resource(amount)))
    }

    mutating func appendPercent(_ keyword: Keyword, _ percent: Double, resource: (Int) -> LocalizedStringResource) {
        guard percent > 0 else { return }
        append(EffectSummary(keyword: keyword, resource: resource(CombatRounding.rounded((percent * 100).rounded()))))
    }

    mutating func appendPreparedAmount(
        _ keyword: Keyword, _ bonus: PreparedTalentBonus<Int>?, resource: (Int) -> LocalizedStringResource,
    ) {
        guard let bonus else { return }
        append(EffectSummary(keyword: keyword, resource: resource(bonus.value)))
    }

    mutating func appendPreparedMultiplier(
        _ keyword: Keyword, _ bonus: PreparedTalentBonus<Double>?, resource: (Int) -> LocalizedStringResource,
    ) {
        guard let bonus else { return }
        append(EffectSummary(keyword: keyword, resource: resource(CombatRounding.rounded(((bonus.value - 1) * 100).rounded()))))
    }

    mutating func appendReduction(_ keyword: Keyword, _ multiplier: Double, resource: (Int) -> LocalizedStringResource) {
        guard multiplier < 1 else { return }
        append(EffectSummary(keyword: keyword, resource: resource(CombatRounding.rounded(((1 - multiplier) * 100).rounded()))))
    }
}

import TrinketContent
import TrinketCore

/// Immutable attribution for one targeted effect. Battle mutation stays in the caller's state.
struct EffectApplication {
    let effect: Effect
    let ability: Ability
    let source: Combatant
    let target: Combatant

    // swiftlint:disable:next function_body_length - one exhaustive dispatch binds each Effect payload before applying its rules
    func apply(in context: inout BattleState) async -> EffectApplyOutcome {
        switch effect {
        case let .burn(potency), let .poison(potency):
            await context.applyDecayingDoT(
                keyword: effect.keyword,
                potency: potency,
                to: target,
                sourceActorID: source.id,
                application: .ability,
                provenance: context.resolution.damageProvenance(for: source.id),
            )
            return EffectApplyOutcome(didApply: true)
        case let .bleed(potency):
            let bleedsBefore = context.roster.activeEffects(for: target).count(where: \.effect.isBleed)
            await DoTApplicator.applyBleed(
                potency: potency,
                to: target,
                sourceActorID: source.id,
                application: .ability,
                provenance: context.resolution.damageProvenance(for: source.id),
                in: &context,
            )
            let didApply = context.roster.activeEffects(for: target).count(where: \.effect.isBleed) > bleedsBefore
            return EffectApplyOutcome(didApply: didApply)
        case let .controlMeter(keyword, amount, _):
            let outcome = await ControlMeterEngine.applyMeterCharge(
                amount, keyword: keyword, to: target, sourceActorID: source.id, in: &context,
            )
            return EffectApplyOutcome(didApply: outcome.didApply)
        case let .shield(_, amount):
            let gain = context.applyBlockGain(
                amount,
                to: target,
                source: source,
                abilityID: ability.id, abilityName: ability.name,
                origin: .direct,
            )
            return EffectApplyOutcome(didApply: gain > 0)
        case let .instantHeal(keyword, amount):
            var request = HealRequest(
                amount: amount, target: target, sourceActorID: source.id,
                origin: .restoration(keyword), logAs: .instantHeal(
                    source: .init(source),
                    abilityID: ability.id,
                    abilityName: ability.name,
                    keyword: keyword,
                ),
            )
            request.isDirectCardHeal = context.hasHeroCard(for: source.id)
            let outcome = await HealingEngine.resolveHeal(request, in: &context)
            return EffectApplyOutcome(didApply: outcome.healthRestored > 0)
        case let .resourceGain(.mana, amount):
            let restored = await restoreMana(amount, in: &context)
            return EffectApplyOutcome(didApply: true, restoredMana: restored)
        case let .resourceGain(.gold, amount):
            let gain = await context.grantGold(
                amount, to: source, abilityID: ability.id, abilityName: ability.name,
                isTheft: ability.stealsGold, isDirectCardGain: true,
            )
            return EffectApplyOutcome(didApply: true, grantedGold: gain)
        case .resourceGain: return EffectApplyOutcome(didApply: false)
        case .drawCards: return applyDrawCards(in: &context)
        case .drawAndPlayCards: return await applyDrawAndPlayCards(in: &context)
        case let .cleanse(keyword):
            return await EffectRemovalOperation.resolveCleanse(
                .all(keyword), source: source, target: target, abilityID: ability.id, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        case let .cleanseHealPerDebuff(healPerDebuff):
            return await EffectRemovalOperation.resolveCleanse(
                .all(nil), source: source, target: target, abilityID: ability.id, abilityName: ability.name,
                healPerDebuff: healPerDebuff, origin: .direct, in: &context,
            ).application
        case .cleanseRandom:
            return await EffectRemovalOperation.resolveCleanse(
                .randomDebuff, source: source, target: target, abilityID: ability.id, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        case let .purge(keyword):
            return await EffectRemovalOperation.resolvePurge(
                .all(keyword), source: source, target: target, abilityID: ability.id, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        case .purgeRandom:
            return await EffectRemovalOperation.resolvePurge(
                .randomBuffs(1), source: source, target: target, abilityID: ability.id, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        case let .panacea(baseHeal, healPerDebuff):
            let action = BattleActionContext(actor: source, in: context)
            let cleanseTarget = BattleActionContext.mostDebuffed(in: action.allies(in: context), state: context)
            return await EffectRemovalOperation.resolveCleanse(
                .all(nil), source: source, target: cleanseTarget, abilityID: ability.id, abilityName: ability.name,
                baseHeal: baseHeal, healPerDebuff: healPerDebuff,
                healTarget: .lowestHealthAlly, origin: .direct, in: &context,
            ).application
        case let .halveShield(keyword):
            guard DefensePoolEngine.halveBlock(on: target, in: &context) else {
                return EffectApplyOutcome(didApply: false)
            }
            emit(.shieldHalved, amount: 0, keyword: keyword, in: &context)
            return EffectApplyOutcome(didApply: true)
        case .deathsDoor: return EffectApplyOutcome(didApply: false)
        case .thorns, .nextBurnBonus: return applyStackingAmountBuff(in: &context)
        case let .thornsFromBlockFraction(divisor, minimum):
            guard divisor > 0 else {
                return EffectApplyOutcome(didApply: false)
            }
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target))
            let amount = max(minimum, block / divisor)
            guard amount > 0 else { return EffectApplyOutcome(didApply: false) }
            return replacingEffect(.thorns(amount)).applyStackingAmountBuff(in: &context)
        case .marked, .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride, .onHitDamage, .hemorrhage,
             .nextHolyStrike, .nextStrikeDouble, .playNextCardTwice, .evadeNextHit, .nextStrikeCritical,
             .nextStrikeLeech, .nextStrikeDamageKeywordOverride, .freezeNextAttacker: return applyStoredEffect(in: &context)
        case .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold: return await applyShieldFromResource(in: &context)
        case let .maximumManaBonus(amount):
            guard amount > 0 else {
                return EffectApplyOutcome(didApply: false)
            }
            guard context.insertEffect(
                .maximumManaBonus(amount),
                to: target,
                sourceID: source.id,
                remainingTurns: 0,
            ) else { return EffectApplyOutcome(didApply: false) }
            _ = await restoreMana(amount, in: &context)
            return EffectApplyOutcome(didApply: true)
        case let .partyDamageBonus(amount):
            guard amount > 0 else {
                return EffectApplyOutcome(didApply: false)
            }
            let recipient = BattleAbilityRules.preparationRecipient(for: source, in: context)
            context.resolution.preparePartyDamage(amount, recipientID: recipient.id)
            emit(.partyDamagePreparationApplied, amount: amount, keyword: .physical, target: recipient, in: &context)
            return EffectApplyOutcome(didApply: true)
        case .multiplyControlMeter: return await applyMultiplyControlMeter(in: &context)
        case .multiplyDoT: return applyMultiplyDoT(in: &context)
        case .detonateDoT: return await applyDetonateDoT(in: &context)
        case .recurringDamage: return await applyRecurringDamage(in: &context)
        case .avatar: return await applyAvatar(in: &context)
        case .blessedAegis: return await applyBlessedAegis(in: &context)
        case let .revive(health):
            guard health > 0 else {
                return EffectApplyOutcome(didApply: false)
            }
            let firstEventID = context.nextEventID
            context.reviveEmitting(
                target,
                health: health,
                source: source,
                abilityID: ability.id,
                abilityName: ability.name,
                origin: .direct,
            )
            return EffectApplyOutcome(didApply: context.nextEventID > firstEventID)
        case .damageReductionPercent, .damageReductionFlat, .healingReductionPercent:
            let applied = context.insertEffect(effect, to: target, sourceID: source.id, remainingTurns: effect.durationTurns)
            return EffectApplyOutcome(didApply: applied)
        }
    }

    func replacingEffect(_ effect: Effect, target: Combatant? = nil) -> Self {
        Self(effect: effect, ability: ability, source: source, target: target ?? self.target)
    }

    func emit(
        _ kind: ActionEvent.EffectOutcome, amount: Int, keyword: Keyword,
        target: Combatant? = nil, origin: ActionEvent.Origin = .direct,
        in context: inout BattleState,
    ) {
        context.nextEvent(
            kind: .effect(kind), source: .init(source),
            abilityID: ability.id, abilityName: ability.name, target: target ?? self.target,
            amount: amount, keyword: keyword, origin: origin,
        )
    }

    func store(
        replacing matches: (Effect) -> Bool,
        event: (kind: ActionEvent.EffectOutcome, amount: Int, keyword: Keyword),
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard context.insertEffect(
            effect, to: target, sourceID: source.id,
            remainingTurns: effect.durationTurns, replacing: matches,
        ) else { return EffectApplyOutcome(didApply: false) }
        emit(event.kind, amount: event.amount, keyword: event.keyword, in: &context)
        return EffectApplyOutcome(didApply: true)
    }

    private func restoreMana(_ amount: Int, in context: inout BattleState) async -> Int {
        let restored = context.restoreMana(context.paced(amount, sourceActorID: source.id), to: target)
        emit(.resourceGain, amount: restored, keyword: .mana, in: &context)
        await CombatTriggerEngine.manaRestorationReactions(for: target, restored: restored, in: &context)
        return restored
    }
}

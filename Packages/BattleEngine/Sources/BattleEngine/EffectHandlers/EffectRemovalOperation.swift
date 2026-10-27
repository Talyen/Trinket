import TrinketContent
import TrinketCore

/// Commits removals before resolving their Cleanse or Purge reactions.
enum EffectRemovalOperation {
    enum CleanseSelection {
        case all(Keyword?)
        case keywords(Set<Keyword>)
        case randomDebuff
    }

    enum PurgeSelection {
        case all(Keyword?)
        case randomBuffs(Int)
    }

    enum Propagation {
        case primary, secondary
    }

    struct Outcome {
        let removed: [ActiveEffect]
        let application: EffectApplyOutcome
    }

    /// One sorted per-keyword event per removal. Cleanse collapses duplicates
    /// to one event per keyword; purge reports every removed buff.
    static func emitRemovalEvents(
        _ removed: [ActiveEffect],
        effectKind: ActionEvent.EffectOutcome,
        source: Combatant,
        target: Combatant,
        abilityID: String = "",
        abilityName: String,
        origin: ActionEvent.Origin,
        in context: inout BattleState,
    ) {
        let keywords: [Keyword] = effectKind == .cleanseApplied
            ? EffectRemoval.distinctSortedKeywords(from: removed)
            : removed.lazy.map(\.keyword).sorted { $0.rawValue < $1.rawValue }
        for keyword in keywords {
            context.nextEvent(
                kind: .effect(effectKind),
                source: .init(source),
                abilityID: abilityID, abilityName: abilityName,
                target: target,
                amount: 0,
                keyword: keyword,
                origin: origin,
            )
        }
    }

    static func grantSecondaryCleanseDodge(
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) {
        let triggers = context.modifiers(for: source.id).triggers
        guard triggers.cleanseDodgeChanceBonus > 0 else { return }
        let duration = max(1, triggers.cleanseDodgeChanceBonusTurns)
        context.roster.mutateRuntime(for: target) {
            $0.talents.grantTimedDodge(
                triggers.cleanseDodgeChanceBonus,
                untilTurn: SaturatedArithmetic.saturatingAdd(context.turnCount, duration),
            )
        }
    }

    static func resolveCleanse(
        _ selection: CleanseSelection,
        source: Combatant,
        target: Combatant,
        abilityID: String = "",
        abilityName: String,
        baseHeal: Int = 0,
        healPerDebuff: Int = 0,
        healTarget: EffectTarget? = nil,
        propagation: Propagation = .primary,
        origin: ActionEvent.Origin = .automatic,
        in context: inout BattleState,
    ) async -> Outcome {
        var removed: [ActiveEffect] = []
        if let participant = context.roster.participant(for: target) {
            removed = switch selection {
            case let .all(keyword):
                EffectRemoval.removeDebuffs(from: &context.roster[participant].activeEffects, keyword: keyword)
            case let .keywords(keywords):
                EffectRemoval.removeDebuffs(from: &context.roster[participant].activeEffects, keywords: keywords)
            case .randomDebuff:
                EffectRemoval.removeRandomDebuff(from: &context.roster[participant].activeEffects, using: &context.rng).map { [$0] } ?? []
            }
            if !removed.isEmpty {
                let triggers = context.modifiers(for: source.id).triggers
                if triggers.cleanseRemovesFreezeBuildup {
                    removed.append(contentsOf: EffectRemoval.removeDebuffs(
                        from: &context.roster[participant].activeEffects,
                        keyword: .freeze,
                    ))
                }
                if triggers.firstCleanseExtraRemovalPerTurn > 0,
                   context.claimHeroTalent(.faeWard, actorID: source.id),
                   context.roster[participant].activeEffects.contains(where: \.effect.isRemovableDebuff),
                   let extra = EffectRemoval.removeRandomDebuff(from: &context.roster[participant].activeEffects, using: &context.rng) {
                    removed.append(extra)
                }
            }
        }
        for effect in removed {
            context.additionalControlSkipsByEffectID.removeValue(forKey: effect.id)
        }
        if let owner = context.roster.participant(for: target), owner.isPartyMember,
           !context.roster.hasPendingActionSkip(for: target) {
            context.ownersSkippingThisPlayerTurn.remove(owner)
        }
        let healAmount = SaturatedArithmetic.saturatingAdd(
            baseHeal, SaturatedArithmetic.saturatingMul(healPerDebuff, removed.count),
        )
        let firstEventID = context.nextEventID
        if !removed.isEmpty, propagation == .secondary {
            grantSecondaryCleanseDodge(source: source, target: target, in: &context)
        }

        if !removed.isEmpty, source.role != .enemy, target.role != .enemy,
           context.modifiers(for: source.id).triggers.clearMind,
           context.roster.runtime(for: source)?.currentMana == 0,
           let owner = context.roster.participant(for: source) {
            CombatTriggerEngine.drawCards(1, for: owner, actor: source, abilityName: "Clear Mind", in: &context)
        }
        await cleanseReactions(
            removed: removed, abilityID: abilityID, abilityName: abilityName, source: source, target: target,
            healAmount: healAmount, healTarget: healTarget,
            allowMassCleanse: propagation == .primary, origin: origin, in: &context,
        )
        // Panacea can apply healing even when there was nothing to remove.
        return Outcome(removed: removed, application: EffectApplyOutcome(didApply: !removed.isEmpty || context.nextEventID > firstEventID))
    }

    private static func cleanseReactions(
        removed: [ActiveEffect],
        abilityID: String = "",
        abilityName: String,
        source: Combatant,
        target: Combatant,
        healAmount: Int,
        healTarget: EffectTarget? = nil,
        allowMassCleanse: Bool = true,
        origin: ActionEvent.Origin,
        in context: inout BattleState,
    ) async {
        let triggers = context.modifiers(for: source.id).triggers
        await CombatTriggerEngine.afterHeroCleanse(source: source, target: target, removed: removed.map(\.keyword), in: &context)
        emitRemovalEvents(
            removed, effectKind: .cleanseApplied, source: source, target: target,
            abilityID: abilityID, abilityName: abilityName, origin: origin, in: &context,
        )
        // Removal is committed even when its first reaction defeats the cleanser.
        guard context.roster.health(for: source) > 0 else { return }
        if healAmount > 0 {
            let recipient = healTarget.map { BattleActionContext(actor: source, in: context).target($0, in: context) } ?? target
            await context.healEmitting(
                amount: healAmount,
                target: recipient,
                source: source,
                abilityID: abilityID, abilityName: abilityName,
                isDirectCardHeal: context.hasHeroCard(for: source.id),
            )
        }
        guard !removed.isEmpty, context.roster.health(for: source) > 0 else { return }
        if context.roster.health(for: target) < context.roster.maxHealth(for: target) {
            _ = await CombatTriggerEngine.resolveBonusHeal(amount: triggers.cleanseBonusHeal, source: source, target: target, in: &context)
        }
        guard context.roster.health(for: source) > 0 else { return }
        _ = await CombatTriggerEngine.resolveBonusHeal(
            amount: triggers.cleanseSelfHeal, source: source,
            target: BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context), in: &context,
        )
        guard context.roster.health(for: source) > 0 else { return }
        CombatTriggerEngine.drawAfterCleanse(source: source, removedCount: removed.count, in: &context)
        await CombatTriggerEngine.afterCleanseAction(
            source: source,
            target: target,
            removedCount: removed.count,
            allowMassCleanse: allowMassCleanse,
            in: &context,
        )
        guard context.roster.health(for: source) > 0 else { return }
        await CombatTriggerEngine.toxicBacklashDamage(
            source: source, removedCount: removed.count(where: { $0.keyword == .poison }), in: &context,
        )
        guard context.roster.health(for: source) > 0 else { return }
        await CombatTriggerEngine.reflectCleansedEffects(removed, source: source, in: &context)
    }

    static func resolvePurge(
        _ selection: PurgeSelection,
        source: Combatant,
        target: Combatant,
        abilityID: String = "",
        abilityName: String,
        origin: ActionEvent.Origin = .automatic,
        in context: inout BattleState,
    ) async -> Outcome {
        // Purge-only by design: sealedSarcophagus guards .shield Block, which
        // is always a removable buff. Cleanse strips debuffs, so the flag
        // would be meaningless on that path.
        let preservingBlock = context.modifiers(for: target.id).triggers.sealedSarcophagus
        var removed: [ActiveEffect] = []
        if let participant = context.roster.participant(for: target) {
            removed = switch selection {
            case let .all(keyword):
                EffectRemoval.removeBuffs(
                    from: &context.roster[participant].activeEffects,
                    keyword: keyword,
                    preservingBlock: preservingBlock,
                )
            case let .randomBuffs(count):
                EffectRemoval.removeBuffs(
                    from: &context.roster[participant].activeEffects, count: count, preservingBlock: preservingBlock, using: &context.rng,
                )
            }
        }
        guard !removed.isEmpty else {
            return Outcome(removed: [], application: EffectApplyOutcome(didApply: false))
        }
        CombatTriggerEngine.protectPurgedEffects(removed, source: source, target: target, in: &context)
        let triggers = context.modifiers(for: source.id).triggers
        emitRemovalEvents(
            removed, effectKind: .purgeApplied, source: source, target: target,
            abilityID: abilityID, abilityName: abilityName, origin: origin, in: &context,
        )
        if target.role == .enemy, source.role != .enemy, triggers.purgeDrawBelowHalf,
           let runtime = context.roster.runtime(for: source), runtime.isAlive,
           runtime.isBelowHalfHealth,
           let owner = context.roster.participant(for: source) {
            CombatTriggerEngine.drawCards(1, for: owner, actor: source, abilityName: "Smite the Wicked", in: &context)
        }
        await CombatTriggerEngine.crownfallDamage(removedCount: removed.count, source: source, target: target, in: &context)
        if target.role == .enemy, context.roster.health(for: source) > 0 {
            if triggers.onPurgeGainBlock > 0 {
                context.applyBlockGain(
                    triggers.onPurgeGainBlock,
                    to: source, source: source,
                    abilityName: context.modifiers(for: source.id).triggerAbilityName(
                        .onPurgeGainBlock, fallback: "Unraveling",
                    ),
                )
            }
            context.prepareAttackBonus(triggers.purgeNextHolyAttackBonus, \.nextPurgeHolyAttackBonus, for: source)
        }
        return Outcome(removed: removed, application: EffectApplyOutcome(didApply: true))
    }
}

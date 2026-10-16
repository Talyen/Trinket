import TrinketContent
import TrinketCore

/// Single owner for stripping effects: cleanse removes debuffs, purge removes buffs.
/// Previously two near-duplicate operations (`CleanseOperation`, `PurgeOperation`) with
/// identical `Outcome` shapes and per-keyword event loops. The two paths stay separate
/// below because their side effects differ on purpose: cleanse fans out to heal/draw/
/// reflect reactions and reports heal-only empty removals as applied (Panacea), while
/// purge only guards Block (`sealedSarcophagus`) and reports empty removals as unapplied.
enum EffectRemovalOperation {
    enum CleanseSelection {
        case all(Keyword?)
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
            : removed.map(\.keyword).sorted { $0.rawValue < $1.rawValue }
        _ = keywords.map { keyword in
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

    /// Secondary-propagation dodge grant shared by the cleanse resolve path and the
    /// mass-cleanse party reaction (previously duplicated in both places).
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
        var effects = context.roster.activeEffects(for: target)
        var removed: [ActiveEffect] = switch selection {
        case let .all(keyword): EffectRemoval.removeDebuffs(from: &effects, keyword: keyword)
        case .randomDebuff: EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng).map { [$0] } ?? []
        }
        if !removed.isEmpty {
            let triggers = context.modifiers(for: source.id).triggers
            if triggers.cleanseRemovesFreezeBuildup {
                removed.append(contentsOf: EffectRemoval.removeDebuffs(from: &effects, keyword: .freeze))
            }
            if triggers.firstCleanseExtraRemovalPerTurn > 0,
               context.claimHeroTalent(.faeWard, actorID: source.id),
               effects.contains(where: \.effect.isRemovableDebuff),
               let extra = EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng) {
                removed.append(extra)
            }
        }
        context.roster.setActiveEffects(effects, for: target)
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
        // Empty-removal still reports heal/side-effect events as applied
        // (Panacea heal-only case). Purge has no such side effects, so its
        // empty path reports didApply:false. The asymmetry is intentional.
        guard !removed.isEmpty else {
            await CombatTriggerEngine.afterHeroCleanse(source: source, target: target, removed: [], in: &context)
            if healAmount > 0, context.roster.health(for: source) > 0 {
                let recipient = healTarget.map { BattleActionContext(actor: source, in: context).target($0, in: context) } ?? target
                await context.healEmitting(
                    amount: healAmount, target: recipient, source: source, abilityID: abilityID, abilityName: abilityName,
                    isDirectCardHeal: context.hasHeroCard(for: source.id),
                )
            }
            return Outcome(removed: [], application: EffectApplyOutcome(didApply: context.nextEventID > firstEventID))
        }
        if propagation == .secondary {
            grantSecondaryCleanseDodge(source: source, target: target, in: &context)
        }

        if source.role != .enemy, target.role != .enemy,
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
        return Outcome(removed: removed, application: EffectApplyOutcome(didApply: true))
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
        let orderedKeywords = EffectRemoval.distinctSortedKeywords(from: removed)
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
        guard context.roster.health(for: source) > 0 else { return }
        _ = await CombatTriggerEngine.bonusHealAfterCleanse(
            source: source, target: target, amount: triggers.cleanseBonusHeal, requireWoundedTarget: true, in: &context,
        )
        guard context.roster.health(for: source) > 0 else { return }
        _ = await CombatTriggerEngine.bonusHealAfterCleanse(
            source: source, target: BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context),
            amount: triggers.cleanseSelfHeal, requireWoundedTarget: false, in: &context,
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
        for keyword in orderedKeywords {
            guard context.roster.health(for: source) > 0 else { return }
            await CombatTriggerEngine.afterCleanseKeywordReaction(
                source: source,
                removedKeyword: keyword,
                removedCount: removed.count(where: { $0.keyword == keyword }),
                in: &context,
            )
        }
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
        var effects = context.roster.activeEffects(for: target)
        // Purge-only by design: sealedSarcophagus guards .shield Block, which
        // is always a removable buff. Cleanse strips debuffs, so the flag
        // would be meaningless on that path.
        let preservingBlock = context.modifiers(for: target.id).triggers.sealedSarcophagus
        let removed: [ActiveEffect] = switch selection {
        case let .all(keyword):
            EffectRemoval.removeBuffs(from: &effects, keyword: keyword, preservingBlock: preservingBlock)
        case let .randomBuffs(count):
            EffectRemoval.removeBuffs(from: &effects, count: max(0, count), preservingBlock: preservingBlock, using: &context.rng)
        }
        guard !removed.isEmpty else {
            return Outcome(removed: [], application: EffectApplyOutcome(didApply: false))
        }
        context.roster.setActiveEffects(effects, for: target)
        CombatTriggerEngine.protectPurgedEffects(removed, source: source, target: target, in: &context)
        let triggers = context.modifiers(for: source.id).triggers
        // One event per removed buff (sorted for determinism), so direct
        // purges report what was actually removed instead of collapsing to
        // a single generic line. This matches the long-standing triggered
        // path; only the direct `.all` path changes. `origin` is
        // intentionally ignored for the keyword choice.
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

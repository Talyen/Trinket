import TrinketContent
import TrinketCore

/// Single owner for stripping effects: cleanse removes debuffs, purge removes buffs.
/// Previously two near-duplicate operations (`CleanseOperation`, `PurgeOperation`) with
/// identical `Outcome` shapes and per-keyword event loops. The two paths stay separate
/// below because their side effects differ on purpose: cleanse fans out to heal/draw/
/// reflect reactions and reports heal-only empty removals as applied (Panacea), while
/// purge only guards Block (`sealedSarcophagus`) and reports empty removals as unapplied.
enum EffectRemovalOperation {
    enum Selection {
        case all(Keyword?)
        case randomDebuff
        case randomBuffs(Int)
    }

    enum Propagation {
        case primary, secondary
    }

    struct Outcome {
        let removed: [ActiveEffect]
        let application: EffectApplyOutcome
        var events: [ActionEvent] {
            application.events
        }
    }

    /// One sorted per-keyword event per removal. Cleanse collapses duplicates
    /// to one event per keyword; purge reports every removed buff.
    static func removalEvents(
        _ removed: [ActiveEffect],
        effectKind: ActionEvent.EffectOutcome,
        source: Combatant,
        target: Combatant,
        abilityName: String,
        origin: ActionEvent.Origin,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let keywords: [Keyword] = effectKind == .cleanseApplied
            ? EffectRemoval.distinctSortedKeywords(from: removed)
            : removed.map(\.keyword).sorted { $0.rawValue < $1.rawValue }
        return keywords.map { keyword in
            context.nextEvent(
                kind: .effect,
                effectKind: effectKind,
                actorName: source.name,
                abilityName: abilityName,
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
            $0.talents.grantTimedDodge(triggers.cleanseDodgeChanceBonus, untilTurn: context.turnCount + duration)
        }
    }

    static func resolveCleanse(
        _ selection: Selection,
        source: Combatant,
        target: Combatant,
        abilityName: String,
        baseHeal: Int = 0,
        healPerDebuff: Int = 0,
        healTarget: Combatant? = nil,
        propagation: Propagation = .primary,
        origin: ActionEvent.Origin = .automatic,
        in context: inout BattleState,
    ) -> Outcome {
        var effects = context.roster.activeEffects(for: target)
        var removed: [ActiveEffect] = switch selection {
        case let .all(keyword): EffectRemoval.removeDebuffs(from: &effects, keyword: keyword)
        case .randomDebuff: EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng).map { [$0] } ?? []
        case let .randomBuffs(count):
            EffectRemoval.removeBuffs(
                from: &effects, count: count, preservingBlock: false, using: &context.rng,
            )
        }
        if !removed.isEmpty {
            let triggers = context.modifiers(for: source.id).triggers
            if triggers.cleanseRemovesFreezeBuildup {
                removed.append(contentsOf: EffectRemoval.removeDebuffs(from: &effects, keyword: .freeze))
            }
            if triggers.firstCleanseExtraRemovalPerTurn > 0,
               context.claimHeroTalent("Fae Ward", actorID: source.id),
               effects.contains(where: \.effect.isRemovableDebuff),
               let extra = EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng) {
                removed.append(extra)
            }
        }
        context.roster.setActiveEffects(effects, for: target)
        if let owner = context.roster.participant(for: target), owner.isPartyMember,
           !context.roster.hasPendingActionSkip(for: target) {
            context.ownersSkippingThisPlayerTurn.remove(owner)
        }
        let healAmount = baseHeal + healPerDebuff * removed.count
        // Empty-removal still reports heal/side-effect events as applied
        // (Panacea heal-only case). Purge has no such side effects, so its
        // empty path reports didApply:false. The asymmetry is intentional.
        guard !removed.isEmpty else {
            var events = CombatTriggerEngine.afterHeroCleanse(source: source, target: target, removed: [], in: &context)
            if healAmount > 0 {
                events.append(contentsOf: context.healEmitting(
                    amount: healAmount, target: healTarget ?? target, source: source, abilityName: abilityName,
                    isDirectCardHeal: context.hasHeroCard(for: source.id),
                ))
            }
            return Outcome(removed: [], application: EffectApplyOutcome(events: events, didApply: !events.isEmpty))
        }
        if propagation == .secondary {
            grantSecondaryCleanseDodge(source: source, target: target, in: &context)
        }
        let events = cleanseReactions(
            removed: removed, abilityName: abilityName, source: source, target: target,
            healAmount: healAmount, healTarget: healTarget ?? target,
            allowMassCleanse: propagation == .primary, origin: origin, in: &context,
        )
        return Outcome(removed: removed, application: EffectApplyOutcome(events: events, didApply: true))
    }

    private static func cleanseReactions(
        removed: [ActiveEffect],
        abilityName: String,
        source: Combatant,
        target: Combatant,
        healAmount: Int? = nil,
        healTarget: Combatant? = nil,
        allowMassCleanse: Bool = true,
        origin: ActionEvent.Origin = .automatic,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        let orderedKeywords = EffectRemoval.distinctSortedKeywords(from: removed)
        var events = CombatTriggerEngine.afterHeroCleanse(
            source: source, target: target, removed: removed.map(\.keyword), in: &context,
        )
        events.append(contentsOf: removalEvents(
            removed, effectKind: .cleanseApplied, source: source, target: target,
            abilityName: abilityName, origin: origin, in: &context,
        ))
        if let healAmount, let healTarget, healAmount > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: healAmount,
                target: healTarget,
                source: source,
                abilityName: abilityName,
                isDirectCardHeal: context.hasHeroCard(for: source.id),
            ))
        }
        events.append(contentsOf: CombatTriggerEngine.bonusHealAfterCleanse(
            source: source, amount: triggers.cleanseBonusHeal, requireWoundedTarget: true, in: &context,
        ).events)
        events.append(contentsOf: CombatTriggerEngine.bonusHealAfterCleanse(
            source: source, amount: triggers.cleanseSelfHeal, requireWoundedTarget: false, in: &context,
        ).events)
        events.append(contentsOf: CombatTriggerEngine.drawAfterCleanse(source: source, removedCount: removed.count, in: &context))
        events.append(contentsOf: CombatTriggerEngine.afterCleanseAction(
            source: source,
            target: target,
            removedCount: removed.count,
            allowMassCleanse: allowMassCleanse,
            in: &context,
        ))
        for keyword in orderedKeywords {
            events.append(contentsOf: CombatTriggerEngine.afterCleanseKeywordReaction(
                source: source,
                removedKeyword: keyword,
                removedCount: removed.count(where: { $0.keyword == keyword }),
                in: &context,
            ))
        }
        events.append(contentsOf: CombatTriggerEngine.reflectCleansedEffects(removed, source: source, in: &context))
        return events
    }

    static func resolvePurge(
        _ selection: Selection,
        source: Combatant,
        target: Combatant,
        abilityName: String,
        origin: ActionEvent.Origin = .automatic,
        in context: inout BattleState,
    ) -> Outcome {
        var effects = context.roster.activeEffects(for: target)
        // Purge-only by design: sealedSarcophagus guards .shield Block, which
        // is always a removable buff. Cleanse strips debuffs, so the flag
        // would be meaningless on that path.
        let preservingBlock = context.modifiers(for: target.id).triggers.sealedSarcophagus
        let removed: [ActiveEffect] = switch selection {
        case let .all(keyword):
            EffectRemoval.removeBuffs(from: &effects, keyword: keyword, preservingBlock: preservingBlock)
        case .randomDebuff:
            EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng).map { [$0] } ?? []
        case let .randomBuffs(count):
            EffectRemoval.removeBuffs(from: &effects, count: max(0, count), preservingBlock: preservingBlock, using: &context.rng)
        }
        guard !removed.isEmpty else {
            return Outcome(removed: [], application: EffectApplyOutcome(events: [], didApply: false))
        }
        context.roster.setActiveEffects(effects, for: target)
        CombatTriggerEngine.protectPurgedEffects(removed, source: source, target: target, in: &context)
        let triggers = context.modifiers(for: source.id).triggers
        if target.role == .enemy, triggers.purgePreparesDoubleHolyAttack {
            context.roster.mutateRuntime(for: source) { $0.talents.pending.doubleNextHolyAttack = true }
        }
        // One event per removed buff (sorted for determinism), so direct
        // purges report what was actually removed instead of collapsing to
        // a single generic line. This matches the long-standing triggered
        // path; only the direct `.all` path changes. `origin` is
        // intentionally ignored for the keyword choice.
        var events = removalEvents(
            removed, effectKind: .purgeApplied, source: source, target: target,
            abilityName: abilityName, origin: origin, in: &context,
        )
        events.append(contentsOf: CombatTriggerEngine.crownfallDamage(
            removedCount: removed.count, source: source, target: target, in: &context,
        ))
        if target.role == .enemy, context.roster.health(for: source) > 0 {
            if triggers.onPurgeGainBlock > 0 {
                events.append(contentsOf: context.applyBlock(
                    triggers.onPurgeGainBlock,
                    to: source, source: source,
                    abilityName: context.modifiers(for: source.id).triggerAbilityName(
                        "onPurgeGainBlock", fallback: "Unraveling",
                    ),
                ))
            }
            if triggers.onPurgeDealHolyDamage > 0, context.roster.enemy.isAlive {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: triggers.onPurgeDealHolyDamage,
                        target: target, keyword: .holy, sourceActorID: source.id,
                        options: .reaction(),
                    ),
                ).events)
            }
        }
        return Outcome(removed: removed, application: EffectApplyOutcome(events: events, didApply: true))
    }
}

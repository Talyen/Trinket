import TrinketContent
import TrinketCore

enum PurgeOperation {
    enum Selection {
        case all(Keyword?)
        case randomBuffs(Int)
    }

    struct Outcome {
        let removed: [ActiveEffect]
        let application: EffectApplyOutcome

        var events: [ActionEvent] {
            application.events
        }
    }

    static func resolve(
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
        case let .randomBuffs(count):
            EffectRemoval.removeBuffs(from: &effects, count: max(0, count), preservingBlock: preservingBlock, using: &context.rng)
        }
        guard !removed.isEmpty else {
            return Outcome(removed: [], application: EffectApplyOutcome(events: [], didApply: false))
        }
        context.roster.setActiveEffects(effects, for: target)
        CombatTriggerEngine.protectPurgedEffects(removed, source: source, target: target, in: &context)
        if target.role == .enemy,
           context.modifiers(for: source.id).triggers.purgePreparesDoubleHolyAttack {
            context.roster.mutateRuntime(for: source) { $0.talents.pending.doubleNextHolyAttack = true }
        }
        // One event per removed buff (sorted for determinism), so direct
        // purges report what was actually removed instead of collapsing to
        // a single generic line. This matches the long-standing triggered
        // path; only the direct `.all` path changes. `origin` is
        // intentionally ignored for the keyword choice.
        let keywords = removed.map(\.keyword).sorted { $0.rawValue < $1.rawValue }
        var events = keywords.map { keyword in
            context.nextEvent(
                kind: .effect, effectKind: .purgeApplied,
                actorName: source.name, abilityName: abilityName, target: target,
                amount: 0, keyword: keyword, origin: origin,
            )
        }
        events.append(contentsOf: CombatTriggerEngine.crownfallDamage(
            removedCount: removed.count, source: source, target: target, in: &context,
        ))
        if target.role == .enemy, context.roster.health(for: source) > 0 {
            let triggers = context.modifiers(for: source.id).triggers
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

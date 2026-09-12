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
        let keywords: [Keyword] = if case let .all(keyword) = selection, origin == .direct {
            [keyword ?? .purge]
        } else {
            removed.map(\.keyword)
        }
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
        return Outcome(removed: removed, application: EffectApplyOutcome(events: events, didApply: true))
    }
}

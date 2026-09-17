import Foundation
import TrinketContent
import TrinketCore

struct AvatarHandler: BattleEffectHandler {
    let kind: EffectKind = .avatar

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .avatar(holyDamage, blockPerTurn, _) = active.effect
        else { return nil }
        if blockPerTurn > 0 {
            return EffectSummary(
                keyword: keyword,
                text: "Avatar: Deals \(holyDamage) Holy damage and gains \(blockPerTurn) Block each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns)).",
            )
        }
        return EffectSummary(
            keyword: keyword,
            text: "Avatar: Deals \(holyDamage) Holy damage each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns)).",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .avatar(holyDamage, blockPerTurn, turns) = effect,
              holyDamage > 0, blockPerTurn >= 0, turns > 0
        else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let application = ActiveEffectMutation.replaceAndEmit(
            .avatar(holyDamage: holyDamage, blockPerTurn: blockPerTurn, turns: turns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .avatar },
            event: (.avatarApplied, holyDamage, .holy),
        )
        guard application.didApply else { return application }
        let events = pulse(
            holyDamage: holyDamage,
            blockPerTurn: blockPerTurn,
            from: target,
            provenance: context.resolution.damageProvenance(for: source.id),
            in: &context,
        )
        return EffectApplyOutcome(events: application.events + events, didApply: true)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard case let .avatar(holyDamage, blockPerTurn, _) = active.effect,
              active.remainingTurns > 0
        else {
            return []
        }
        let events = pulse(
            holyDamage: holyDamage,
            blockPerTurn: blockPerTurn,
            from: target,
            in: &context,
        )
        if var updated = context.roster.activeEffects(for: target).first(where: { $0.id == active.id }) {
            updated.remainingTurns -= 1
            ActiveEffectMutation.finishTurn(
                active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
            )
        }
        return events
    }

    private func pulse(
        holyDamage: Int,
        blockPerTurn: Int,
        from caster: Combatant,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let opponent = BattleTargetResolver.abilityTarget(for: caster, in: context)
        var events = DoTDamage.resolveDamage(
            basePotency: holyDamage,
            keyword: .holy,
            target: opponent,
            sourceActorID: caster.id,
            provenance: provenance,
            in: &context,
        ).events
        if blockPerTurn > 0 {
            events.append(contentsOf: context.applyBlock(
                blockPerTurn,
                to: caster,
                source: caster,
                abilityName: "Avatar",
            ))
        }
        return events
    }
}

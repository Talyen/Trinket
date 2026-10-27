import Foundation
import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func summarizeAvatar(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .avatar(holyDamage, blockPerTurn, _) = active.effect
        else { return nil }
        let blockClause = blockPerTurn > 0 ? L10n.summary_avatarhandler_e8766418d22b(blockPerTurn) : L10n.summary_avatarhandler_3ff4038b7d8e
        return EffectSummary(
            keyword: keyword,
            resource: L10n.summary_avatarhandler_a9e78e0afef2(
                holyDamage,
                blockClause,
                BattleTiming.remainingDurationResource(turns: active.remainingTurns),
            ),
        )
    }

    static func advanceAvatar(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) async {
        guard case let .avatar(holyDamage, blockPerTurn, _) = active.effect,
              active.remainingTurns > 0
        else {
            return
        }
        await pulseAvatar(holyDamage: holyDamage, blockPerTurn: blockPerTurn, from: target, in: &context)
        ActiveEffectMutation.finishPulsedTurn(active, on: target, in: &context)
    }

    static func pulseAvatar(
        holyDamage: Int,
        blockPerTurn: Int,
        from caster: Combatant,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) async {
        let opponent = BattleActionContext(actor: caster, in: context).selectedTarget
        _ = await DoTDamage.resolveDamage(
            basePotency: holyDamage,
            keyword: .holy,
            target: opponent,
            sourceActorID: caster.id,
            provenance: provenance,
            in: &context,
        )
        if blockPerTurn > 0 {
            context.applyBlockGain(blockPerTurn, to: caster, source: caster, abilityName: "Avatar")
        }
    }
}

extension EffectApplication {
    func applyAvatar(in context: inout BattleState) async -> EffectApplyOutcome {
        guard case let .avatar(holyDamage, blockPerTurn, turns) = effect,
              holyDamage > 0, blockPerTurn >= 0, turns > 0
        else {
            return EffectApplyOutcome(didApply: false)
        }
        let application = store(
            replacing: { $0.kind == .avatar },
            event: (.avatarApplied, holyDamage, .holy),
            in: &context,
        )
        guard application.didApply else { return application }
        await EffectHandlers.pulseAvatar(
            holyDamage: holyDamage,
            blockPerTurn: blockPerTurn,
            from: target,
            provenance: context.resolution.damageProvenance(for: source.id),
            in: &context,
        )

        return EffectApplyOutcome(didApply: true)
    }
}

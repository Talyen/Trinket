import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // swiftlint:disable:next function_body_length - shield resolution is one ordered mutation step
    static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        assert(
            state.buildupDamage == state.remaining || state.remaining == 0,
            "buildupDamage invariant before shield: buildup \(state.buildupDamage) != remaining \(state.remaining)",
        )
        var effects = context.roster.activeEffects(for: state.combatant)

        let blockMultiplier = DamageDefensePolicy.blockMultiplier(state: state, in: context)
        guard blockMultiplier > 0 else { return }

        applyIntercede(to: &state, blockMultiplier: blockMultiplier, in: &context)
        effects = context.roster.activeEffects(for: state.combatant)

        guard let index = effects.firstIndex(where: {
            if case .shield = $0.effect {
                return true
            }; return false
        }),
            case let .shield(keyword, buffer) = effects[index].effect,
            buffer > 0,
            state.remaining > 0,
            !state.options.isHealthCost
        else {
            return
        }

        let sourceTriggers = state.sourceActorID.map { context.modifiers(for: $0).triggers }
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        let targetIsStunned = state.targetStatus.isStunned
        let targetIsFrozen = state.targetStatus.isFrozen

        let effectiveBuffer = max(0, CombatRounding.scaled(buffer, multiplier: blockMultiplier) - state.heroCardBlockIgnore)
        guard effectiveBuffer > 0, state.remaining > 0 else {
            return
        }

        let absorption = applyAbsorption(
            to: &state,
            keyword: keyword,
            buffer: buffer,
            effectiveBuffer: effectiveBuffer,
            sourceTriggers: sourceTriggers,
            targetIsStunned: targetIsStunned,
            in: &context,
        )

        var blockBroken = false
        if let reduced = DefensePoolEngine.reduce(
            absorption.absorbed + absorption.extraRemoved,
            in: effects,
        ) {
            effects = reduced.effects
            blockBroken = reduced.broken
        }
        state.heroCardBlockBroken = blockBroken
        context.roster.setActiveEffects(effects, for: state.combatant)

        state.damageEvents.append(contentsOf: applyBlockAbsorptionReactions(
            absorbed: absorption.absorbed,
            blockBroken: blockBroken,
            defenderTriggers: defenderTriggers,
            sourceTriggers: sourceTriggers,
            to: &state,
            in: &context,
        ))
        state.damageEvents.append(contentsOf: handleTalentBlockedDamage(
            absorbed: absorption.absorbed,
            defender: state.combatant,
            attackerID: state.sourceActorID,
            in: &context,
        ))
        applyOverflowAndBreakReactions(blockBroken: blockBroken, defenderTriggers: defenderTriggers, to: &state, in: &context)
    }

    private static func applyOverflowAndBreakReactions(
        blockBroken: Bool,
        defenderTriggers: CombatTraitTriggers,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.remaining > 0, defenderTriggers.postBlockOverflowDamageMultiplier != 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: defenderTriggers.postBlockOverflowDamageMultiplier,
            )
        }

        if blockBroken {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBlockBroken(
                on: state.combatant,
                attackerID: state.sourceActorID,
                in: &context,
            ))
        }
    }

    private struct ShieldAbsorption {
        var absorbed: Int
        var extraRemoved: Int
    }

    private static func applyAbsorption(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        buffer: Int,
        effectiveBuffer: Int,
        sourceTriggers: CombatTraitTriggers?,
        targetIsStunned: Bool,
        in context: inout BattleState,
    ) -> ShieldAbsorption {
        let absorbed = min(state.remaining, effectiveBuffer)
        state.blockedAmount += absorbed
        state.buildupDamage = max(0, state.buildupDamage - absorbed)
        appendAbsorption(
            absorbed,
            abilityName: keyword.rawValue,
            keyword: keyword,
            actorName: keyword.rawValue,
            target: state.combatant,
            to: &state,
            in: &context,
        )
        let extraRemoved = extraBlockRemoval(
            absorbed: absorbed,
            buffer: buffer,
            sourceTriggers: sourceTriggers,
            targetIsStunned: targetIsStunned,
            damageKeyword: state.damageKeyword,
        )
        return ShieldAbsorption(absorbed: absorbed, extraRemoved: extraRemoved)
    }

    private static func applyIntercede(
        to state: inout DamageResolutionState,
        blockMultiplier: Double,
        in context: inout BattleState,
    ) {
        guard state.combatant.role == .companion,
              state.remaining > 0,
              context.roster.hero.isAlive,
              context.heroModifiers.triggers.blockAbsorbsCompanionDamage
        else { return }
        let heroEffects = context.roster.activeEffects(for: context.roster.hero.combatant)
        let available = CombatRounding.scaled(DefensePoolEngine.blockPoints(in: heroEffects), multiplier: blockMultiplier)
        guard let reduced = DefensePoolEngine.reduce(min(state.remaining, available), in: heroEffects)
        else { return }
        let heroAbsorbed = reduced.absorbed
        state.blockedAmount += heroAbsorbed
        state.buildupDamage = max(0, state.buildupDamage - heroAbsorbed)
        appendAbsorption(
            heroAbsorbed,
            abilityName: "Intercede",
            keyword: reduced.keyword,
            actorName: reduced.keyword.rawValue,
            target: context.roster.hero.combatant,
            to: &state,
            in: &context,
        )
        context.roster.setActiveEffects(reduced.effects, for: context.roster.hero.combatant)
        state.damageEvents.append(contentsOf: handleTalentBlockedDamage(
            absorbed: heroAbsorbed,
            defender: context.roster.hero.combatant,
            attackerID: state.sourceActorID,
            in: &context,
        ))
        if reduced.broken {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBlockBroken(
                on: context.roster.hero.combatant,
                attackerID: state.sourceActorID,
                in: &context,
            ))
        }
    }

    private static func handleTalentBlockedDamage(
        absorbed: Int,
        defender: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard absorbed > 0, defender.role != .enemy, let attackerID,
              let attacker = context.roster.combatant(for: attackerID)
        else { return [] }
        var events: [ActionEvent] = []
        if defenderTriggersContainStoredImpact(in: context, defender: defender) {
            context.storedBlockedDamageByActorID[defender.id, default: 0] += absorbed
        }
        if hasSeismicReversal(in: context, defender: defender) {
            events.append(contentsOf: dealTalentDamage(
                absorbed,
                keyword: .stun,
                target: attacker.combatant,
                source: defender,
                in: &context,
            ))
        }
        if hasGlacialReprieve(in: context, defender: defender) {
            events.append(contentsOf: dealTalentDamage(
                absorbed,
                keyword: .freeze,
                target: attacker.combatant,
                source: defender,
                in: &context,
            ))
        }
        return events
    }

    private static func partyTrigger(
        _ keyPath: KeyPath<CombatTraitTriggers, Bool>,
        defender: Combatant,
        in context: BattleState,
    ) -> Bool {
        context.modifiers(for: defender.id).triggers[keyPath: keyPath]
            || CombatTriggerEngine.hasLivingPartyTrigger(keyPath, in: context)
    }

    private static func defenderTriggersContainStoredImpact(in context: BattleState, defender: Combatant) -> Bool {
        partyTrigger(\.storedImpact, defender: defender, in: context)
    }

    private static func hasSeismicReversal(in context: BattleState, defender: Combatant) -> Bool {
        partyTrigger(\.seismicReversal, defender: defender, in: context)
    }

    private static func hasGlacialReprieve(in context: BattleState, defender: Combatant) -> Bool {
        partyTrigger(\.glacialReprieve, defender: defender, in: context)
    }

    private static func dealTalentDamage(
        _ amount: Int,
        keyword: Keyword,
        target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: target) > 0 else { return [] }
        return resolveRetaliation(
            amount: amount,
            keyword: keyword,
            target: target,
            sourceActorID: source.id,

            in: &context,
        ).events
    }

    private static func extraBlockRemoval(
        absorbed: Int,
        buffer: Int,
        sourceTriggers: CombatTraitTriggers?,
        targetIsStunned: Bool,
        damageKeyword: Keyword?,
    ) -> Int {
        let canSunder = damageKeyword == .physical || damageKeyword == .stun
        var extraRemoved = canSunder
            ? min(buffer - absorbed, CombatRounding.scaled(absorbed, multiplier: sourceTriggers?.sunderingBlockMultiplier ?? 0))
            : 0
        if damageKeyword == .physical, let sourceTriggers, sourceTriggers.physicalBlockBreakMultiplier > 0 {
            extraRemoved += CombatRounding.scaled(absorbed, multiplier: sourceTriggers.physicalBlockBreakMultiplier - 1)
        }
        if damageKeyword == .holy, let sourceTriggers, sourceTriggers.holyBlockBreakMultiplier > 0 {
            extraRemoved += CombatRounding.scaled(absorbed, multiplier: sourceTriggers.holyBlockBreakMultiplier - 1)
        }
        if damageKeyword == .poison, let sourceTriggers, sourceTriggers.poisonStripsBlockBeforeHealth > 0 {
            extraRemoved += sourceTriggers.poisonStripsBlockBeforeHealth
        }
        if targetIsStunned, let sourceTriggers, sourceTriggers.stunnedEnemyLoseAllBlock {
            extraRemoved = buffer
        }
        return extraRemoved
    }

    private static func applyBlockAbsorptionReactions(
        absorbed: Int,
        blockBroken: Bool,
        defenderTriggers: CombatTraitTriggers,
        sourceTriggers: CombatTraitTriggers?,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if absorbed > 0, let attackerID = state.sourceActorID,
           let attacker = context.roster.combatant(for: attackerID),
           context.roster.health(for: attacker.combatant) > 0 {
            let reflection = defenderTriggers.onBlockHitDealHoly
            if reflection > 0 {
                events.append(contentsOf: resolveRetaliation(
                    amount: reflection,
                    keyword: .holy,
                    target: attacker.combatant,
                    sourceActorID: state.combatant.id,
                    in: &context,
                ).events)
            }
            if defenderTriggers.onBlockReduceAttackerAccuracyPercent > 0 {
                context.appendEffect(
                    .damageReductionPercent(
                        Double(defenderTriggers.onBlockReduceAttackerAccuracyPercent) / 100,
                        defenderTriggers.onBlockReduceAttackerAccuracyTurns,
                    ),
                    to: attacker.combatant,
                    sourceID: state.combatant.id,
                    remainingTurns: defenderTriggers.onBlockReduceAttackerAccuracyTurns,
                )
            }
        }

        if blockBroken, state.combatant.role == .enemy,
           let sourceTriggers, sourceTriggers.onEnemyBlockBrokenDealPhysical > 0,
           let attackerID = state.sourceActorID,
           context.roster.health(for: state.combatant) > 0 {
            events.append(contentsOf: resolveRetaliation(
                amount: sourceTriggers.onEnemyBlockBrokenDealPhysical,
                keyword: .physical,
                target: state.combatant,
                sourceActorID: attackerID,
                in: &context,
            ).events)
        }
        return events
    }
}

import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // swiftlint:disable:next function_body_length - shield resolution is one ordered mutation step
    static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        var effects = context.roster.activeEffects(for: state.combatant)

        let blockMultiplier = DamageDefensePolicy.blockMultiplier(state: state, in: context)
        // Full bypass skips ally protection too: it scales by the same
        // multiplier, so it would absorb 0 and its absorbed-gated side
        // effects (talent blocked-damage, block-broken) would no-op.
        guard blockMultiplier > 0 else { return }

        applyAllyBlockProtection(to: &state, blockMultiplier: blockMultiplier, in: &context)
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

        let effectiveBuffer = max(0, CombatRounding.scaled(buffer, multiplier: blockMultiplier))
        guard effectiveBuffer > 0, state.remaining > 0 else {
            return
        }

        let doublesPhysical = defenderTriggers.doublePhysicalBlockAbsorption && state.damageKeyword == .physical
        let belowHalfHealth = context.roster.health(for: state.combatant) * 2
            < context.roster.maxHealth(for: state.combatant)
        let oathMultiplier = belowHalfHealth ? defenderTriggers.blockAbsorptionMultiplierBelowHalfHealth : 1
        let manaMultiplier = (context.roster.runtime(for: state.combatant)?.currentMana ?? 0) > 0
            ? defenderTriggers.blockAbsorptionMultiplierWhileMana : 1
        let attackerIsBurning = state.sourceActorID.flatMap { context.roster.combatant(for: $0)?.combatant }
            .map { context.roster.hasAffliction(.burn, on: $0) } ?? false
        let burningMultiplier = attackerIsBurning ? defenderTriggers.blockAbsorptionVsBurningMultiplier : 1
        let absorptionMultiplier = (doublesPhysical ? 2.0 : 1.0) * max(1, oathMultiplier)
            * max(1, defenderTriggers.doubleAllBlockAbsorption ? 2 : 1)
            * max(1, manaMultiplier) * max(1, burningMultiplier)
        let absorptionBuffer = CombatRounding.scaled(effectiveBuffer, multiplier: absorptionMultiplier)

        let absorption = applyAbsorption(
            to: &state,
            keyword: keyword,
            buffer: buffer,
            effectiveBuffer: absorptionBuffer,
            sourceTriggers: sourceTriggers,
            in: &context,
        )

        let blockRemoval = max(
            absorption.absorbed > 0 ? 1 : 0,
            CombatRounding.scaled(absorption.absorbed, multiplier: 1 / absorptionMultiplier),
        ) + max(0, absorption.extraRemoved)

        var blockBroken = false
        if let reduced = DefensePoolEngine.reduce(
            blockRemoval,
            in: effects,
        ) {
            effects = reduced.effects
            blockBroken = reduced.broken
        }
        state.heroCardBlockBroken = blockBroken
        context.roster.setActiveEffects(effects, for: state.combatant)

        // The Patient Edge: actual attack damage absorbed by Block prepares a Critical Hit.
        if absorption.absorbed > 0,
           state.options.isAttackHit, !state.options.isRetaliation, !state.options.isPeriodic,
           defenderTriggers.blockPreparesCritical {
            ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
                if case .nextStrikeCritical = $0 {
                    return true
                }
                return false
            }
            _ = context.insertEffect(
                .nextStrikeCritical,
                to: state.combatant,
                sourceID: state.combatant.id,
                remainingTurns: 0,
                replacing: { $0 == .nextStrikeCritical },
            )
        }

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
            blockBroken: blockBroken,
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
        in context: inout BattleState,
    ) -> ShieldAbsorption {
        let absorbed = min(state.remaining, effectiveBuffer)
        state.blockedAmount += absorbed
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
            damageKeyword: state.damageKeyword,
            isAttackHit: state.options.isAttackHit,
        )
        return ShieldAbsorption(absorbed: absorbed, extraRemoved: extraRemoved)
    }

    private static func applyAllyBlockProtection(
        to state: inout DamageResolutionState,
        blockMultiplier: Double,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0, !state.options.isHealthCost else { return }
        let protector: Combatant
        let abilityName: String
        if state.combatant.role == .companion,
           context.roster.hero.isAlive,
           context.heroModifiers.triggers.blockAbsorbsCompanionDamage {
            protector = context.roster.hero.combatant
            abilityName = "Intercede"
        } else if state.combatant.role == .hero,
                  context.roster.companion.isAlive,
                  context.companionModifiers.triggers.companionBlockAbsorbsHeroDamage {
            protector = context.roster.companion.combatant
            abilityName = "Sacrificial Guard"
        } else {
            return
        }
        let protectorEffects = context.roster.activeEffects(for: protector)
        let available = CombatRounding.scaled(DefensePoolEngine.blockPoints(in: protectorEffects), multiplier: blockMultiplier)
        guard let reduced = DefensePoolEngine.reduce(min(state.remaining, available), in: protectorEffects)
        else { return }
        let absorbed = reduced.absorbed
        state.blockedAmount += absorbed
        appendAbsorption(
            absorbed,
            abilityName: abilityName,
            keyword: reduced.keyword,
            actorName: reduced.keyword.rawValue,
            target: protector,
            to: &state,
            in: &context,
        )
        context.roster.setActiveEffects(reduced.effects, for: protector)
        state.damageEvents.append(contentsOf: handleTalentBlockedDamage(
            absorbed: absorbed,
            blockBroken: reduced.broken,
            defender: protector,
            attackerID: state.sourceActorID,
            in: &context,
        ))
        if reduced.broken {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBlockBroken(
                on: protector,
                attackerID: state.sourceActorID,
                in: &context,
            ))
        }
    }

    private static func handleTalentBlockedDamage(
        absorbed: Int,
        blockBroken: Bool,
        defender: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard absorbed > 0, defender.role != .enemy, let attackerID,
              let attacker = context.roster.combatant(for: attackerID)
        else { return [] }
        var events: [ActionEvent] = []
        if partyTrigger(\.storedImpact, defender: defender, in: context) {
            context.storedBlockedDamageByActorID[defender.id, default: 0] += absorbed
        }
        if blockBroken, context.modifiers(for: defender.id).triggers.seismicReversal {
            events.append(contentsOf: resolveNestedDamage(
                amount: absorbed,
                keyword: .stun,
                target: attacker.combatant,
                sourceActorID: defender.id,
                requireTargetAlive: true,
                in: &context,
            ).events)
        }
        if partyTrigger(\.glacialReprieve, defender: defender, in: context) {
            events.append(contentsOf: resolveNestedDamage(
                amount: absorbed,
                keyword: .freeze,
                target: attacker.combatant,
                sourceActorID: defender.id,
                requireTargetAlive: true,
                in: &context,
            ).events)
        }
        let reflectChance = context.modifiers(for: defender.id).triggers.blockHolyReflectChancePercent
        if reflectChance > 0, attacker.role == .enemy,
           context.claimTalentAbility("Radiant Shell", actorID: defender.id),
           BattleChance.succeeds(probability: reflectChance, using: &context.rng) {
            events.append(contentsOf: resolveNestedDamage(
                amount: absorbed,
                keyword: .holy,
                target: attacker.combatant,
                sourceActorID: defender.id,
                requireTargetAlive: true,
                in: &context,
            ).events)
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

    private static func extraBlockRemoval(
        absorbed: Int,
        buffer: Int,
        sourceTriggers: CombatTraitTriggers?,
        damageKeyword: Keyword?,
        isAttackHit: Bool,
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
        if isAttackHit, damageKeyword == .poison, let sourceTriggers {
            extraRemoved += sourceTriggers.poisonAttackExtraBlockRemoval
        }
        if damageKeyword == .poison, let sourceTriggers,
           sourceTriggers.poisonDamageVsBlockMultiplier > 1 {
            extraRemoved += CombatRounding.scaled(
                absorbed,
                multiplier: sourceTriggers.poisonDamageVsBlockMultiplier - 1,
            )
        }
        if isAttackHit, damageKeyword == .burn, let sourceTriggers,
           sourceTriggers.burnAttackBlockBreakMultiplier > 1 {
            extraRemoved += CombatRounding.scaled(
                absorbed,
                multiplier: sourceTriggers.burnAttackBlockBreakMultiplier - 1,
            )
        }
        if isAttackHit, damageKeyword == .bleed, let sourceTriggers,
           sourceTriggers.bleedAttackBlockBreakMultiplier > 1 {
            extraRemoved += CombatRounding.scaled(
                absorbed,
                multiplier: sourceTriggers.bleedAttackBlockBreakMultiplier - 1,
            )
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
                events.append(contentsOf: resolveNestedDamage(
                    amount: reflection,
                    keyword: .holy,
                    target: attacker.combatant,
                    sourceActorID: state.combatant.id,
                    requireTargetAlive: true,
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
            events.append(contentsOf: resolveNestedDamage(
                amount: sourceTriggers.onEnemyBlockBrokenDealPhysical,
                keyword: .physical,
                target: state.combatant,
                sourceActorID: attackerID,
                requireTargetAlive: true,
                in: &context,
            ).events)
        }
        return events
    }
}

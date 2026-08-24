import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        var effects = context.roster.activeEffects(for: state.combatant)

        applyIntercede(to: &state, in: &context)

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
            state.activeEffects = effects
            return
        }

        let sourceTriggers = state.sourceActorID.map { context.modifiers(for: $0).triggers }
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers
        let targetIsStunned = state.targetStatus.isStunned
        let targetIsFrozen = state.targetStatus.isFrozen

        let effectiveBuffer = effectiveBlockBuffer(
            buffer: buffer,
            sourceTriggers: sourceTriggers,
            targetIsStunned: targetIsStunned,
            targetIsFrozen: targetIsFrozen,
            damageKeyword: state.damageKeyword
        )
        guard effectiveBuffer > 0, state.remaining > 0 else {
            state.activeEffects = effects
            return
        }

        let absorption = applyAbsorption(
            to: &state,
            keyword: keyword,
            buffer: buffer,
            effectiveBuffer: effectiveBuffer,
            sourceTriggers: sourceTriggers,
            targetIsStunned: targetIsStunned,
            in: &context
        )

        var blockBroken = false
        if let reduced = DefensePoolEngine.reduce(
            absorption.absorbed + absorption.extraRemoved,
            in: effects
        ) {
            effects = reduced.effects
            blockBroken = reduced.broken
        }
        context.roster.setActiveEffects(effects, for: state.combatant)
        state.activeEffects = effects
        state.damageEvents.append(contentsOf: applyBlockAbsorptionReactions(
            absorbed: absorption.absorbed,
            blockBroken: blockBroken,
            defenderTriggers: defenderTriggers,
            sourceTriggers: sourceTriggers,
            to: &state,
            in: &context
        ))
        applyOverflowAndBreakReactions(blockBroken: blockBroken, defenderTriggers: defenderTriggers, to: &state, in: &context)
    }

    /// Unbreakable overflow mitigation and block-broken reactions.
    private static func applyOverflowAndBreakReactions(
        blockBroken: Bool,
        defenderTriggers: CombatTraitTriggers,
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        // Unbreakable: damage that exceeds Block is reduced by half.
        if state.remaining > 0, defenderTriggers.postBlockOverflowDamageMultiplier != 1 {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: defenderTriggers.postBlockOverflowDamageMultiplier
            )
        }

        if blockBroken {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBlockBroken(
                on: state.combatant,
                attackerID: state.sourceActorID,
                in: &context
            ))
            state.activeEffects = context.roster.activeEffects(for: state.combatant)
        }
    }

    /// Result of a single Block absorption event.
    private struct ShieldAbsorption {
        var absorbed: Int
        var extraRemoved: Int
    }

    /// Absorbs damage into the effective Block pool, computes talent-based extra
    /// removal, and emits the absorption event.
    private static func applyAbsorption(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        buffer: Int,
        effectiveBuffer: Int,
        sourceTriggers: CombatTraitTriggers?,
        targetIsStunned: Bool,
        in context: inout BattleState
    ) -> ShieldAbsorption {
        let absorbed = min(state.remaining, effectiveBuffer)
        state.remaining -= absorbed
        state.blockedAmount += absorbed
        let extraRemoved = extraBlockRemoval(
            absorbed: absorbed,
            buffer: buffer,
            sourceTriggers: sourceTriggers,
            targetIsStunned: targetIsStunned,
            damageKeyword: state.damageKeyword
        )
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .shieldAbsorbed,
            actorName: keyword.rawValue,
            abilityName: keyword.rawValue,
            target: state.combatant,
            amount: absorbed,
            keyword: keyword,
            appliedEffectSummaries: [],
            milestone: nil
        ))
        return ShieldAbsorption(absorbed: absorbed, extraRemoved: extraRemoved)
    }

    /// Intercede: the Hero's Block also absorbs damage dealt to the Companion.
    private static func applyIntercede(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.combatant.role == .companion,
              state.remaining > 0,
              context.roster.hero.isAlive,
              context.heroModifiers.triggers.blockAbsorbsCompanionDamage
        else { return }
        let heroEffects = context.roster.activeEffects(for: context.roster.hero.combatant)
        guard let reduced = DefensePoolEngine.reduce(state.remaining, in: heroEffects)
        else { return }
        let heroAbsorbed = reduced.absorbed
        state.remaining -= heroAbsorbed
        state.blockedAmount += heroAbsorbed
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .shieldAbsorbed,
            actorName: reduced.keyword.rawValue,
            abilityName: "Intercede",
            target: context.roster.hero.combatant,
            amount: heroAbsorbed,
            keyword: reduced.keyword
        ))
        context.roster.setActiveEffects(reduced.effects, for: context.roster.hero.combatant)
    }

    /// Talent Block-ignore modifiers (Holy, Burn, Physical-ignore) reduce the
    /// effective Block pool before absorption; fully-ignored Block stays intact.
    private static func effectiveBlockBuffer(
        buffer: Int,
        sourceTriggers: CombatTraitTriggers?,
        targetIsStunned: Bool,
        targetIsFrozen: Bool,
        damageKeyword: Keyword?
    ) -> Int {
        var effectiveBuffer = buffer
        if let sourceTriggers {
            if damageKeyword == .physical, sourceTriggers.physicalBlockIgnorePercent > 0 {
                effectiveBuffer = CombatRounding.scaled(
                    buffer,
                    multiplier: 1 - min(1, sourceTriggers.physicalBlockIgnorePercent)
                )
            }
            if damageKeyword == .physical, sourceTriggers.physicalIgnoresBlockVsStunnedOrFrozen,
               targetIsStunned || targetIsFrozen {
                effectiveBuffer = 0
            }
            if damageKeyword == .holy, sourceTriggers.holyIgnoresBlock || sourceTriggers.holyIgnoresBlockAndDodge {
                effectiveBuffer = 0
            }
            if damageKeyword == .burn, sourceTriggers.burnIgnoresBlockAndMitigation {
                effectiveBuffer = 0
            }
        }
        return effectiveBuffer
    }

    /// Extra Block removal from sunder/shred talents beyond the absorbed amount.
    private static func extraBlockRemoval(
        absorbed: Int,
        buffer: Int,
        sourceTriggers: CombatTraitTriggers?,
        targetIsStunned: Bool,
        damageKeyword: Keyword?
    ) -> Int {
        let canSunder = damageKeyword == .physical || damageKeyword == .stun
        var extraRemoved = canSunder
            ? min(buffer - absorbed, CombatRounding.scaled(absorbed, multiplier: sourceTriggers?.sunderingBlockMultiplier ?? 0))
            : 0
        // Shield Breaker: Physical attacks deal double damage to enemy Block.
        if damageKeyword == .physical, let sourceTriggers, sourceTriggers.physicalBlockBreakMultiplier > 0 {
            extraRemoved += CombatRounding.scaled(absorbed, multiplier: sourceTriggers.physicalBlockBreakMultiplier - 1)
        }
        // Pure Radiance: Holy damage deals bonus damage against enemy Block.
        if damageKeyword == .holy, let sourceTriggers, sourceTriggers.holyBlockBreakMultiplier > 0 {
            extraRemoved += CombatRounding.scaled(absorbed, multiplier: sourceTriggers.holyBlockBreakMultiplier - 1)
        }
        // Corrosive Venom: Poison strips Block before damaging Health.
        if damageKeyword == .poison, let sourceTriggers, sourceTriggers.poisonStripsBlockBeforeHealth > 0 {
            extraRemoved += sourceTriggers.poisonStripsBlockBeforeHealth
        }
        // Sunder Shield: Stunned enemies lose all their active Block.
        if targetIsStunned, let sourceTriggers, sourceTriggers.stunnedEnemyLoseAllBlock {
            extraRemoved = buffer
        }
        return extraRemoved
    }

    /// Reactions after a Block absorbs damage: Sun-Struck Shell, Dazzling Guard,
    /// and Shield Shatter on broken enemy Block.
    private static func applyBlockAbsorptionReactions(
        absorbed: Int,
        blockBroken: Bool,
        defenderTriggers: CombatTraitTriggers,
        sourceTriggers: CombatTraitTriggers?,
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        // Sun-Struck Shell: when this combatant's Block absorbs a hit, reflect
        // Holy damage to the attacker.
        if absorbed > 0, let attackerID = state.sourceActorID,
           let attacker = context.roster.combatant(for: attackerID),
           context.roster.health(for: attacker.combatant) > 0 {
            let reflection = defenderTriggers.onBlockHitDealHoly
            if reflection > 0 {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: reflection,
                        target: attacker.combatant,
                        keyword: .holy,
                        sourceActorID: state.combatant.id,
                        options: DamageOptions(
                            applyStatBonus: false,
                            applyItemBonus: false,
                            applyDodge: false,
                            isRetaliation: true
                        )
                    )
                ).events)
            }
            // Dazzling Guard: blocking an attack reduces the attacker's damage for 2 turns.
            if defenderTriggers.onBlockReduceAttackerAccuracyPercent > 0 {
                context.appendEffect(
                    .damageReductionPercent(
                        Double(defenderTriggers.onBlockReduceAttackerAccuracyPercent) / 100,
                        defenderTriggers.onBlockReduceAttackerAccuracyTurns
                    ),
                    to: attacker.combatant,
                    sourceID: state.combatant.id,
                    remainingTurns: defenderTriggers.onBlockReduceAttackerAccuracyTurns
                )
            }
        }

        // Shield Shatter: breaking an enemy's Block deals Physical damage to them.
        if blockBroken, state.combatant.role == .enemy,
           let sourceTriggers, sourceTriggers.onEnemyBlockBrokenDealPhysical > 0,
           let attackerID = state.sourceActorID,
           context.roster.health(for: state.combatant) > 0 {
            events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: sourceTriggers.onEnemyBlockBrokenDealPhysical,
                    target: state.combatant,
                    keyword: .physical,
                    sourceActorID: attackerID,
                    options: DamageOptions(
                        applyStatBonus: false,
                        applyItemBonus: false,
                        applyDodge: false,
                        isRetaliation: true
                    )
                )
            ).events)
            state.activeEffects = context.roster.activeEffects(for: state.combatant)
        }
        return events
    }
}

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

        let borrowedStrip = applyAllyBlockProtection(to: &state, blockMultiplier: blockMultiplier, in: &context)
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

        var sourceTriggers = state.sourceActorID.map { context.modifiers(for: $0).triggers }
        if let strip = sourceTriggers?.poisonStripsBlockBeforeHealth {
            sourceTriggers?.poisonStripsBlockBeforeHealth = max(0, strip - borrowedStrip)
        }
        let defenderTriggers = context.modifiers(for: state.combatant.id).triggers

        let effectiveBuffer = max(0, CombatRounding.scaled(buffer, multiplier: blockMultiplier))
        guard effectiveBuffer > 0, state.remaining > 0 else {
            return
        }

        // Corrosive Venom strips Block before this packet is absorbed, so a
        // packet larger than the defender's Block gains penetration instead of
        // soaking the strip against an already-depleted pool.
        let stripBeforeAbsorption = state.damageKeyword == .poison
            ? sourceTriggers?.poisonStripsBlockBeforeHealth ?? 0
            : 0

        let absorptionMultiplier = blockAbsorptionMultiplier(for: state.combatant, state: state, in: context)
        let absorbableBuffer = max(0, buffer - stripBeforeAbsorption)
        let absorbableEffectiveBuffer = max(0, CombatRounding.scaled(absorbableBuffer, multiplier: blockMultiplier))
        let absorptionBuffer = CombatRounding.scaled(absorbableEffectiveBuffer, multiplier: absorptionMultiplier)

        let absorbed = applyAbsorption(
            to: &state,
            keyword: keyword,
            effectiveBuffer: absorptionBuffer,
            in: &context,
        )

        let consumedBlock = max(
            absorbed > 0 ? 1 : 0,
            CombatRounding.scaled(absorbed, multiplier: 1 / absorptionMultiplier),
        )
        let blockRemoval = consumedBlock + extraBlockRemoval(
            consumedBlock: consumedBlock,
            buffer: buffer,
            sourceTriggers: sourceTriggers,
            damageKeyword: state.damageKeyword,
            isAttackHit: state.options.isAttackHit,
        )

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

        recordBlockAbsorption(absorbed, owner: state.combatant, to: &state, in: &context)

        state.damageEvents.append(contentsOf: applyBlockAbsorptionReactions(
            absorbed: absorbed,
            blockBroken: blockBroken,
            defenderTriggers: defenderTriggers,
            sourceTriggers: sourceTriggers,
            to: &state,
            in: &context,
        ))
        state.damageEvents.append(contentsOf: handleTalentBlockedDamage(
            absorbed: absorbed,
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
            state.brokenBlockOwners.append(state.combatant)
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBlockBroken(
                on: state.combatant,
                attackerID: state.sourceActorID,
                in: &context,
            ))
        }
    }

    private static func applyAbsorption(
        to state: inout DamageResolutionState,
        keyword: Keyword,
        effectiveBuffer: Int,
        in context: inout BattleState,
    ) -> Int {
        let absorbed = min(state.remaining, effectiveBuffer)
        // A strip that exhausts the pool absorbs nothing; skip the log entry.
        if absorbed > 0 {
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
        }
        return absorbed
    }

    private static func applyAllyBlockProtection(
        to state: inout DamageResolutionState,
        blockMultiplier: Double,
        in context: inout BattleState,
    ) -> Int {
        guard state.remaining > 0, !state.options.isHealthCost else { return 0 }
        guard let protection = allyBlockProtector(for: state.combatant, in: context) else { return 0 }
        let protector = protection.owner
        let protectorEffects = context.roster.activeEffects(for: protector)
        let buffer = DefensePoolEngine.blockPoints(in: protectorEffects)
        let sourceTriggers = state.sourceActorID.map { context.modifiers(for: $0).triggers }
        let stripBeforeAbsorption = state.damageKeyword == .poison
            ? sourceTriggers?.poisonStripsBlockBeforeHealth ?? 0
            : 0
        let absorptionMultiplier = blockAbsorptionMultiplier(for: protector, state: state, in: context)
        let effectiveBlock = CombatRounding.scaled(max(0, buffer - stripBeforeAbsorption), multiplier: blockMultiplier)
        let available = CombatRounding.scaled(effectiveBlock, multiplier: absorptionMultiplier)
        let absorbed = min(state.remaining, available)
        let consumedBlock = max(absorbed > 0 ? 1 : 0, CombatRounding.scaled(absorbed, multiplier: 1 / absorptionMultiplier))
        let blockRemoval = consumedBlock + extraBlockRemoval(
            consumedBlock: consumedBlock,
            buffer: buffer,
            sourceTriggers: sourceTriggers,
            damageKeyword: state.damageKeyword,
            isAttackHit: state.options.isAttackHit,
        )
        guard let reduced = DefensePoolEngine.reduce(blockRemoval, in: protectorEffects) else { return 0 }
        if absorbed > 0 {
            state.blockedAmount += absorbed
            appendAbsorption(
                absorbed,
                abilityName: protection.abilityName,
                keyword: reduced.keyword,
                actorName: reduced.keyword.rawValue,
                target: protector,
                to: &state,
                in: &context,
            )
        }
        context.roster.setActiveEffects(reduced.effects, for: protector)
        recordBlockAbsorption(absorbed, owner: protector, to: &state, in: &context)
        state.damageEvents.append(contentsOf: handleTalentBlockedDamage(
            absorbed: absorbed,
            blockBroken: reduced.broken,
            defender: protector,
            attackerID: state.sourceActorID,
            in: &context,
        ))
        if reduced.broken {
            state.brokenBlockOwners.append(protector)
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBlockBroken(
                on: protector,
                attackerID: state.sourceActorID,
                in: &context,
            ))
        }
        return min(buffer, max(0, stripBeforeAbsorption))
    }

    private static func allyBlockProtector(
        for combatant: Combatant,
        in context: BattleState,
    ) -> (owner: Combatant, abilityName: String)? {
        if combatant.role == .companion,
           context.roster.hero.isAlive,
           context.heroModifiers.triggers.blockAbsorbsCompanionDamage {
            return (context.roster.hero.combatant, "Intercede")
        }
        if combatant.role == .hero,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.companionBlockAbsorbsHeroDamage {
            return (context.roster.companion.combatant, "Sacrificial Guard")
        }
        return nil
    }

    private static func blockAbsorptionMultiplier(
        for owner: Combatant,
        state: DamageResolutionState,
        in context: BattleState,
    ) -> Double {
        let defenderTriggers = context.modifiers(for: owner.id).triggers
        let doublesPhysical = defenderTriggers.doublePhysicalBlockAbsorption && state.damageKeyword == .physical
        let belowHalfHealth = context.roster.health(for: owner) * 2
            < context.roster.maxHealth(for: owner)
        let oathMultiplier = belowHalfHealth ? defenderTriggers.blockAbsorptionMultiplierBelowHalfHealth : 1
        let manaMultiplier = (context.roster.runtime(for: owner)?.currentMana ?? 0) > 0
            ? defenderTriggers.blockAbsorptionMultiplierWhileMana : 1
        let attackerIsBurning = state.sourceActorID.flatMap { context.roster.combatant(for: $0)?.combatant }
            .map { context.roster.hasAffliction(.burn, on: $0) } ?? false
        let burningMultiplier = attackerIsBurning ? defenderTriggers.blockAbsorptionVsBurningMultiplier : 1
        return (doublesPhysical ? 2.0 : 1.0) * max(1, oathMultiplier)
            * max(1, defenderTriggers.doubleAllBlockAbsorption ? 2 : 1)
            * max(1, manaMultiplier) * max(1, burningMultiplier)
    }

    private static func recordBlockAbsorption(
        _ absorbed: Int,
        owner: Combatant,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard absorbed > 0 else { return }
        state.blockAbsorbingOwners.append(owner)
        guard state.options.isAttackHit, !state.options.isRetaliation, !state.options.isPeriodic,
              context.modifiers(for: owner.id).triggers.blockPreparesCritical
        else { return }
        ActiveEffectMutation.removeMatching(from: owner, in: &context) { $0 == .nextStrikeCritical }
        _ = context.insertEffect(
            .nextStrikeCritical,
            to: owner,
            sourceID: owner.id,
            remainingTurns: 0,
            replacing: { $0 == .nextStrikeCritical },
        )
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
        consumedBlock: Int,
        buffer: Int,
        sourceTriggers: CombatTraitTriggers?,
        damageKeyword: Keyword?,
        isAttackHit: Bool,
    ) -> Int {
        let remainingBlock = max(0, buffer - consumedBlock)
        let canSunder = damageKeyword == .physical || damageKeyword == .stun
        var extraRemoved = canSunder
            ? CombatRounding.scaled(consumedBlock, multiplier: sourceTriggers?.sunderingBlockMultiplier ?? 0)
            : 0
        if damageKeyword == .physical, let sourceTriggers, sourceTriggers.physicalBlockBreakMultiplier > 0 {
            extraRemoved += CombatRounding.scaled(consumedBlock, multiplier: sourceTriggers.physicalBlockBreakMultiplier - 1)
        }
        if damageKeyword == .holy, let sourceTriggers, sourceTriggers.holyBlockBreakMultiplier > 0 {
            extraRemoved += CombatRounding.scaled(consumedBlock, multiplier: sourceTriggers.holyBlockBreakMultiplier - 1)
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
                consumedBlock,
                multiplier: sourceTriggers.poisonDamageVsBlockMultiplier - 1,
            )
        }
        if isAttackHit, damageKeyword == .burn, let sourceTriggers,
           sourceTriggers.burnAttackBlockBreakMultiplier > 1 {
            extraRemoved += CombatRounding.scaled(
                consumedBlock,
                multiplier: sourceTriggers.burnAttackBlockBreakMultiplier - 1,
            )
        }
        if isAttackHit, damageKeyword == .bleed, let sourceTriggers,
           sourceTriggers.bleedAttackBlockBreakMultiplier > 1 {
            extraRemoved += CombatRounding.scaled(
                consumedBlock,
                multiplier: sourceTriggers.bleedAttackBlockBreakMultiplier - 1,
            )
        }
        return min(remainingBlock, max(0, extraRemoved))
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

import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        let blockMultiplier = DamageDefensePolicy.blockMultiplier(state: state, in: context)
        guard blockMultiplier > 0 else { return }

        let borrowedStrip = if let protection = allyBlockProtector(for: state.combatant, in: context) {
            await absorbBlock(
                ownedBy: protection.owner, abilityName: protection.abilityName,
                blockMultiplier: blockMultiplier, to: &state, in: &context,
            )
        } else {
            0
        }
        // Resolve the recipient from live state: protection reactions may have
        // changed either participant's effects or the attacker's modifiers.
        _ = await absorbBlock(
            ownedBy: state.combatant, blockMultiplier: blockMultiplier,
            previouslyStripped: borrowedStrip, to: &state, in: &context,
        )
    }

    // swiftlint:disable:next function_body_length - commit one Block pool before its ordered absorption and break reactions
    private static func absorbBlock(
        ownedBy owner: Combatant,
        abilityName: String? = nil,
        blockMultiplier: Double,
        previouslyStripped: Int = 0,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async -> Int {
        guard state.remaining > 0, !state.options.isHealthCost else { return 0 }
        let pool = blockPool(for: owner, in: context)
        guard let keyword = pool.keyword else { return 0 }
        let isBorrowed = owner.id != state.combatant.id
        let buffer = pool.amount
        guard isBorrowed || CombatRounding.scaled(buffer, multiplier: blockMultiplier) > 0 else { return 0 }

        var sourceTriggers = state.sourceActorID.map { context.modifiers(for: $0).triggers }
        if !isBorrowed, let strip = sourceTriggers?.poisonStripsBlockBeforeHealth {
            sourceTriggers?.poisonStripsBlockBeforeHealth = max(0, strip - previouslyStripped)
        }
        let defenderTriggers = context.modifiers(for: owner.id).triggers
        let stripBeforeAbsorption = state.damageKeyword == .poison
            ? sourceTriggers?.poisonStripsBlockBeforeHealth ?? 0
            : 0
        let absorptionMultiplier = blockAbsorptionMultiplier(for: owner, state: state, in: context)
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
        var blockBroken = false
        if blockRemoval > 0 {
            context.roster.mutateEffects(for: owner) {
                blockBroken = DefensePoolEngine.consume(blockRemoval, from: &$0)
            }
        }
        if absorbed > 0 {
            state.blockedAmount += absorbed
            appendAbsorption(
                absorbed,
                abilityName: abilityName ?? keyword.rawValue,
                keyword: keyword,
                source: .init(actorID: owner.id, name: keyword.rawValue),
                target: owner,
                to: &state,
                in: &context,
            )
        }
        if !isBorrowed {
            state.heroCardBlockBroken = blockBroken
        }
        recordBlockAbsorption(absorbed, owner: owner, to: &state, in: &context)

        await applyBlockAbsorptionReactions(
            absorbed: absorbed,
            blockBroken: blockBroken,
            owner: owner,
            defenderTriggers: defenderTriggers,
            sourceTriggers: sourceTriggers,
            to: &state,
            in: &context,
        )
        await handleTalentBlockedDamage(
            absorbed: absorbed,
            blockBroken: blockBroken,
            defender: owner,
            attackerID: state.sourceActorID,
            in: &context,
        )
        if !isBorrowed, state.options.isAttackHit, blockBroken, state.remaining > 0,
           defenderTriggers.postBlockOverflowDamageMultiplier != 1 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: defenderTriggers.postBlockOverflowDamageMultiplier)
        }
        if blockBroken {
            state.brokenBlockOwners.append(owner)
            await CombatTriggerEngine.afterBlockBroken(on: owner, attackerID: state.sourceActorID, in: &context)
        }
        return min(buffer, max(0, stripBeforeAbsorption))
    }

    private static func blockPool(for owner: Combatant, in context: BattleState) -> (amount: Int, keyword: Keyword?) {
        var amount = 0
        var keyword: Keyword?
        for active in context.roster.activeEffects(for: owner) {
            guard case let .shield(stackKeyword, buffer) = active.effect else { continue }
            amount = SaturatedArithmetic.saturatingAdd(amount, buffer)
            if buffer > 0, keyword == nil {
                keyword = stackKeyword
            }
        }
        return (amount, keyword)
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
        let belowHalfHealth = context.roster.isBelowHalfHealth(for: owner)
        let oathMultiplier = belowHalfHealth ? defenderTriggers.blockAbsorptionMultiplierBelowHalfHealth : 1
        let manaMultiplier = (context.roster.runtime(for: owner)?.currentMana ?? 0) > 0
            ? defenderTriggers.blockAbsorptionMultiplierWhileMana : 1
        let attackerIsBurning = state.sourceActorID.flatMap { context.roster.combatant(for: $0)?.combatant }
            .map { context.roster.hasAffliction(.burn, on: $0) } ?? false
        let burningMultiplier = attackerIsBurning ? defenderTriggers.blockAbsorptionVsBurningMultiplier : 1
        return (doublesPhysical ? 2.0 : 1.0) * max(1, oathMultiplier)
            * max(1, defenderTriggers.blockAbsorptionMultiplier)
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
        guard state.options.isPrimaryAttack,
              context.modifiers(for: owner.id).triggers.blockPreparesCritical
        else { return }
        guard let participant = context.roster.participant(for: owner), participant.isPartyMember else { return }
        context.roster[participant].uniques.patientEdgeReady = true
    }

    private static func handleTalentBlockedDamage(
        absorbed: Int,
        blockBroken: Bool,
        defender: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) async {
        guard absorbed > 0, defender.role != .enemy, let attackerID,
              let attacker = context.roster.combatant(for: attackerID)
        else { return }

        if partyTrigger(\.storedImpact, defender: defender, in: context) {
            context.roster.mutateRuntime(for: defender) {
                $0.talents.battle.storedBlockedDamage = SaturatedArithmetic.saturatingAdd($0.talents.battle.storedBlockedDamage, absorbed)
            }
        }
        if blockBroken, context.modifiers(for: defender.id).triggers.seismicReversal {
            _ = await resolveNestedDamage(
                amount: absorbed,
                keyword: .stun,
                target: attacker.combatant,
                sourceActorID: defender.id,
                requireTargetAlive: true,
                in: &context,
            )
        }
        let freeze = context.modifiers(for: defender.id).triggers.firstBlockFreezeDamagePerTurn
        if freeze > 0, context.claimTurnGuard(.glacialReprieve, actorID: defender.id) {
            _ = await resolveNestedDamage(
                amount: freeze,
                keyword: .freeze,
                target: attacker.combatant,
                sourceActorID: defender.id,
                requireTargetAlive: true,
                in: &context,
            )
        }
        let reflectChance = context.modifiers(for: defender.id).triggers.blockHolyReflectChancePercent
        if reflectChance > 0, attacker.role == .enemy,
           context.claimTalentAbility(.radiantShell, actorID: defender.id),
           BattleChance.succeeds(probability: reflectChance, using: &context.rng) {
            _ = await resolveNestedDamage(
                amount: absorbed,
                keyword: .holy,
                target: attacker.combatant,
                sourceActorID: defender.id,
                requireTargetAlive: true,
                in: &context,
            )
        }
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
        let sharedKeyword = damageKeyword.flatMap {
            UniqueCombatEngine.sharedDamageKeyword(for: $0, triggers: sourceTriggers ?? CombatTraitTriggers())
        }
        let isPhysical = damageKeyword == .physical || sharedKeyword == .physical
        let canSunder = isPhysical || damageKeyword == .stun
        var extraRemoved = canSunder
            ? CombatRounding.scaled(consumedBlock, multiplier: sourceTriggers?.sunderingBlockMultiplier ?? 0)
            : 0
        if isAttackHit, isPhysical, let sourceTriggers, sourceTriggers.physicalBlockBreakMultiplier > 0 {
            extraRemoved = SaturatedArithmetic.saturatingAdd(
                extraRemoved,
                CombatRounding.scaled(consumedBlock, multiplier: sourceTriggers.physicalBlockBreakMultiplier - 1),
            )
        }
        if damageKeyword == .holy, let sourceTriggers, sourceTriggers.holyBlockBreakMultiplier > 0 {
            extraRemoved = SaturatedArithmetic.saturatingAdd(
                extraRemoved,
                CombatRounding.scaled(consumedBlock, multiplier: sourceTriggers.holyBlockBreakMultiplier - 1),
            )
        }
        if damageKeyword == .poison, let sourceTriggers, sourceTriggers.poisonStripsBlockBeforeHealth > 0 {
            extraRemoved = SaturatedArithmetic.saturatingAdd(extraRemoved, sourceTriggers.poisonStripsBlockBeforeHealth)
        }
        if isAttackHit, damageKeyword == .poison, let sourceTriggers {
            extraRemoved = SaturatedArithmetic.saturatingAdd(extraRemoved, sourceTriggers.poisonAttackExtraBlockRemoval)
        }
        if damageKeyword == .poison, let sourceTriggers,
           sourceTriggers.poisonDamageVsBlockMultiplier > 1 {
            extraRemoved = SaturatedArithmetic.saturatingAdd(extraRemoved, CombatRounding.scaled(
                consumedBlock,
                multiplier: sourceTriggers.poisonDamageVsBlockMultiplier - 1,
            ))
        }
        if isAttackHit, damageKeyword == .burn || sharedKeyword == .burn, let sourceTriggers,
           sourceTriggers.burnAttackBlockBreakMultiplier > 1 {
            extraRemoved = SaturatedArithmetic.saturatingAdd(extraRemoved, CombatRounding.scaled(
                consumedBlock,
                multiplier: sourceTriggers.burnAttackBlockBreakMultiplier - 1,
            ))
        }
        if isAttackHit, damageKeyword == .bleed || sharedKeyword == .bleed, let sourceTriggers,
           sourceTriggers.bleedAttackBlockBreakMultiplier > 1 {
            extraRemoved = SaturatedArithmetic.saturatingAdd(extraRemoved, CombatRounding.scaled(
                consumedBlock,
                multiplier: sourceTriggers.bleedAttackBlockBreakMultiplier - 1,
            ))
        }
        return min(remainingBlock, max(0, extraRemoved))
    }

    private static func applyBlockAbsorptionReactions(
        absorbed: Int,
        blockBroken: Bool,
        owner: Combatant,
        defenderTriggers: CombatTraitTriggers,
        sourceTriggers: CombatTraitTriggers?,
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) async {
        if owner.id == state.combatant.id, absorbed > 0, let attackerID = state.sourceActorID,
           let attacker = context.roster.combatant(for: attackerID),
           context.roster.health(for: attacker.combatant) > 0 {
            let reflection = defenderTriggers.onBlockHitDealHoly
            if reflection > 0 {
                _ = await resolveNestedDamage(
                    amount: reflection,
                    keyword: .holy,
                    target: attacker.combatant,
                    sourceActorID: state.combatant.id,
                    requireTargetAlive: true,
                    in: &context,
                )
            }
            if defenderTriggers.onBlockReduceAttackerAccuracyPercent > 0 {
                context.insertEffect(
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

        if blockBroken,
           let sourceTriggers, sourceTriggers.onEnemyBlockBrokenDealPhysical > 0,
           let attackerID = state.sourceActorID,
           let attacker = context.roster.participant(for: attackerID),
           let defender = context.roster.participant(for: owner),
           attacker.isPartyMember != defender.isPartyMember,
           context.roster.health(for: state.combatant) > 0 {
            // The Block break committed this offensive consequence before any lethal reflection.
            _ = await resolveNestedDamage(
                amount: sourceTriggers.onEnemyBlockBrokenDealPhysical,
                keyword: .physical,
                target: state.combatant,
                sourceActorID: attackerID,
                requireTargetAlive: true,
                in: &context,
            )
        }
    }
}

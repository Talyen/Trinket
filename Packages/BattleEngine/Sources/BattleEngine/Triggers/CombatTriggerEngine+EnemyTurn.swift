import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Single owner for enemy-avoidance events: the enemy is always the named
    /// actor, and only the outcome, ability name, target, and keyword vary.
    private static func emitAvoidanceEvent(
        effectKind: ActionEvent.EffectOutcome,
        abilityName: String,
        target: Combatant,
        keyword: Keyword,
        in context: inout BattleState,
    ) {
        context.nextEvent(
            kind: .effect(effectKind),
            source: .init(context.roster.enemy),
            abilityName: abilityName,
            target: target,
            amount: 0,
            keyword: keyword,
        )
    }

    /// Total of a trigger magnitude across living allies plus the first ally
    /// carrying it (nil when nobody does). Shared by the bleed/poison
    /// enemy-action gates, which differ only in the key they sum.
    private static func partyChanceAndSource<T: Numeric & Comparable>(
        _ chance: KeyPath<CombatTraitTriggers, T>,
        adding: (T, T) -> T = (+),
        in context: BattleState,
    ) -> (chance: T, source: Combatant?) {
        var total: T = 0
        var source: Combatant?
        for ally in livingAllies(in: context) {
            let value = ally.profile.triggers[keyPath: chance]
            total = adding(total, value)
            if source == nil, value > 0 {
                source = ally.combatant
            }
        }
        return (total, source)
    }

    static func beforeEnemyActBleedReactions(in context: inout BattleState) -> Bool {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive else { return false }
        let enemyIsBleeding = context.roster.hasAffliction(.bleed, on: enemy)
        guard enemyIsBleeding else { return false }

        let (skipChance, skipSource) = partyChanceAndSource(
            \.bleedingEnemyActionSkipChancePercent,
            in: context,
        )
        if skipChance > 0,
           BattleChance.succeeds(probability: skipChance, using: &context.rng) {
            let source = skipSource ?? context.roster.hero.combatant
            emitAvoidanceEvent(
                effectKind: .controlActionSkipped,
                abilityName: triggerAbilityName(
                    .bleedingEnemyActionSkipChancePercent,
                    for: source,
                    fallback: "Hamstring Shot",
                    in: context,
                ),
                target: enemy,
                keyword: .bleed,
                in: &context,
            )
            return true
        }
        return false
    }

    static func beforeEnemyAttackBleedReactions(in context: inout BattleState) async {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive, context.roster.hasAffliction(.bleed, on: enemy) else { return }
        let (damage, source) = partyChanceAndSource(
            \.bleedingEnemyAttackDealDamage, adding: SaturatedArithmetic.saturatingAdd, in: context,
        )
        guard damage > 0, let source else { return }
        _ = await context.dealReactionDamage(damage, to: enemy, keyword: .physical, sourceActorID: source.id)
    }

    internal static func beforeEnemyAttack(
        _ facts: ResolvedActionFacts, in context: inout BattleState,
    ) async -> Bool {
        guard !facts.damageKeywords.isEmpty else { return false }
        let actor = facts.action.actor
        let checkpoint = CombatCheckpoint.attackEligibility(actor.id)
        guard checkpoint.allowsContinuation(in: context) else { return true }
        let avoidance = await enemyAttackAvoidance(in: &context)
        guard !avoidance else { return avoidance }

        if checkpoint.allowsContinuation(in: context) {
            await beforeEnemyAttackBleedReactions(in: &context)
        }
        guard context.roster.health(for: actor) > 0 else { return true }
        if context.roster.hasPendingActionSkip(for: actor) {
            await BattleTurnEngine.consumeActionSkip(for: actor, context: &context)
            return true
        }
        return context.isBattleOver
    }

    private static func companionNegateEnemyAttack(
        in context: inout BattleState,
    ) async -> Bool? {
        let companion = context.roster.companion
        guard companion.isAlive else { return nil }
        let companionTriggers = context.companionModifiers.triggers
        guard companionTriggers.negateFirstEnemyAttack, !companion.talents.battle.negatedFirstEnemyAttack else {
            return nil
        }
        // Claim the combat allowance before resolving reactions.
        context.roster.mutateRuntime(for: companion.combatant) { $0.talents.battle.negatedFirstEnemyAttack = true }
        let protected = context.talentAdjustedEnemyTarget
        return await dodgeEntireEnemyAbility(
            by: protected,
            abilityName: triggerAbilityName(
                .negateFirstEnemyAttack,
                for: companion.combatant,
                fallback: "Warning Bark",
                in: context,
            ),
            in: &context,
        )
    }

    private static func dodgeEntireEnemyAbility(
        by protected: Combatant,
        abilityName: String,
        in context: inout BattleState,
    ) async -> Bool {
        context.nextEvent(
            kind: .effect(.dodgeApplied),
            source: .init(protected),
            abilityName: abilityName,
            target: protected,
            amount: 0,
            keyword: .dodge,
        )
        await UniqueCombatEngine.afterUniqueDodge(by: protected, attackerID: context.roster.enemy.id, in: &context)
        afterHeroTalentDodge(by: protected, in: &context)
        await afterDodge(by: protected, attackerID: context.roster.enemy.id, allowsCounterattacks: true, in: &context)
        return true
    }

    static func consumeEnemyActionDelay(in context: inout BattleState) -> Bool {
        let enemy = context.enemy
        let delays = context.roster.enemy.talents.battle.actionDelays
        if delays > 0 {
            context.roster.enemy.talents.battle.actionDelays = delays - 1
            emitAvoidanceEvent(
                effectKind: .controlActionSkipped,
                abilityName: "Delay",
                target: enemy,
                keyword: .stun,
                in: &context,
            )
            return true
        }
        return false
    }

    static func enemyAttackAvoidance(in context: inout BattleState) async -> Bool {
        if let companionNegation = await companionNegateEnemyAttack(in: &context) {
            return companionNegation
        }

        let abilityTarget = context.talentAdjustedEnemyTarget
        if let blindedMiss = blindingLightMiss(abilityTarget: abilityTarget, in: &context) {
            return blindedMiss
        }
        if let poisonMiss = poisonedEnemyMiss(abilityTarget: abilityTarget, in: &context) {
            return poisonMiss
        }
        if abilityTarget.id == context.roster.hero.id,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.swapAndDodgeForHeroChance > 0,
           BattleChance.succeeds(
               probability: context.companionModifiers.triggers.swapAndDodgeForHeroChance,
               using: &context.rng,
           ) {
            return await dodgeEntireEnemyAbility(
                by: context.roster.companion.combatant,
                abilityName: "Decoy Swap",
                in: &context,
            )
        }
        return false
    }

    static func afterEnemyFreezeRecover(in context: inout BattleState) {
        for (_, runtime) in livingPartyMembers(in: context) {
            guard context.modifiers(for: runtime.id).triggers.subzeroMist else { continue }
            context.roster.mutateRuntime(for: runtime.combatant) { $0.talents.turn.subzeroMistActive = true }
        }
    }

    private static func blindingLightMiss(
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) -> Bool? {
        let enemy = context.roster.enemy.combatant
        let pending = context.roster.runtime(for: enemy)?.talents.pending
        let chance = pending?.nextAttackMissChance ?? 0
        guard chance > 0 else { return nil }
        context.roster.mutateRuntime(for: enemy) {
            $0.talents.pending.nextAttackMissChance = 0
            $0.talents.pending.nextAttackMissAbilityName = nil
        }
        guard BattleChance.succeeds(probability: chance, using: &context.rng) else { return nil }
        emitAvoidanceEvent(
            effectKind: .dodgeApplied,
            abilityName: pending?.nextAttackMissAbilityName ?? "Blinding Light",
            target: abilityTarget,
            keyword: .dodge,
            in: &context,
        )
        return true
    }

    private static func poisonedEnemyMiss(
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) -> Bool? {
        let enemy = context.enemy
        guard context.roster.hasAffliction(.poison, on: enemy) else {
            return nil
        }
        let (missChance, missSource) = partyChanceAndSource(\.poisonedEnemyMissChancePercent, in: context)
        guard missChance > 0, BattleChance.succeeds(probability: missChance, using: &context.rng) else {
            return nil
        }
        let source = missSource ?? context.roster.hero.combatant
        emitAvoidanceEvent(
            effectKind: .dodgeApplied,
            abilityName: triggerAbilityName(
                .poisonedEnemyMissChancePercent,
                for: source,
                fallback: "Paralytic Poison",
                in: context,
            ),
            target: abilityTarget,
            keyword: .dodge,
            in: &context,
        )
        return true
    }

    static func afterEnemyAbility(in context: inout BattleState) async {
        guard context.roster.companion.isAlive else { return }
        let retrieverTriggers = context.companionModifiers.triggers

        if retrieverTriggers.onEnemyAbilityGold > 0 {
            await emitGold(
                .onEnemyAbilityGold, "Fetch!",
                amount: retrieverTriggers.onEnemyAbilityGold,
                to: context.roster.companion.combatant,
                in: &context,
            )
        }
    }

    static func afterEnemyStunRecover(in context: inout BattleState) async {
        let enemy = context.roster.enemy.combatant
        for (owner, member) in livingPartyMembers(in: context) {
            let triggers = context.modifiers(for: member.id).triggers
            if triggers.onEnemyStunRecoverDrawCard > 0 {
                emitDraw(
                    .onEnemyStunRecoverDrawCard,
                    "Second Wind",
                    count: triggers.onEnemyStunRecoverDrawCard,
                    for: owner,
                    actor: member.combatant,
                    in: &context,
                )
            }
            if triggers.onEnemyStunRecoverApplyAfflictions > 0, context.roster.health(for: enemy) > 0 {
                let potency = triggers.onEnemyStunRecoverApplyAfflictions
                for keyword in [Keyword.poison, .burn, .bleed] {
                    await DoTApplicator.applyDoT(
                        keyword: keyword,
                        potency: potency,
                        to: enemy,
                        sourceActorID: member.id,
                        application: .attached,
                        in: &context,
                    )
                }
            }
            if triggers.onStunExpirePoisonDamage > 0, context.roster.health(for: enemy) > 0 {
                await heroTalentDamage(
                    .poison, amount: triggers.onStunExpirePoisonDamage,
                    source: member.combatant, name: "Venom Trap", in: &context,
                )
            }
        }
    }
}

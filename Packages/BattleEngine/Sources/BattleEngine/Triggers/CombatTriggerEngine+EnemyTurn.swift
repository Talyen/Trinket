import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Single owner for enemy-avoidance events: the enemy is always the named
    /// actor, and only the outcome, ability name, target, and keyword vary.
    private static func avoidanceEvent(
        effectKind: ActionEvent.EffectOutcome,
        abilityName: String,
        target: Combatant,
        keyword: Keyword,
        in context: inout BattleState,
    ) -> ActionEvent {
        context.nextEvent(
            kind: .effect,
            effectKind: effectKind,
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
        in context: BattleState,
    ) -> (chance: T, source: Combatant?) {
        let living = livingAllies(in: context)
        let total = living.reduce(0) { $0 + $1.profile.triggers[keyPath: chance] }
        let source = living.first { $0.profile.triggers[keyPath: chance] > 0 }?.combatant
        return (total, source)
    }

    static func beforeEnemyActBleedReactions(in context: inout BattleState) -> (events: [ActionEvent], cancelled: Bool) {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive else { return ([], false) }
        let enemyIsBleeding = context.roster.hasAffliction(.bleed, on: enemy)
        guard enemyIsBleeding else { return ([], false) }

        var events: [ActionEvent] = []
        let (skipChance, skipSource) = partyChanceAndSource(
            \.bleedingEnemyActionSkipChancePercent,
            in: context,
        )
        if skipChance > 0,
           BattleChance.succeeds(probability: skipChance, using: &context.rng) {
            let source = skipSource ?? context.roster.hero.combatant
            events.append(avoidanceEvent(
                effectKind: .controlActionSkipped,
                abilityName: triggerAbilityName(
                    "bleedingEnemyActionSkipChancePercent",
                    for: source,
                    fallback: "Hamstring Shot",
                    in: context,
                ),
                target: enemy,
                keyword: .bleed,
                in: &context,
            ))
            return (events, true)
        }
        return (events, false)
    }

    static func beforeEnemyAttackBleedReactions(in context: inout BattleState) async -> [ActionEvent] {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive, context.roster.hasAffliction(.bleed, on: enemy) else { return [] }
        let (damage, source) = partyChanceAndSource(\.bleedingEnemyAttackDealDamage, in: context)
        guard damage > 0, let source else { return [] }
        return await context.resolveDamage(DamageRequest(
            amount: damage, target: enemy, keyword: .physical, sourceActorID: source.id, options: .reaction(),
        )).events
    }

    internal static func beforeEnemyAttack(
        _ facts: ResolvedActionFacts, in context: inout BattleState,
    ) async -> (events: [ActionEvent], cancelled: Bool) {
        guard !facts.damageKeywords.isEmpty else { return ([], false) }
        let actor = facts.action.actor
        let checkpoint = CombatCheckpoint.attackEligibility(actor.id)
        guard checkpoint.allowsContinuation(in: context) else { return ([], true) }
        let avoidance = await enemyAttackAvoidance(in: &context)
        guard !avoidance.cancelled else { return avoidance }
        var events = avoidance.events
        await events.append(contentsOf: checkpoint.resolve([
            { await beforeEnemyAttackBleedReactions(in: &$0) },
        ], in: &context))
        guard context.roster.health(for: actor) > 0 else { return (events, true) }
        if context.roster.hasPendingActionSkip(for: actor) {
            await events.append(contentsOf: BattleTurnEngine.consumeActionSkip(for: actor, context: &context))
            return (events, true)
        }
        return (events, context.isBattleOver)
    }

    private static func companionNegateEnemyAttack(
        in context: inout BattleState,
    ) async -> (events: [ActionEvent], cancelled: Bool)? {
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
                "negateFirstEnemyAttack",
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
    ) async -> (events: [ActionEvent], cancelled: Bool) {
        var events: [ActionEvent] = [
            context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                source: .init(protected),
                abilityName: abilityName,
                target: protected,
                amount: 0,
                keyword: .dodge,
            ),
        ]
        await events.append(contentsOf: UniqueCombatEngine.afterUniqueDodge(
            by: protected,
            attackerID: context.roster.enemy.id,
            in: &context,
        ))
        events.append(contentsOf: Self.afterHeroTalentDodge(by: protected, in: &context))
        await events.append(contentsOf: Self.afterDodge(
            by: protected,
            attackerID: context.roster.enemy.id,
            allowsCounterattacks: true,
            in: &context,
        ))
        return (events, true)
    }

    static func consumeEnemyActionDelay(in context: inout BattleState) -> (events: [ActionEvent], cancelled: Bool) {
        let enemy = context.enemy
        let delays = context.additionalControlSkipsByCombatantID[enemy.id, default: 0]
        if delays > 0 {
            context.additionalControlSkipsByCombatantID[enemy.id] = delays - 1
            return ([avoidanceEvent(
                effectKind: .controlActionSkipped,
                abilityName: "Delay",
                target: enemy,
                keyword: .stun,
                in: &context,
            )], true)
        }
        return ([], false)
    }

    static func enemyAttackAvoidance(in context: inout BattleState) async -> (events: [ActionEvent], cancelled: Bool) {
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
        return ([], false)
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
    ) -> (events: [ActionEvent], cancelled: Bool)? {
        let enemy = context.roster.enemy.combatant
        let pending = context.roster.runtime(for: enemy)?.talents.pending
        let chance = pending?.nextAttackMissChance ?? 0
        guard chance > 0 else { return nil }
        context.roster.mutateRuntime(for: enemy) {
            $0.talents.pending.nextAttackMissChance = 0
            $0.talents.pending.nextAttackMissAbilityName = nil
        }
        guard BattleChance.succeeds(probability: chance, using: &context.rng) else { return nil }
        return ([avoidanceEvent(
            effectKind: .dodgeApplied,
            abilityName: pending?.nextAttackMissAbilityName ?? "Blinding Light",
            target: abilityTarget,
            keyword: .dodge,
            in: &context,
        )], true)
    }

    private static func poisonedEnemyMiss(
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) -> (events: [ActionEvent], cancelled: Bool)? {
        let enemy = context.enemy
        guard context.roster.hasAffliction(.poison, on: enemy) else {
            return nil
        }
        let (missChance, missSource) = partyChanceAndSource(\.poisonedEnemyMissChancePercent, in: context)
        guard missChance > 0, BattleChance.succeeds(probability: missChance, using: &context.rng) else {
            return nil
        }
        let source = missSource ?? context.roster.hero.combatant
        return ([avoidanceEvent(
            effectKind: .dodgeApplied,
            abilityName: triggerAbilityName(
                "poisonedEnemyMissChancePercent",
                for: source,
                fallback: "Paralytic Poison",
                in: context,
            ),
            target: abilityTarget,
            keyword: .dodge,
            in: &context,
        )], true)
    }

    static func afterEnemyAbility(in context: inout BattleState) async -> [ActionEvent] {
        guard context.roster.companion.isAlive else { return [] }
        let retrieverTriggers = context.companionModifiers.triggers
        var events: [ActionEvent] = []
        if retrieverTriggers.onEnemyAbilityGold > 0 {
            await events.append(contentsOf: emitGold(
                "onEnemyAbilityGold", "Fetch!",
                amount: retrieverTriggers.onEnemyAbilityGold,
                to: context.roster.companion.combatant,
                in: &context,
            ))
        }
        return events
    }

    static func afterEnemyStunRecover(in context: inout BattleState) async -> [ActionEvent] {
        var events: [ActionEvent] = []
        let enemy = context.roster.enemy.combatant
        for (owner, member) in livingPartyMembers(in: context) {
            let triggers = context.modifiers(for: member.id).triggers
            if triggers.onEnemyStunRecoverDrawCard > 0 {
                events.append(contentsOf: drawCards(
                    triggers.onEnemyStunRecoverDrawCard,
                    for: owner,
                    actor: member.combatant,
                    abilityName: triggerAbilityName(
                        "onEnemyStunRecoverDrawCard",
                        for: member.combatant,
                        fallback: "Second Wind",
                        in: context,
                    ),
                    in: &context,
                ))
            }
            if triggers.onEnemyStunRecoverApplyAfflictions > 0, context.roster.health(for: enemy) > 0 {
                let potency = triggers.onEnemyStunRecoverApplyAfflictions
                for keyword in [Keyword.poison, .burn, .bleed] {
                    await events.append(contentsOf: applyDoT(
                        keyword: keyword,
                        potency: potency,
                        to: enemy,
                        sourceActorID: member.id,
                        application: .attached,
                        in: &context,
                    ))
                }
            }
            if triggers.onStunExpirePoisonDamage > 0, context.roster.health(for: enemy) > 0 {
                await events.append(contentsOf: heroTalentDamage(
                    .poison, amount: triggers.onStunExpirePoisonDamage,
                    source: member.combatant, name: "Venom Trap", in: &context,
                ))
            }
        }
        return events
    }
}

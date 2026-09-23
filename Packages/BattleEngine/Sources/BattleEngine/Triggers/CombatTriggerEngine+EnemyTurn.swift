import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
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
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .controlActionSkipped,
                actorName: context.roster.enemy.name,
                abilityName: triggerAbilityName(
                    "bleedingEnemyActionSkipChancePercent",
                    for: source,
                    fallback: "Hamstring Shot",
                    in: context,
                ),
                target: enemy,
                amount: 0,
                keyword: .bleed,
            ))
            return (events, true)
        }
        return (events, false)
    }

    static func beforeEnemyAttackBleedReactions(in context: inout BattleState) -> [ActionEvent] {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive, context.roster.hasAffliction(.bleed, on: enemy) else { return [] }
        let (damage, source) = partyChanceAndSource(\.bleedingEnemyAttackDealDamage, in: context)
        guard damage > 0, let source else { return [] }
        return context.resolveDamage(DamageRequest(
            amount: damage, target: enemy, keyword: .physical, sourceActorID: source.id, options: .reaction(),
        )).events
    }

    internal static func beforeEnemyAttack(
        _ facts: ResolvedActionFacts, in context: inout BattleState,
    ) -> (events: [ActionEvent], cancelled: Bool) {
        guard !facts.damageKeywords.isEmpty else { return ([], false) }
        let actor = facts.action.actor
        let checkpoint = CombatCheckpoint.attackEligibility(actor.id)
        guard checkpoint.allowsContinuation(in: context) else { return ([], true) }
        let avoidance = enemyAttackAvoidance(in: &context)
        guard !avoidance.cancelled else { return avoidance }
        var events = avoidance.events
        events.append(contentsOf: checkpoint.resolve([
            { beforeEnemyAttackBleedReactions(in: &$0) },
        ], in: &context))
        guard context.roster.health(for: actor) > 0 else { return (events, true) }
        if context.roster.hasPendingActionSkip(for: actor) {
            events.append(contentsOf: BattleTurnEngine.consumeActionSkip(for: actor, context: &context))
            return (events, true)
        }
        return (events, context.isBattleOver)
    }

    private static func companionNegateEnemyAttack(
        in context: inout BattleState,
    ) -> (events: [ActionEvent], cancelled: Bool)? {
        let companion = context.roster.companion
        guard companion.isAlive else { return nil }
        let companionTriggers = context.companionModifiers.triggers
        guard companionTriggers.negateFirstEnemyAttack, !companion.talents.battle.negatedFirstEnemyAttack else {
            return nil
        }
        // Claim the combat allowance before resolving reactions.
        context.roster.mutateRuntime(for: companion.combatant) { $0.talents.battle.negatedFirstEnemyAttack = true }
        let protected = context.talentAdjustedEnemyTarget
        var events: [ActionEvent] = [
            context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                actorName: protected.name,
                abilityName: triggerAbilityName(
                    "negateFirstEnemyAttack",
                    for: companion.combatant,
                    fallback: "Warning Bark",
                    in: context,
                ),
                target: protected,
                amount: 0,
                keyword: .dodge,
            ),
        ]
        events.append(contentsOf: UniqueCombatEngine.afterUniqueDodge(
            by: protected,
            attackerID: context.roster.enemy.id,
            in: &context,
        ))
        events.append(contentsOf: Self.afterHeroTalentDodge(by: protected, in: &context))
        events.append(contentsOf: Self.afterDodge(
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
            return ([context.nextEvent(
                kind: .effect,
                effectKind: .controlActionSkipped,
                actorName: enemy.name,
                abilityName: "Delay",
                target: enemy,
                amount: 0,
                keyword: .stun,
            )], true)
        }
        return ([], false)
    }

    static func enemyAttackAvoidance(in context: inout BattleState) -> (events: [ActionEvent], cancelled: Bool) {
        if let companionNegation = companionNegateEnemyAttack(in: &context) {
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
            context.prependEffect(.evadeNextHit, to: context.roster.hero.combatant, remainingTurns: 0)
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
        let chance = context.roster.runtime(for: enemy)?.talents.pending.nextAttackMissChance ?? 0
        guard chance > 0 else { return nil }
        context.roster.mutateRuntime(for: enemy) { $0.talents.pending.nextAttackMissChance = 0 }
        guard BattleChance.succeeds(probability: chance, using: &context.rng) else { return nil }
        return ([context.nextEvent(
            kind: .effect,
            effectKind: .dodgeApplied,
            actorName: enemy.name,
            abilityName: "Blinding Light",
            target: abilityTarget,
            amount: 0,
            keyword: .dodge,
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
        return ([context.nextEvent(
            kind: .effect,
            effectKind: .dodgeApplied,
            actorName: context.roster.enemy.name,
            abilityName: triggerAbilityName(
                "poisonedEnemyMissChancePercent",
                for: source,
                fallback: "Paralytic Poison",
                in: context,
            ),
            target: abilityTarget,
            amount: 0,
            keyword: .dodge,
        )], true)
    }

    static func afterEnemyAbility(in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.companion.isAlive else { return [] }
        let retrieverTriggers = context.companionModifiers.triggers
        var events: [ActionEvent] = []
        if retrieverTriggers.onEnemyAbilityGold > 0 {
            events.append(contentsOf: emitGold(
                "onEnemyAbilityGold", "Fetch!",
                amount: retrieverTriggers.onEnemyAbilityGold,
                to: context.roster.companion.combatant,
                in: &context,
            ))
        }
        return events
    }

    static func afterEnemyStunRecover(in context: inout BattleState) -> [ActionEvent] {
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
                for keyword in [Keyword.poison, .burn] {
                    events.append(contentsOf: context.applyDecayingDoT(
                        keyword: keyword,
                        potency: potency,
                        to: enemy,
                        sourceActorID: member.id,
                        application: .attached,
                    ))
                }
                events.append(contentsOf: DoTApplicator.applyBleed(
                    potency: potency,
                    to: enemy,
                    sourceActorID: member.id,
                    application: .attached,
                    in: &context,
                ))
            }
        }
        return events
    }
}

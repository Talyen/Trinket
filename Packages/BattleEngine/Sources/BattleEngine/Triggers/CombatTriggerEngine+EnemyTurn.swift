import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func beforeEnemyActBleedReactions(in context: inout BattleState) -> (events: [ActionEvent], cancelled: Bool) {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive else { return ([], false) }
        let enemyIsBleeding = context.roster.hasAffliction(.bleed, on: enemy)
        guard enemyIsBleeding else { return ([], false) }

        var events: [ActionEvent] = []
        let living = livingAllies(in: context)
        let skipChance = living.reduce(0) {
            $0 + $1.profile.triggers.bleedingEnemyActionSkipChancePercent
        }
        if skipChance > 0,
           BattleChance.succeeds(probability: skipChance, using: &context.rng) {
            let source = living.first {
                $0.profile.triggers.bleedingEnemyActionSkipChancePercent > 0
            }?.combatant ?? context.roster.hero.combatant
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
        let living = livingAllies(in: context)
        let damage = living.reduce(0) { $0 + $1.profile.triggers.bleedingEnemyAttackDealDamage }
        guard damage > 0, let source = living.first(where: {
            $0.profile.triggers.bleedingEnemyAttackDealDamage > 0
        })?.combatant else { return [] }
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
        if companionTriggers.negateFirstEnemyAttack, !companion.hasNegatedFirstEnemyAttack {
            context.roster.mutateRuntime(for: companion.combatant) { $0.hasNegatedFirstEnemyAttack = true }
            return ([context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                actorName: companion.name,
                abilityName: triggerAbilityName(
                    "negateFirstEnemyAttack",
                    for: companion.combatant,
                    fallback: "Warning Bark",
                    in: context,
                ),
                target: context.roster.enemy.combatant,
                amount: 0,
                keyword: .dodge,
            )], true)
        }
        return nil
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
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive, context.modifiers(for: runtime.id).triggers.subzeroMist else { continue }
            context.roster.mutateRuntime(for: runtime.combatant) { $0.subzeroMistActive = true }
        }
    }

    private static func poisonedEnemyMiss(
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) -> (events: [ActionEvent], cancelled: Bool)? {
        let enemy = context.enemy
        guard context.roster.hasAffliction(.poison, on: enemy) else {
            return nil
        }
        let living = livingAllies(in: context)
        let missChance = living.reduce(0) {
            $0 + $1.profile.triggers.poisonedEnemyMissChancePercent
        }
        guard missChance > 0, BattleChance.succeeds(probability: missChance, using: &context.rng) else {
            return nil
        }
        let source = living.first {
            $0.profile.triggers.poisonedEnemyMissChancePercent > 0
        }?.combatant ?? context.roster.hero.combatant
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
            events.append(contentsOf: context.grantGoldEvent(
                retrieverTriggers.onEnemyAbilityGold,
                to: context.roster.companion.combatant,
                abilityName: triggerAbilityName(
                    "onEnemyAbilityGold",
                    for: context.roster.companion.combatant,
                    fallback: "Fetch!",
                    in: context,
                ),
            ))
        }
        return events
    }

    static func afterEnemyStunRecover(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        let enemy = context.roster.enemy.combatant
        for owner in [BattleParticipant.hero, .companion] {
            let member = context.roster[owner]
            guard member.isAlive else { continue }
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
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .poison,
                    potency: potency,
                    to: enemy,
                    sourceActorID: member.id,
                    application: .attached,
                ))
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: potency,
                    to: enemy,
                    sourceActorID: member.id,
                    application: .attached,
                ))
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

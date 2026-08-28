import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func beforeEnemyActBleedReactions(in context: inout BattleState) -> (events: [ActionEvent], cancelled: Bool) {
        let enemy = context.enemy
        guard context.roster.enemy.isAlive else { return ([], false) }
        let enemyIsBleeding = context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .bleed }
        guard enemyIsBleeding else { return ([], false) }

        var events: [ActionEvent] = []
        let living = livingAllies(in: context)
        let pin = living.reduce(0) { $0 + $1.profile.triggers.bleedingEnemyAttackDealDamage }
        if pin > 0 {
            let source = living.first {
                $0.profile.triggers.bleedingEnemyAttackDealDamage > 0
            }?.combatant ?? context.roster.hero.combatant
            events = context.resolveDamage(
                DamageRequest(
                    amount: pin,
                    target: enemy,
                    keyword: .physical,
                    sourceActorID: source.id,
                    options: .flatReaction
                )
            ).events
            guard context.roster.enemy.isAlive else { return (events, true) }
        }

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
                    in: context
                ),
                target: enemy,
                amount: 0,
                keyword: .bleed
            ))
            return (events, true)
        }
        return (events, false)
    }

    private static func companionNegateEnemyAttack(
        in context: inout BattleState
    ) -> (events: [ActionEvent], cancelled: Bool)? {
        let companion = context.roster.companion
        guard companion.isAlive else { return nil }
        let companionTriggers = context.companionModifiers.triggers
        if companionTriggers.negateFirstEnemyAttack || companionTriggers.negateFirstEnemyAttackChance > 0,
           !companion.hasNegatedFirstEnemyAttack {
            context.roster.mutateRuntime(for: companion.combatant) { $0.hasNegatedFirstEnemyAttack = true }
            let negated = companionTriggers.negateFirstEnemyAttack
                || BattleChance.succeeds(
                    probability: companionTriggers.negateFirstEnemyAttackChance,
                    using: &context.rng
                )
            if negated {
                let abilityName = companionTriggers.negateFirstEnemyAttack
                    ? triggerAbilityName(
                        "negateFirstEnemyAttack",
                        for: companion.combatant,
                        fallback: "Warning Bark",
                        in: context
                    )
                    : triggerAbilityName(
                        "negateFirstEnemyAttackChance",
                        for: companion.combatant,
                        fallback: "Shadow Shift",
                        in: context
                    )
                return ([context.nextEvent(
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    actorName: companion.name,
                    abilityName: abilityName,
                    target: context.roster.enemy.combatant,
                    amount: 0,
                    keyword: .dodge
                )], true)
            }
        }
        return nil
    }

    static func enemyActAvoidance(in context: inout BattleState) -> (events: [ActionEvent], cancelled: Bool) {
        if let companionNegation = companionNegateEnemyAttack(in: &context) {
            return companionNegation
        }

        var events: [ActionEvent] = []
        let abilityTarget = context.talentAdjustedEnemyTarget
        let enemy = context.enemy
        if let poisonMiss = poisonedEnemyMiss(abilityTarget: abilityTarget, in: &context) {
            return poisonMiss
        }
        if context.roster.hasControlStatus(for: enemy, keyword: .freeze),
           abilityTarget.id == context.roster.companion.id,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.frozenEnemyMissChanceVsCompanionPercent > 0,
           BattleChance.succeeds(
               probability: context.companionModifiers.triggers.frozenEnemyMissChanceVsCompanionPercent,
               using: &context.rng
           ) {
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                actorName: context.roster.enemy.name,
                abilityName: triggerAbilityName(
                    "frozenEnemyMissChanceVsCompanionPercent",
                    for: context.roster.companion.combatant,
                    fallback: "Subzero Mist",
                    in: context
                ),
                target: abilityTarget,
                amount: 0,
                keyword: .dodge
            ))
            return (events, true)
        }
        if abilityTarget.id == context.roster.hero.id,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.swapAndDodgeForHeroChance > 0,
           BattleChance.succeeds(
               probability: context.companionModifiers.triggers.swapAndDodgeForHeroChance,
               using: &context.rng
           ) {
            context.prependEffect(.evadeNextHit, to: context.roster.hero.combatant, remainingTurns: 0)
        }
        return (events, false)
    }

    private static func poisonedEnemyMiss(
        abilityTarget: Combatant,
        in context: inout BattleState
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
                in: context
            ),
            target: abilityTarget,
            amount: 0,
            keyword: .dodge
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
                    in: context
                )
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
                        in: context
                    ),
                    in: &context
                ))
            }
            if triggers.onEnemyStunRecoverApplyAfflictions > 0, context.roster.health(for: enemy) > 0 {
                let potency = triggers.onEnemyStunRecoverApplyAfflictions
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .poison,
                    potency: potency,
                    to: enemy,
                    sourceActorID: member.id,
                    dealImmediateDamage: false,
                    suppressAffixReactions: true
                ))
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: potency,
                    to: enemy,
                    sourceActorID: member.id,
                    dealImmediateDamage: false,
                    suppressAffixReactions: true
                ))
                events.append(contentsOf: DoTApplicator.applyBleed(
                    potency: potency,
                    to: enemy,
                    sourceActorID: member.id,
                    dealImmediateDamage: false,
                    suppressAffixReactions: true,
                    in: &context
                ))
            }
        }
        return events
    }
}

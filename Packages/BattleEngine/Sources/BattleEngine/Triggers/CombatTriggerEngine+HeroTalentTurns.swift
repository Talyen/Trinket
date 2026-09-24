import TrinketContent
import TrinketCore

// MARK: - Turn lifecycle

package extension CombatTriggerEngine {
    static func startHeroTalentTurn(in context: inout BattleState) -> [ActionEvent] {
        for owner in [BattleParticipant.hero, .companion] {
            let actor = context.roster[owner].combatant
            var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
            history.spentMana = false
            context.heroTalents.history[actor.id] = history
        }
        return []
    }

    static func afterHeroTalentPoisonExpiry(sourceID: String?, target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction, let sourceID,
              let source = context.roster.combatant(for: sourceID), source.isAlive else { return [] }
        let triggers = context.modifiers(for: sourceID).triggers
        if triggers.unstableCulture, target.role == .enemy {
            context.heroTalents.history[sourceID, default: HeroTalentHistory()].preparations.insert(.doublePoison)
        }
        var events: [ActionEvent] = []
        if triggers.poisonExpiryManaRestore > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.poisonExpiryManaRestore,
                to: source.combatant,
                abilityName: "Spent Reagents",
            ))
        }
        if triggers.returningBloomHeal > 0 {
            events.append(contentsOf: heroTalentHeal(
                to: context.roster.companion.combatant,
                source: source.combatant,
                amount: triggers.returningBloomHeal,
                name: "Returning Bloom",
                in: &context,
            ))
        }
        return events
    }

    static func afterHeroTalentSpendMana(
        actor: Combatant,
        amount: Int,
        empowered: Bool = false,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction, context.roster.health(for: actor) > 0 else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if empowered, triggers.manaEmpowerPurgeCount > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: applyPurge(
                to: context.roster.enemy.combatant,
                source: actor,
                abilityName: triggerAbilityName("manaEmpowerPurgeCount", for: actor, fallback: "Hexing Rune", in: context),
                count: triggers.manaEmpowerPurgeCount,
                purgeAll: false,
                in: &context,
            ))
        }
        if empowered, triggers.barkweaveOnEmpowerBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.barkweaveOnEmpowerBlock,
                to: actor,
                source: actor,
                abilityName: "Barkweave",
            ))
        }
        if empowered, triggers.sharedCurrentCompanionNextAttackBonus > 0,
           context.roster.companion.isAlive {
            context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                $0.talents.pending.cardDamageBonus = max(
                    $0.talents.pending.cardDamageBonus,
                    triggers.sharedCurrentCompanionNextAttackBonus,
                )
            }
        }
        guard amount > 0 else { return events }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].spentMana = true
        let hero = context.roster.hero.combatant
        if context.roster.hero.isAlive, context.roster.companion.isAlive,
           context.heroTalents.history[hero.id]?.spentMana == true,
           context.heroTalents.history[context.roster.companion.id]?.spentMana == true,
           context.heroModifiers.triggers.groveAccord,
           context.claimHeroTalent("groveAccord", actorID: hero.id) {
            for target in [hero, context.roster.companion.combatant] {
                events.append(contentsOf: heroTalentThorns(to: target, source: hero, name: "Grove Accord", in: &context))
            }
        }
        return events
    }
}

// MARK: - Reward emitters

package extension CombatTriggerEngine {
    static func heroTalentThorns(
        to target: Combatant, source: Combatant, amount: Int = 1, name: String, in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let total = context.roster.activeEffects(for: target).reduce(amount) { sum, active in
                if case let .thorns(amount) = active.effect {
                    return sum + amount
                }
                return sum
            }
            ActiveEffectMutation.removeMatching(from: target, in: &context) { $0.kind == .thorns }
            context.appendEffect(.thorns(total), to: target, sourceID: source.id, remainingTurns: 0)
            return [context.nextEvent(
                kind: .effect,
                effectKind: .thornsApplied,
                actorName: source.name,
                abilityName: name,
                target: target,
                amount: amount,
                keyword: .thorns,
            )]
        }
    }

    static func heroTalentHeal(
        to target: Combatant,
        source: Combatant,
        amount: Int = 1,
        name: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let outcome = HealingEngine.resolveHeal(
                HealRequest(amount: amount, target: target, sourceActorID: source.id, logAs: .silent), in: &context,
            )
            guard outcome.healthRestored > 0 else { return outcome.events }
            return outcome.events + [context.nextEvent(
                kind: .effect, effectKind: .instantHeal, actorName: source.name,
                abilityName: name, target: target, amount: outcome.healthRestored, keyword: .health,
            )]
        }
    }

    static func heroTalentMana(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            context.restoreManaEmitting(1, to: target, abilityName: name)
        }
    }

    static func heroTalentGold(to source: Combatant, amount: Int = 1, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            context.grantGoldEvent(amount, to: source, abilityName: name)
        }
    }

    static func heroTalentBlock(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            context.applyBlock(1, to: target, source: source, abilityName: name)
        }
    }

    static func heroTalentDamage(
        _ keyword: Keyword,
        amount: Int = 1,
        source: Combatant,
        name: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.enemy.isAlive, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let target = context.roster.enemy.combatant
            let outcome = context.resolveDamage(DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
                options: .reaction(),
            ))
            var events = outcome.events
            if outcome.healthLost > 0 {
                events.append(context.nextEvent(
                    kind: .abilityDamage,
                    actorName: source.name,
                    abilityName: name,
                    target: target,
                    amount: outcome.healthLost,
                    keyword: keyword,
                    origin: .automatic,
                ))
            }
            if keyword == .burn || keyword == .poison {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: keyword,
                    potency: outcome.healthLost,
                    to: target,
                    sourceActorID: source.id,
                    application: .afterHit,
                ))
            }
            return events
        }
    }
}

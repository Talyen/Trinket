import TrinketContent
import TrinketCore

// MARK: - Turn lifecycle

package extension CombatTriggerEngine {
    static func startHeroTalentTurn(in context: inout BattleState) -> [ActionEvent] {
        for owner in [BattleParticipant.hero, .companion] {
            let actor = context.roster[owner].combatant
            var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
            history.playedStun = false
            history.spentMana = false
            history.falseOpening = false
            context.heroTalents.history[actor.id] = history
        }
        return []
    }

    static func endHeroTalentTurn(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for (owner, runtime) in livingPartyMembers(in: context) {
            let actor = runtime.combatant
            let triggers = context.modifiers(for: actor.id).triggers
            let history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
            if triggers.lastWager, history.lastGrantedGold, context.turnCadence.cardsPlayed[owner, default: 0] > 0 {
                events.append(contentsOf: heroTalentThorns(to: actor, source: actor, name: "Last Wager", in: &context))
            }
            if triggers.groveReserve, runtime.currentMana >= 6, context.roster.companion.isAlive {
                events.append(contentsOf: context.applyBlock(
                    runtime.currentMana / 6, to: context.roster.companion.combatant,
                    source: actor, abilityName: "Grove Reserve",
                ))
            }
        }
        return events
    }

    static func afterHeroTalentEnemyTurn(in context: inout BattleState) -> [ActionEvent] {
        context.heroTalents.enemyTurnActive = false
        let actor = context.roster.hero.combatant
        guard context.heroModifiers.triggers.quietGrove,
              !context.heroTalents.healthLostDuringEnemyTurn.contains(actor.id) else { return [] }
        return heroTalentHeal(to: context.roster.companion.combatant, source: actor, name: "Quiet Grove", in: &context)
    }

    static func afterHeroTalentPoisonExpiry(sourceID: String?, target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction, let sourceID,
              let source = context.roster.combatant(for: sourceID), source.isAlive else { return [] }
        let triggers = context.modifiers(for: sourceID).triggers
        if triggers.unstableCulture, target.role == .enemy {
            context.heroTalents.history[sourceID, default: HeroTalentHistory()].preparations.insert(.doublePoison)
        }
        var events: [ActionEvent] = []
        if triggers.spentReagents {
            events.append(contentsOf: heroTalentMana(
                to: source.combatant,
                source: source.combatant,
                name: "Spent Reagents",
                in: &context,
            ))
        }
        if triggers.returningBloom {
            events.append(contentsOf: heroTalentHeal(
                to: context.roster.companion.combatant,
                source: source.combatant,
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
        if empowered, triggers.barkweave {
            context.removeTalentPoint(.thorns, from: context.roster.enemy.combatant)
        }
        guard amount > 0 else { return events }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].spentMana = true
        let hero = context.roster.hero.combatant
        if actor.role == .companion, context.roster.hero.isAlive, context.heroModifiers.triggers.sharedCurrent {
            events.append(contentsOf: heroTalentThorns(
                to: hero, source: hero, amount: amount, name: "Shared Current", in: &context,
            ))
        }
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

    static func heroTalentHeal(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let outcome = HealingEngine.resolveHeal(
                HealRequest(amount: 1, target: target, sourceActorID: source.id, logAs: .silent), in: &context,
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

    static func heroTalentDamage(_ keyword: Keyword, source: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.enemy.isAlive, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let target = context.roster.enemy.combatant
            let outcome = context.resolveDamage(DamageRequest(
                amount: 1,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
                options: .reaction(),
            ))
            var events = outcome.events
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

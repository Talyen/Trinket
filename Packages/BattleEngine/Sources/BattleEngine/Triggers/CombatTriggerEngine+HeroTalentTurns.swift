import TrinketContent
import TrinketCore

extension CombatTriggerEngine {
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
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive else { continue }
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
        let companion = context.roster.companion
        if companion.isAlive, context.companionModifiers.triggers.shadowCamouflage,
           !context.heroTalents.attackedDuringEnemyTurn.contains(companion.id) {
            context.roster.mutateRuntime(for: companion.combatant) { $0.talents.pending.shadowCamouflageBonus = 1 }
        }
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

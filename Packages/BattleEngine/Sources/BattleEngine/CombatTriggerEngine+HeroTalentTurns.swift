import TrinketContent
import TrinketCore

extension CombatTriggerEngine {
    static func startHeroTalentTurn(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let actor = context.roster[owner].combatant
            var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
            let pendingBlock = history.pendingCompanionBlock
            history.tiers = []
            history.playedPoison = false
            history.restoredHealth = false
            history.playedStun = false
            history.spentMana = false
            history.dodged = false
            history.falseOpening = false
            history.startingMana = context.roster[owner].currentMana
            history.pendingCompanionBlock = false
            context.heroTalents.history[actor.id] = history
            if pendingBlock {
                events.append(contentsOf: heroTalentBlock(
                    to: context.roster.companion.combatant,
                    source: actor,
                    name: "Grove Reserve",
                    in: &context,
                ))
            }
        }
        return events
    }

    static func endHeroTalentTurn(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive else { continue }
            let actor = runtime.combatant
            let triggers = context.modifiers(for: actor.id).triggers
            let history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
            if triggers.sealedVial, context.hasTalentStatus(.poison, on: context.roster.enemy.combatant) {
                context.removeTalentPoint(.poison, from: actor)
            }
            if triggers.masterworkMixture, history.playedPoison, history.restoredHealth,
               context.roster.hero.isAlive, context.roster.companion.isAlive {
                for target in [context.roster.hero.combatant, context.roster.companion.combatant] {
                    events.append(contentsOf: heroTalentHeal(to: target, source: actor, name: "Masterwork Mixture", in: &context))
                }
            }
            if triggers.lastWager, history.lastGrantedGold, context.turnCadence.cardsPlayed[owner, default: 0] > 0 {
                events.append(contentsOf: heroTalentThorns(to: actor, source: actor, name: "Last Wager", in: &context))
            }
            if triggers.improvingOdds, !history.dodged {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].dodgeGrowth = min(5, history.dodgeGrowth + 1)
            }
            if triggers.groveReserve, runtime.currentMana < history.startingMana, context.roster.companion.isAlive {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].pendingCompanionBlock = true
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

    static func afterHeroTalentPoisonExpiry(sourceID: String?, in context: inout BattleState) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction, let sourceID,
              let source = context.roster.combatant(for: sourceID), source.isAlive else { return [] }
        let triggers = context.modifiers(for: sourceID).triggers
        var events: [ActionEvent] = []
        if triggers.spentReagents, context.claimHeroTalent("spentReagents", actorID: sourceID) {
            events.append(contentsOf: heroTalentMana(
                to: source.combatant,
                source: source.combatant,
                name: "Spent Reagents",
                in: &context,
            ))
        }
        if triggers.returningBloom, context.claimHeroTalent("returningBloom", actorID: sourceID) {
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
        if empowered, triggers.barkweave, context.claimHeroTalent("barkweave", actorID: actor.id) {
            context.removeTalentPoint(.thorns, from: context.roster.enemy.combatant)
        }
        guard amount > 0 else { return events }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].spentMana = true
        let hero = context.roster.hero.combatant
        if actor.role == .companion, context.roster.hero.isAlive, context.heroModifiers.triggers.sharedCurrent,
           context.claimHeroTalent("sharedCurrent", actorID: hero.id) {
            context.removeTalentPoint(.poison, from: hero)
        }
        if context.roster.hero.isAlive, context.roster.companion.isAlive,
           context.heroTalents.history[hero.id]?.spentMana == true,
           context.heroTalents.history[context.roster.companion.id]?.spentMana == true,
           context.heroModifiers.triggers.groveAccord, context.claimHeroTalent("groveAccord", actorID: hero.id) {
            for target in [hero, context.roster.companion.combatant] {
                events.append(contentsOf: heroTalentThorns(to: target, source: hero, name: "Grove Accord", in: &context))
            }
        }
        return events
    }

    static func heroTalentBlockGainReduction(target: Combatant, amount: Int, in context: inout BattleState) -> Int {
        guard amount > 0, target.role == .enemy, context.allowsHeroTalentReaction,
              context.roster.hero.isAlive, context.roster.companion.isAlive,
              context.heroModifiers.triggers.perfectPurity,
              !context.hasTalentDebuff(on: context.roster.hero.combatant),
              !context.hasTalentDebuff(on: context.roster.companion.combatant),
              context.claimHeroTalent("perfectPurity", actorID: context.roster.hero.id) else { return 0 }
        return 1
    }
}

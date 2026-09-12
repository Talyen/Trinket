import TrinketContent
import TrinketCore

extension CombatTriggerEngine {
    static func captureHeroOutcome(_ facts: ResolvedActionFacts, in context: inout BattleState) {
        let actor = facts.action.actor
        guard context.hasHeroCard(for: actor.id) else { return }
        let keywords = facts.damageKeywords
        if keywords.contains(.poison), context.modifiers(for: actor.id).triggers.dissolvingFumes {
            context.removeTalentPoint(.thorns, from: context.roster.enemy.combatant)
        }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastPlaySerial = context.resolution.cardTalents?
            .playSerial ?? -1
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastDamageKeywords = keywords
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastGrantedGold = false
        if keywords.contains(.stun) {
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].playedStun = true
        }
    }

    static func finishHeroCard(actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if context.roster.health(for: actor) > 0, context.resolution.cardTalents?.preparations.contains(.stealGold) == true {
            events.append(contentsOf: context.grantGoldEvent(
                2, to: actor, abilityName: "Paid in Full", isTheft: true, isDirectCardGain: true,
            ))
        }
        guard let card = context.resolution.finishCardTalents(),
              let outcome = context.resolution.cardOutcome(for: actor.id) else { return events }
        events.append(contentsOf: CombatCheckpoint.cardCompletion(actor.id).resolve([
            { heroPoisonCard(outcome, actor: actor, in: &$0) },
            { heroRestorationCard(card, outcome: outcome, actor: actor, in: &$0) },
            { heroFortuneCard(card, outcome: outcome, actor: actor, in: &$0) },
        ], in: &context))
        guard context.roster.health(for: actor) > 0 else { return events }
        var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
        if history.lastPlaySerial == card.playSerial {
            history.lastDamageKeywords = outcome.damageKeywords
            history.lastGrantedGold = card.grantedGold
        }
        history.tiers.insert(card.tier)
        history.playedStun = history.playedStun || outcome.damageKeywords.contains(.stun)
        history.preparedHeal = history.preparedHeal || card.preparedHeal
        context.heroTalents.history[actor.id] = history
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.fullHouse, history.tiers.count == 3 {
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].tiers = []
            events.append(contentsOf: heroTalentGold(to: actor, amount: 5, name: "Full House", in: &context))
            if let owner = context.roster.participant(for: actor) {
                events.append(contentsOf: drawCards(1, for: owner, actor: actor, abilityName: "Full House", in: &context))
            }
        }
        return events
    }

    private static func heroPoisonCard(_ outcome: ResolvedActionFacts, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard outcome.damageKeywords.contains(.poison) else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        let companion = context.roster.companion.combatant
        var events: [ActionEvent] = []
        if triggers.firstBloom {
            events.append(contentsOf: heroTalentMana(to: companion, source: actor, name: "First Bloom", in: &context))
        }
        if triggers.reactiveCoating {
            events.append(contentsOf: heroTalentThorns(to: actor, source: actor, name: "Reactive Coating", in: &context))
        }
        if triggers.safeHandling {
            context.removeTalentPoint(.burn, from: actor)
        }
        if triggers.livingBark, context.hasTalentStatus(.thorns, on: actor) {
            events.append(contentsOf: heroTalentBlock(to: actor, source: actor, name: "Living Bark", in: &context))
        }
        if triggers.coolMoss {
            context.removeTalentPoint(.burn, from: companion)
        }
        return events
    }

    private static func heroRestorationCard(
        _ card: HeroTalentCardFacts,
        outcome: ResolvedActionFacts,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        let enemy = context.roster.enemy.combatant
        let companion = context.roster.companion.combatant
        var events: [ActionEvent] = []
        if outcome.cleanses {
            if triggers.clearSolution, card.removedDebuffs == 0 {
                events.append(contentsOf: heroTalentMana(to: actor, source: actor, name: "Clear Solution", in: &context))
            }
            if triggers.freshBatch {
                context.removeTalentPoint(.thorns, from: enemy)
            }
        }
        if card.restoredHealth {
            if triggers.coolingSalve {
                context.removeTalentPoint(.burn, from: actor)
            }
            if card.tier == .basic, triggers.restorativeFumes {
                context.removeTalentPoint(.shield, from: enemy)
            }
            if actor.role == .companion, context.roster.hero.isAlive {
                let hero = context.roster.hero.combatant
                let heroTriggers = context.heroModifiers.triggers
                if heroTriggers.sharedPrescription {
                    context.removeTalentPoint(.poison, from: hero)
                }
                if heroTriggers.pruningTouch {
                    context.removeTalentPoint(.thorns, from: enemy)
                }
            }
        }
        if card.restoredMana {
            if triggers.livingConduit {
                events.append(contentsOf: heroTalentThorns(to: companion, source: actor, name: "Living Conduit", in: &context))
            }
        }
        return events
    }

    private static func heroFortuneCard(
        _ card: HeroTalentCardFacts,
        outcome: ResolvedActionFacts,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if outcome.isRandom, outcome.damageKeywords.isEmpty {
            if triggers.consolationPrize {
                events.append(contentsOf: heroTalentGold(to: actor, name: "Consolation Prize", in: &context))
            }
            if triggers.falseOpening {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].falseOpening = true
            }
        }
        if outcome.isRandom, !outcome.damageKeywords.isEmpty {
            if triggers.houseCredit {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedGold = true
            }
            if triggers.improvisedAssault, !outcome.damageKeywords.contains(.physical) {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedPhysical = true
            }
        }
        if card.grantedGold {
            if triggers.luckyCharm,
               context.resolution.claim(.heroTalent("luckyCharm"), actorID: actor.id, cadence: .turn(context.turnCount)) {
                events.append(contentsOf: performRandomCleanses(
                    source: actor, target: actor, count: 1, abilityName: "Lucky Charm", in: &context,
                ))
            }
            if triggers.paidInFull {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparations.insert(.stealGold)
            }
        }
        if card.tier == .skill, triggers.luckyBreak {
            let runtime = context.roster.runtime(for: actor)
            let canHeal = (runtime?.currentHealth ?? 0) < (runtime?.maxHealth ?? 0)
                && !frozenTargetCannotBlockOrHeal(actor, in: context)
            let choice = Int.random(in: 0 ..< (canHeal ? 3 : 2), using: &context.rng)
            switch choice {
            case 0: events.append(contentsOf: heroTalentGold(to: actor, name: "Lucky Break", in: &context))
            case 1: events.append(contentsOf: heroTalentBlock(to: actor, source: actor, name: "Lucky Break", in: &context))
            default: events.append(contentsOf: heroTalentHeal(to: actor, source: actor, name: "Lucky Break", in: &context))
            }
        }
        return events
    }
}

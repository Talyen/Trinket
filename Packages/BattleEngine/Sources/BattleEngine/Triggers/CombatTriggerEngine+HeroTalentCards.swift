import TrinketContent
import TrinketCore

extension CombatTriggerEngine {
    static func captureHeroOutcome(original: Ability, resolved: Ability, actor: Combatant, in context: inout BattleState) {
        guard context.hasHeroCard(for: actor.id), context.heroTalents.cards.last?.capturedOutcome == false else { return }
        var keywords: Set<Keyword> = []
        for component in resolved.damageComponents where component.target != .actor {
            var amount = component.amount
            if let condition = component.condition {
                if BattleConditionEvaluator.isMet(condition, actor: actor, in: context) {
                    amount += component.bonusAmount
                } else if component.bonusAmount == 0 {
                    continue
                }
            }
            if amount > 0 {
                keywords.insert(component.keyword)
            }
        }
        var cleanses = false
        for targeted in resolved.targetedEffects {
            if let condition = targeted.condition,
               !BattleConditionEvaluator.isMet(condition, actor: actor, in: context) {
                continue
            }
            switch targeted.effect.kind {
            case .burn, .poison, .bleed, .controlMeter:
                if (targeted.effect.potency ?? 0) > 0 {
                    keywords.insert(targeted.effect.keyword)
                }
            case .cleanse, .cleanseRandom, .cleanseHealPerDebuff, .panacea: cleanses = true
            default: break
            }
        }
        if keywords.contains(.poison), context.modifiers(for: actor.id).triggers.dissolvingFumes,
           context.claimHeroTalent("dissolvingFumes", actorID: actor.id) {
            context.removeTalentPoint(.thorns, from: context.roster.enemy.combatant)
        }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastPlaySerial = context.heroTalents.cards.last?
            .playSerial ?? -1
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastDamageKeywords = keywords
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastGrantedGold = false
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].tiers.insert(resolved.tier)
        if keywords.contains(.poison) {
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].playedPoison = true
        }
        if keywords.contains(.stun) {
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].playedStun = true
        }
        context.mutateHeroCard {
            $0.capturedOutcome = true
            $0.isRandom = original.outcomeBranches != nil
            $0.damageKeywords = keywords
            $0.cleanses = cleanses
        }
    }

    static func finishHeroCard(actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let card = context.heroTalents.cards.popLast() else { return [] }
        guard context.roster.health(for: actor) > 0 else { return [] }
        var events = heroPoisonCard(card, actor: actor, in: &context)
        events.append(contentsOf: heroRestorationCard(card, actor: actor, in: &context))
        events.append(contentsOf: heroFortuneCard(card, actor: actor, in: &context))
        var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
        if history.lastPlaySerial == card.playSerial {
            history.lastDamageKeywords = card.damageKeywords
            history.lastGrantedGold = card.grantedGold
        }
        history.tiers.insert(card.tier)
        history.playedPoison = history.playedPoison || card.damageKeywords.contains(.poison)
        history.restoredHealth = history.restoredHealth || card.restoredHealth
        history.playedStun = history.playedStun || card.damageKeywords.contains(.stun)
        history.preparedHeal = history.preparedHeal || card.preparedHeal
        context.heroTalents.history[actor.id] = history
        for targetID in card.preparedBlockIgnore {
            context.heroTalents.history[targetID, default: HeroTalentHistory()].preparedBlockIgnore = true
        }
        for targetID in card.preparedCoin {
            context.heroTalents.history[targetID, default: HeroTalentHistory()].preparedCoin = true
        }
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.fullHouse, history.tiers.count == 3,
           context.claimHeroTalent("fullHouse", actorID: actor.id) {
            events.append(contentsOf: heroTalentGold(to: actor, name: "Full House", in: &context))
        }
        return events
    }

    private static func heroPoisonCard(_ card: HeroTalentCardFacts, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard card.damageKeywords.contains(.poison) else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        let companion = context.roster.companion.combatant
        var events: [ActionEvent] = []
        if triggers.reactiveCoating, context.claimHeroTalent("reactiveCoating", actorID: actor.id) {
            events.append(contentsOf: heroTalentThorns(to: actor, source: actor, name: "Reactive Coating", in: &context))
        }
        if triggers.safeHandling, context.claimHeroTalent("safeHandling", actorID: actor.id) {
            context.removeTalentPoint(.burn, from: actor)
        }
        if triggers.unstableCulture, context.claimHeroTalent("unstableCulture", actorID: actor.id),
           BattleChance.succeeds(probability: 0.25, using: &context.rng) {
            events.append(contentsOf: heroTalentDamage(.burn, source: actor, in: &context))
        }
        if triggers.livingBark, context.hasTalentStatus(.thorns, on: actor),
           context.claimHeroTalent("livingBark", actorID: actor.id) {
            events.append(contentsOf: heroTalentBlock(to: actor, source: actor, name: "Living Bark", in: &context))
        }
        if triggers.coolMoss, context.claimHeroTalent("coolMoss", actorID: actor.id) {
            context.removeTalentPoint(.burn, from: companion)
        }
        return events
    }

    private static func heroRestorationCard(_ card: HeroTalentCardFacts, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        let enemy = context.roster.enemy.combatant
        let companion = context.roster.companion.combatant
        var events: [ActionEvent] = []
        if card.cleanses {
            if triggers.clearSolution, card.removedDebuffs == 0,
               context.claimHeroTalent("clearSolution", actorID: actor.id) {
                events.append(contentsOf: heroTalentMana(to: actor, source: actor, name: "Clear Solution", in: &context))
            }
            if triggers.freshBatch, context.claimHeroTalent("freshBatch", actorID: actor.id) {
                context.removeTalentPoint(.thorns, from: enemy)
            }
        }
        if card.restoredHealth {
            if triggers.coolingSalve, context.claimHeroTalent("coolingSalve", actorID: actor.id) {
                context.removeTalentPoint(.burn, from: actor)
            }
            if card.tier == .basic, triggers.restorativeFumes,
               context.claimHeroTalent("restorativeFumes", actorID: actor.id) {
                context.removeTalentPoint(.shield, from: enemy)
            }
            if actor.role == .companion, context.roster.hero.isAlive {
                let hero = context.roster.hero.combatant
                let heroTriggers = context.heroModifiers.triggers
                if heroTriggers.sharedPrescription, context.claimHeroTalent("sharedPrescription", actorID: hero.id) {
                    context.removeTalentPoint(.poison, from: hero)
                }
                if heroTriggers.pruningTouch, context.claimHeroTalent("pruningTouch", actorID: hero.id) {
                    context.removeTalentPoint(.thorns, from: enemy)
                }
            }
        }
        if card.restoredMana {
            if triggers.firstBloom,
               card.previousDamageKeywords.contains(.poison),
               context.claimHeroTalent("firstBloom", actorID: actor.id) {
                events.append(contentsOf: heroTalentMana(to: companion, source: actor, name: "First Bloom", in: &context))
            }
            if triggers.livingConduit, context.claimHeroTalent("livingConduit", actorID: actor.id) {
                events.append(contentsOf: heroTalentThorns(to: companion, source: actor, name: "Living Conduit", in: &context))
            }
        }
        for targetID in card.gainedThornsOn.sorted() {
            if context.modifiers(for: targetID).triggers.thornShedding,
               let target = context.roster.combatant(for: targetID), target.isAlive,
               context.claimHeroTalent("thornShedding", actorID: targetID) {
                context.removeTalentPoint(.poison, from: target.combatant)
            }
        }
        return events
    }

    private static func heroFortuneCard(_ card: HeroTalentCardFacts, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if card.isRandom, card.damageKeywords.isEmpty {
            if triggers.consolationPrize, context.claimHeroTalent("consolationPrize", actorID: actor.id) {
                events.append(contentsOf: heroTalentGold(to: actor, name: "Consolation Prize", in: &context))
            }
            if triggers.falseOpening, context.claimHeroTalent("falseOpening", actorID: actor.id) {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].falseOpening = true
            }
        }
        if card.isRandom, !card.damageKeywords.isEmpty {
            if triggers.houseCredit, context.claimHeroTalent("houseCredit", actorID: actor.id) {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedGold = true
            }
            if triggers.improvisedAssault, !card.damageKeywords.contains(.physical),
               context.claimHeroTalent("improvisedAssault", actorID: actor.id) {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedPhysical = true
            }
        }
        if card.grantedGold {
            if triggers.luckyCharm, context.claimHeroTalent("luckyCharm", actorID: actor.id) {
                context.removeTalentPoint(.poison, from: actor)
            }
            if triggers.sleightOfCoin, context.heroTalents.history[actor.id]?.preparedCoin == true,
               context.claimHeroTalent("sleightOfCoin", actorID: actor.id) {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedCoin = false
                context.removeTalentPoint(.thorns, from: context.roster.enemy.combatant)
            }
        }
        if card.tier == .skill, triggers.luckyBreak, context.claimHeroTalent("luckyBreak", actorID: actor.id) {
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

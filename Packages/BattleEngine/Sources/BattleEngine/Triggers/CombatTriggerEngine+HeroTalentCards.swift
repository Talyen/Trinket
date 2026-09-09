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
        if keywords.contains(.poison), context.modifiers(for: actor.id).triggers.dissolvingFumes {
            context.removeTalentPoint(.thorns, from: context.roster.enemy.combatant)
        }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastPlaySerial = context.heroTalents.cards.last?
            .playSerial ?? -1
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastDamageKeywords = keywords
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].lastGrantedGold = false
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
        var events: [ActionEvent] = []
        if context.roster.health(for: actor) > 0, context.heroTalents.cards.last?.preparations.contains(.stealGold) == true {
            events.append(contentsOf: context.grantGoldEvent(
                2, to: actor, abilityName: "Paid in Full", isTheft: true, isDirectCardGain: true,
            ))
        }
        guard let card = context.heroTalents.cards.popLast() else { return events }
        guard context.roster.health(for: actor) > 0 else { return [] }
        events.append(contentsOf: heroPoisonCard(card, actor: actor, in: &context))
        events.append(contentsOf: heroRestorationCard(card, actor: actor, in: &context))
        events.append(contentsOf: heroFortuneCard(card, actor: actor, in: &context))
        var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
        if history.lastPlaySerial == card.playSerial {
            history.lastDamageKeywords = card.damageKeywords
            history.lastGrantedGold = card.grantedGold
        }
        history.tiers.insert(card.tier)
        history.playedStun = history.playedStun || card.damageKeywords.contains(.stun)
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

    private static func heroPoisonCard(_ card: HeroTalentCardFacts, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard card.damageKeywords.contains(.poison) else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        let companion = context.roster.companion.combatant
        var events: [ActionEvent] = []
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

    private static func heroRestorationCard(_ card: HeroTalentCardFacts, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        let enemy = context.roster.enemy.combatant
        let companion = context.roster.companion.combatant
        var events: [ActionEvent] = []
        if card.cleanses {
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
            if triggers.firstBloom, card.previousDamageKeywords.contains(.poison) {
                events.append(contentsOf: heroTalentMana(to: companion, source: actor, name: "First Bloom", in: &context))
            }
            if triggers.livingConduit {
                events.append(contentsOf: heroTalentThorns(to: companion, source: actor, name: "Living Conduit", in: &context))
            }
        }
        return events
    }

    private static func heroFortuneCard(_ card: HeroTalentCardFacts, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if card.isRandom, card.damageKeywords.isEmpty {
            if triggers.consolationPrize {
                events.append(contentsOf: heroTalentGold(to: actor, name: "Consolation Prize", in: &context))
            }
            if triggers.falseOpening {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].falseOpening = true
            }
        }
        if card.isRandom, !card.damageKeywords.isEmpty {
            if triggers.houseCredit {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedGold = true
            }
            if triggers.improvisedAssault, !card.damageKeywords.contains(.physical) {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedPhysical = true
            }
        }
        if card.grantedGold {
            if triggers.luckyCharm {
                context.removeTalentPoint(.poison, from: actor)
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

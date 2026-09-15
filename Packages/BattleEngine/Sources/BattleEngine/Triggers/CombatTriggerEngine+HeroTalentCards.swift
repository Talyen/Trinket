import TrinketContent
import TrinketCore

// MARK: - Card play

package extension CombatTriggerEngine {
    /// Internal on purpose: `ResolvedActionFacts` is an internal type.
    internal static func captureHeroOutcome(_ facts: ResolvedActionFacts, in context: inout BattleState) {
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

// MARK: - Card hits

package extension CombatTriggerEngine {
    static func heroCardDamageBonus(keyword: Keyword?, sourceID: String?, in context: inout BattleState) -> Int {
        guard let sourceID, let keyword, context.hasHeroCard(for: sourceID),
              context.roster.combatant(for: sourceID)?.isAlive == true else { return 0 }
        let triggers = context.modifiers(for: sourceID).triggers
        let history = context.heroTalents.history[sourceID, default: HeroTalentHistory()]
        var bonus = 0
        if keyword == .poison {
            if triggers.reactiveSediment, context.resolution.cardTalents?.previousDamageKeywords.contains(.burn) == true {
                bonus += 1
            }
            if triggers.entanglingGrowth, context.roster.companion.isAlive,
               context.heroTalents.history[context.roster.companion.id]?.playedStun == true {
                bonus += 1
            }
        }
        if keyword == .physical {
            if history.preparedPhysical, context.claimHeroCardBonus("improvisedAssault", actorID: sourceID) {
                context.heroTalents.history[sourceID, default: HeroTalentHistory()].preparedPhysical = false
                bonus += 2
            }
        }
        return context.paced(bonus, sourceActorID: sourceID)
    }

    static func heroCardBlockIgnore(keyword: Keyword?, sourceID: String?, in context: inout BattleState) -> Int {
        guard let sourceID, context.hasHeroCard(for: sourceID),
              context.roster.combatant(for: sourceID)?.isAlive == true else { return 0 }
        var ignored = 0
        if keyword == .poison, context.modifiers(for: sourceID).triggers.rootPassage,
           context.roster.companion.isAlive,
           context.hasTalentStatus(.thorns, on: context.roster.companion.combatant) {
            ignored += 1
        }
        return ignored
    }

    static func afterHeroCardHit(
        keyword: Keyword?,
        sourceID: String?,
        critical: Bool,
        fullyBlocked: Bool,
        blockBroken: Bool,
        targetWasFrozen: Bool,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let sourceID, context.hasHeroCard(for: sourceID),
              let runtime = context.roster.combatant(for: sourceID), runtime.isAlive else { return [] }
        let actor = runtime.combatant
        let triggers = context.modifiers(for: sourceID).triggers
        let companion = context.roster.companion.combatant
        var events: [ActionEvent] = []
        if critical, triggers.smokeTrick {
            context.removeTalentPoint(.burn, from: actor)
        }
        if fullyBlocked, triggers.missedOpportunity {
            events.append(contentsOf: heroTalentBlock(to: actor, source: actor, name: "Missed Opportunity", in: &context))
        }
        guard keyword == .physical else { return events }
        if critical, triggers.cleanCut {
            context.removeTalentPoint(.poison, from: actor)
        }
        if blockBroken, triggers.crackedGuard {
            events.append(contentsOf: heroTalentHeal(to: companion, source: actor, name: "Cracked Guard", in: &context))
        }
        if targetWasFrozen, triggers.coldRead {
            events.append(contentsOf: heroTalentHeal(to: actor, source: actor, name: "Cold Read", in: &context))
        }
        if fullyBlocked, triggers.feignedMiss {
            events.append(contentsOf: heroTalentDamage(.stun, source: actor, in: &context))
        }
        if triggers.prismaticEdge, context.claimHeroCardBonus("prismaticEdge", actorID: sourceID),
           BattleChance.succeeds(probability: 0.25, using: &context.rng) {
            let keyword: Keyword = Bool.random(using: &context.rng) ? .burn : .freeze
            events.append(contentsOf: heroTalentDamage(keyword, source: actor, in: &context))
        }
        return events
    }

    static func afterHeroTalentHealthLoss(
        target: Combatant,
        sourceID: String?,
        keyword: Keyword?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if context.heroTalents.enemyTurnActive {
            context.heroTalents.healthLostDuringEnemyTurn.insert(target.id)
        }
        guard context.allowsHeroTalentReaction else { return [] }
        var events: [ActionEvent] = []
        if keyword == .poison, target.role == .enemy, let sourceID,
           let source = context.roster.combatant(for: sourceID), source.isAlive,
           context.modifiers(for: sourceID).triggers.barbedSpores {
            events.append(contentsOf: heroTalentThorns(
                to: context.roster.companion.combatant,
                source: source.combatant,
                name: "Barbed Spores",
                in: &context,
            ))
        }
        return events
    }

    static func afterHeroTalentDodge(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction, context.roster.health(for: actor) > 0 else { return [] }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].dodgeGrowth = 0
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if triggers.passingLuck {
            events.append(contentsOf: heroTalentHeal(
                to: context.roster.companion.combatant,
                source: actor,
                name: "Passing Luck",
                in: &context,
            ))
        }
        if triggers.blindSpot {
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparations.insert(.ignorePhysicalBlock)
        }
        if actor.role == .companion, context.roster.hero.isAlive, context.heroModifiers.triggers.scatteredCaltrops {
            events.append(contentsOf: heroTalentThorns(
                to: context.roster.hero.combatant,
                source: context.roster.hero.combatant,
                name: "Scattered Caltrops",
                in: &context,
            ))
        }
        return events
    }
}

// MARK: - Card restoration

package extension CombatTriggerEngine {
    static func heroCardHealingBonus(request: HealRequest, amount: Int, in context: inout BattleState) -> Int {
        guard request.isDirectCardHeal, amount > 0, let sourceID = request.sourceActorID,
              let runtime = context.roster.combatant(for: sourceID) else { return 0 }
        let source = runtime.combatant
        let target = request.target
        guard context.hasHeroCard(for: source.id), context.roster.health(for: source) > 0,
              context.roster.health(for: target) > 0,
              context.roster.health(for: target) < context.roster.maxHealth(for: target),
              !frozenTargetCannotBlockOrHeal(target, in: context) else { return 0 }
        let triggers = context.modifiers(for: source.id).triggers
        var bonus = 0
        if triggers.fortifyingTonic, context.hasTalentStatus(.poison, on: target) {
            bonus += 1
        }
        if triggers.springSap, context.hasTalentStatus(.thorns, on: target) {
            bonus += 1
        }
        if context.heroTalents.history[source.id]?.preparedHeal == true,
           context.claimHeroCardBonus("measuredDose", actorID: source.id) {
            context.heroTalents.history[source.id, default: HeroTalentHistory()].preparedHeal = false
            bonus += 1
        }
        return context.paced(bonus, sourceActorID: source.id)
    }

    static func afterHeroCardHeal(
        request: HealRequest,
        restored: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard request.isDirectCardHeal, let sourceID = request.sourceActorID,
              let runtime = context.roster.combatant(for: sourceID) else { return [] }
        let source = runtime.combatant
        let target = request.target
        guard context.hasHeroCard(for: source.id), context.roster.health(for: source) > 0,
              target.role != .enemy else { return [] }
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        guard restored > 0 else { return events }
        context.mutateHeroCard { $0.restoredHealth = true }
        if triggers.cleansingDew {
            context.removeTalentPoint(.poison, from: target)
        }
        if triggers.sharedRoots, target.role == .companion {
            context.removeTalentPoint(.burn, from: source)
        }
        if triggers.verdantShelter {
            events.append(contentsOf: heroTalentThorns(to: target, source: source, name: "Verdant Shelter", in: &context))
        }
        return events
    }

    static func heroCardManaBonus(source: Combatant, target: Combatant, in context: inout BattleState) -> Int {
        guard context.hasHeroCard(for: source.id), let runtime = context.roster.runtime(for: target),
              runtime.isAlive, runtime.currentMana < runtime.maxMana,
              context.modifiers(for: source.id).triggers.deepRoots,
              context.hasTalentStatus(.thorns, on: source) else { return 0 }
        return 1
    }

    static func afterHeroCardMana(source: Combatant, restored: Int, in context: inout BattleState) {
        guard restored > 0, context.hasHeroCard(for: source.id) else { return }
        context.mutateHeroCard { $0.restoredMana = true }
        if context.modifiers(for: source.id).triggers.measuredDose {
            context.mutateHeroCard { $0.preparedHeal = true }
        }
    }

    static func heroCardGoldBonus(source: Combatant, amount: Int, in context: inout BattleState) -> Int {
        guard amount > 0, context.hasHeroCard(for: source.id) else { return 0 }
        context.mutateHeroCard { $0.grantedGold = true }
        if context.heroTalents.history[source.id]?.lastPlaySerial == context.resolution.cardTalents?.playSerial {
            context.heroTalents.history[source.id, default: HeroTalentHistory()].lastGrantedGold = true
        }
        guard context.heroTalents.history[source.id]?.preparedGold == true,
              context.claimHeroCardBonus("houseCredit", actorID: source.id) else { return 0 }
        context.heroTalents.history[source.id, default: HeroTalentHistory()].preparedGold = false
        return 1
    }

    static func heroCardGoldCritical(source: Combatant, in context: inout BattleState) -> Bool {
        guard context.hasHeroCard(for: source.id), context.modifiers(for: source.id).triggers.sleightOfCoin else { return false }
        if let critical = context.resolution.cardTalents?.criticalGold {
            return critical
        }
        let critical = CriticalChanceEngine.rollSucceeds(
            actorID: source.id, defender: context.roster.enemy.combatant, in: &context,
        )
        context.mutateHeroCard { $0.criticalGold = critical }
        return critical
    }

    static func afterHeroCleanse(
        source: Combatant,
        target: Combatant,
        removed: [Keyword],
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if source.role != .enemy, target.role != .enemy,
           context.roster.health(for: source) > 0,
           context.modifiers(for: source.id).triggers.lessonLearned {
            context.roster.mutateRuntime(for: target) { $0.talents.turn.cleansedKeywordProtection.formUnion(removed) }
        }
        guard context.allowsHeroTalentReaction, source.role != .enemy, target.role != .enemy,
              context.roster.health(for: source) > 0, context.roster.health(for: target) > 0 else { return [] }
        if context.hasHeroCard(for: source.id) {
            context.mutateHeroCard { $0.removedDebuffs += removed.count }
        }
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        if triggers.clearMind, (context.roster.runtime(for: target)?.maxMana ?? 0) > 0,
           context.claimHeroTalent("clearMind:" + target.id, actorID: source.id, battle: true) {
            context.appendEffect(.maximumManaBonus(1), to: target, sourceID: source.id, remainingTurns: 0)
        }
        if removed.contains(.burn), triggers.heatRecovery {
            events.append(contentsOf: heroTalentMana(to: target, source: source, name: "Heat Recovery", in: &context))
        }
        if removed.contains(.poison), triggers.antitoxinCoating {
            events.append(contentsOf: heroTalentThorns(to: target, source: source, name: "Antitoxin Coating", in: &context))
        }
        if !removed.isEmpty {
            if triggers.perfectPurity {
                context.heroTalents.history[target.id, default: HeroTalentHistory()].preparations.insert(.poisonDamage)
            }
            if !context.hasTalentDebuff(on: target), triggers.cleanBreak,
               let owner = context.roster.participant(for: source),
               BattleCardCombatEngine.drawFirstCard(matching: .poison, for: owner, context: &context) != nil {
                events.append(context.nextEvent(
                    kind: .effect, effectKind: .cardsDrawn, actorName: source.name,
                    abilityName: "Clean Break", target: source, amount: 1, keyword: .poison,
                ))
            }
        }
        return events
    }
}

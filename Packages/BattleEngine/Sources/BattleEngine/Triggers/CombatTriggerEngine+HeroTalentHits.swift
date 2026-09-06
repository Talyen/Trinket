import TrinketContent
import TrinketCore

extension CombatTriggerEngine {
    static func heroCardDamageBonus(keyword: Keyword?, sourceID: String?, in context: inout BattleState) -> Int {
        guard let sourceID, let keyword, context.hasHeroCard(for: sourceID),
              context.roster.combatant(for: sourceID)?.isAlive == true else { return 0 }
        let triggers = context.modifiers(for: sourceID).triggers
        let history = context.heroTalents.history[sourceID, default: HeroTalentHistory()]
        var bonus = 0
        if keyword == .poison {
            if triggers.reactiveSediment, context.heroTalents.cards.last?.previousDamageKeywords.contains(.burn) == true,
               context.claimHeroTalent("reactiveSediment", actorID: sourceID) {
                bonus += 1
            }
            if triggers.entanglingGrowth, context.roster.companion.isAlive,
               context.heroTalents.history[context.roster.companion.id]?.playedStun == true,
               context.claimHeroTalent("entanglingGrowth", actorID: sourceID) {
                bonus += 1
            }
        }
        if keyword == .physical {
            if triggers.paidInFull, context.heroTalents.cards.last?.previousGrantedGold == true,
               context.claimHeroTalent("paidInFull", actorID: sourceID) {
                bonus += 1
            }
            if history.preparedPhysical, context.claimHeroCardBonus("improvisedAssault", actorID: sourceID) {
                context.heroTalents.history[sourceID, default: HeroTalentHistory()].preparedPhysical = false
                bonus += 1
            }
        }
        return context.paced(bonus, sourceActorID: sourceID)
    }

    static func heroCardBlockIgnore(keyword: Keyword?, sourceID: String?, in context: inout BattleState) -> Int {
        guard let sourceID, context.hasHeroCard(for: sourceID),
              context.roster.combatant(for: sourceID)?.isAlive == true else { return 0 }
        var ignored = 0
        if context.heroTalents.history[sourceID]?.preparedBlockIgnore == true,
           context.claimHeroCardBonus("cleanBreak", actorID: sourceID) {
            context.heroTalents.history[sourceID, default: HeroTalentHistory()].preparedBlockIgnore = false
            ignored += 1
        }
        if keyword == .poison, context.modifiers(for: sourceID).triggers.rootPassage,
           context.roster.companion.isAlive,
           context.hasTalentStatus(.thorns, on: context.roster.companion.combatant),
           context.claimHeroTalent("rootPassage", actorID: sourceID) {
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
        if critical, triggers.smokeTrick, context.claimHeroTalent("smokeTrick", actorID: sourceID) {
            context.removeTalentPoint(.burn, from: actor)
        }
        if fullyBlocked, triggers.missedOpportunity, context.claimHeroTalent("missedOpportunity", actorID: sourceID) {
            events.append(contentsOf: heroTalentBlock(to: actor, source: actor, name: "Missed Opportunity", in: &context))
        }
        guard keyword == .physical else { return events }
        if critical, triggers.cleanCut, context.claimHeroTalent("cleanCut", actorID: sourceID) {
            context.removeTalentPoint(.poison, from: actor)
        }
        if blockBroken, triggers.crackedGuard, context.claimHeroTalent("crackedGuard", actorID: sourceID) {
            events.append(contentsOf: heroTalentHeal(to: companion, source: actor, name: "Cracked Guard", in: &context))
        }
        if targetWasFrozen, triggers.coldRead, context.claimHeroTalent("coldRead", actorID: sourceID) {
            events.append(contentsOf: heroTalentHeal(to: actor, source: actor, name: "Cold Read", in: &context))
        }
        if fullyBlocked, triggers.feignedMiss, context.claimHeroTalent("feignedMiss", actorID: sourceID) {
            events.append(contentsOf: heroTalentDamage(.stun, source: actor, in: &context))
        }
        if triggers.prismaticEdge, context.claimHeroTalent("prismaticEdge", actorID: sourceID),
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
        if target.role != .enemy, context.roster.health(for: target) > 0,
           context.roster.health(for: target) * 2 < context.roster.maxHealth(for: target),
           context.modifiers(for: target.id).triggers.shelterSeed,
           context.claimHeroTalent("shelterSeed", actorID: target.id, battle: true) {
            events.append(contentsOf: heroTalentThorns(
                to: context.roster.companion.combatant,
                source: target,
                name: "Shelter Seed",
                in: &context,
            ))
        }
        if keyword == .poison, target.role == .enemy, let sourceID,
           let source = context.roster.combatant(for: sourceID), source.isAlive,
           context.modifiers(for: sourceID).triggers.barbedSpores,
           context.claimHeroTalent("barbedSpores", actorID: sourceID) {
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
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].dodged = true
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.sleightOfCoin {
            if context.heroTalents.cards.isEmpty {
                context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparedCoin = true
            } else {
                context.mutateHeroCard { $0.preparedCoin.insert(actor.id) }
            }
        }
        var events: [ActionEvent] = []
        if triggers.passingLuck, context.claimHeroTalent("passingLuck", actorID: actor.id) {
            events.append(contentsOf: heroTalentHeal(
                to: context.roster.companion.combatant,
                source: actor,
                name: "Passing Luck",
                in: &context,
            ))
        }
        if triggers.blindSpot, context.claimHeroTalent("blindSpot", actorID: actor.id) {
            context.removeTalentPoint(.shield, from: context.roster.enemy.combatant)
        }
        if actor.role == .companion, context.roster.hero.isAlive, context.heroModifiers.triggers.scatteredCaltrops,
           context.claimHeroTalent("scatteredCaltrops", actorID: context.roster.hero.id) {
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

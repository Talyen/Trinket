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
            if triggers.reactiveSediment, context.heroTalents.cards.last?.previousDamageKeywords.contains(.burn) == true {
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
        if triggers.prismaticEdge, BattleChance.succeeds(probability: 0.25, using: &context.rng) {
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

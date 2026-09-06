import TrinketContent
import TrinketCore

extension CombatTriggerEngine {
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
        if triggers.fortifyingTonic, context.hasTalentStatus(.poison, on: target),
           context.claimHeroTalent("fortifyingTonic", actorID: source.id) {
            bonus += 1
        }
        if triggers.springSap, context.hasTalentStatus(.thorns, on: target),
           context.claimHeroTalent("springSap", actorID: source.id) {
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
        overflow: Int,
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
        if overflow > 0, triggers.reclaimedReagents,
           context.claimHeroTalent("reclaimedReagents", actorID: source.id, battle: true) {
            events.append(contentsOf: heroTalentMana(to: target, source: source, name: "Reclaimed Reagents", in: &context))
        }
        guard restored > 0 else { return events }
        context.mutateHeroCard { $0.restoredHealth = true }
        context.heroTalents.history[source.id, default: HeroTalentHistory()].restoredHealth = true
        if triggers.cleansingDew, context.claimHeroTalent("cleansingDew", actorID: source.id) {
            context.removeTalentPoint(.poison, from: target)
        }
        if triggers.sharedRoots, target.role == .companion, context.claimHeroTalent("sharedRoots", actorID: source.id) {
            context.removeTalentPoint(.burn, from: source)
        }
        if triggers.verdantShelter, context.claimHeroTalent("verdantShelter", actorID: source.id) {
            events.append(contentsOf: heroTalentThorns(to: target, source: source, name: "Verdant Shelter", in: &context))
        }
        return events
    }

    static func heroCardManaBonus(source: Combatant, target: Combatant, in context: inout BattleState) -> Int {
        guard context.hasHeroCard(for: source.id), let runtime = context.roster.runtime(for: target),
              runtime.isAlive, runtime.currentMana < runtime.maxMana,
              context.modifiers(for: source.id).triggers.deepRoots,
              context.hasTalentStatus(.thorns, on: source),
              context.claimHeroTalent("deepRoots", actorID: source.id) else { return 0 }
        return 1
    }

    static func afterHeroCardMana(source: Combatant, restored: Int, in context: inout BattleState) {
        guard restored > 0, context.hasHeroCard(for: source.id) else { return }
        context.mutateHeroCard { $0.restoredMana = true }
        if context.modifiers(for: source.id).triggers.measuredDose,
           context.claimHeroTalent("measuredDose", actorID: source.id) {
            context.mutateHeroCard { $0.preparedHeal = true }
        }
    }

    static func heroCardGoldBonus(source: Combatant, amount: Int, in context: inout BattleState) -> Int {
        guard amount > 0, context.hasHeroCard(for: source.id) else { return 0 }
        context.mutateHeroCard { $0.grantedGold = true }
        if context.heroTalents.history[source.id]?.lastPlaySerial == context.heroTalents.cards.last?.playSerial {
            context.heroTalents.history[source.id, default: HeroTalentHistory()].lastGrantedGold = true
        }
        guard context.heroTalents.history[source.id]?.preparedGold == true,
              context.claimHeroCardBonus("houseCredit", actorID: source.id) else { return 0 }
        context.heroTalents.history[source.id, default: HeroTalentHistory()].preparedGold = false
        return 1
    }

    static func afterHeroCleanse(
        source: Combatant,
        target: Combatant,
        removed: [Keyword],
        in context: inout BattleState,
    ) -> [ActionEvent] {
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
        if removed.contains(.burn), triggers.heatRecovery, context.claimHeroTalent("heatRecovery", actorID: source.id) {
            events.append(contentsOf: heroTalentMana(to: target, source: source, name: "Heat Recovery", in: &context))
        }
        if removed.contains(.poison), triggers.antitoxinCoating, context.claimHeroTalent("antitoxinCoating", actorID: source.id) {
            events.append(contentsOf: heroTalentThorns(to: target, source: source, name: "Antitoxin Coating", in: &context))
        }
        if !removed.isEmpty, !context.hasTalentDebuff(on: target), triggers.cleanBreak,
           context.claimHeroTalent("cleanBreak", actorID: source.id) {
            if context.hasHeroCard(for: source.id) {
                context.mutateHeroCard { $0.preparedBlockIgnore.insert(target.id) }
            } else {
                context.heroTalents.history[target.id, default: HeroTalentHistory()].preparedBlockIgnore = true
            }
        }
        return events
    }
}

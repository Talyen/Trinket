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
        if overflow > 0, triggers.masterworkMixture {
            let other = target.role == .hero ? context.roster.companion : context.roster.hero
            let amount = min(overflow, max(0, other.maxHealth - other.currentHealth))
            if other.isAlive, amount > 0 {
                var transfer = HealRequest(
                    amount: amount, target: other.combatant, sourceActorID: source.id,
                    origin: .restoration(.health), logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: "Masterwork Mixture",
                        keyword: .health,
                    ),
                )
                transfer.amountBasis = .resolved
                events.append(contentsOf: HealingEngine.resolveHeal(transfer, in: &context).events)
            }
        }
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
        if context.heroTalents.history[source.id]?.lastPlaySerial == context.heroTalents.cards.last?.playSerial {
            context.heroTalents.history[source.id, default: HeroTalentHistory()].lastGrantedGold = true
        }
        guard context.heroTalents.history[source.id]?.preparedGold == true,
              context.claimHeroCardBonus("houseCredit", actorID: source.id) else { return 0 }
        context.heroTalents.history[source.id, default: HeroTalentHistory()].preparedGold = false
        return 1
    }

    static func heroCardGoldCritical(source: Combatant, in context: inout BattleState) -> Bool {
        guard context.hasHeroCard(for: source.id), context.modifiers(for: source.id).triggers.sleightOfCoin else { return false }
        if let critical = context.heroTalents.cards.last?.criticalGold {
            return critical
        }
        let critical = CriticalChanceEngine.rollSucceeds(
            keyword: .gold, actorID: source.id, defender: context.roster.enemy.combatant, in: &context,
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
            context.roster.mutateRuntime(for: target) { $0.cleansedKeywordProtection.formUnion(removed) }
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

import TrinketContent
import TrinketCore

// MARK: - Card play

package extension CombatTriggerEngine {
    static func finishHeroCard(actor _: Combatant, in context: inout BattleState) -> [ActionEvent] {
        _ = context.resolution.finishCardTalents()
        return []
    }
}

// MARK: - Card hits

package extension CombatTriggerEngine {
    static func afterHeroCardHit(
        keyword: Keyword?,
        sourceID: String?,
        critical: Bool,
        healthLost: Int,
        fullyBlocked: Bool,
        blockBroken: Bool,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let sourceID, context.hasHeroCard(for: sourceID),
              let runtime = context.roster.combatant(for: sourceID), runtime.isAlive else { return [] }
        let actor = runtime.combatant
        let triggers = context.modifiers(for: sourceID).triggers
        var events: [ActionEvent] = []
        if critical {
            context.mutateHeroCard { $0.didCriticalHit = true }
        }
        if keyword == .freeze {
            events.append(contentsOf: drawOnFreezeCardHit(healthLost: healthLost, actor: actor, in: &context))
        }
        if keyword == .freeze, critical, triggers.freezeCriticalRestoreMana > 0 {
            events.append(contentsOf: heroTalentMana(to: actor, source: actor, name: "Frost Circuit", in: &context))
        }
        if keyword == .poison, critical, triggers.poisonCritPreparesBleedCrit {
            context.roster.mutateRuntime(for: actor) { $0.talents.pending.guaranteedBleedCritical = true }
        }
        if keyword == .stun, critical, triggers.stunCriticalStealGold > 0,
           context.claimHeroCardBonus("Cutpurse Cut", actorID: sourceID) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.stunCriticalStealGold,
                to: actor,
                abilityName: "Cutpurse Cut",
                isTheft: true,
            ))
        }
        if keyword == .burn, critical, triggers.burnAttackCritDrawCard,
           context.claimHeroCardBonus("Ashen Arsenal", actorID: sourceID),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(
                1, for: owner, actor: actor, abilityName: "Ashen Arsenal", in: &context,
            ))
        }
        if keyword == .burn, triggers.burnPreparesBleedDamageBonus > 0 {
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextBleedDamageBonus = max(
                    $0.talents.pending.nextBleedDamageBonus,
                    triggers.burnPreparesBleedDamageBonus,
                )
            }
        }
        events.append(contentsOf: afterOtherCardHits(
            keyword: keyword, actor: actor,
            critical: critical, healthLost: healthLost, fullyBlocked: fullyBlocked,
            triggers: triggers, in: &context,
        ))
        guard keyword == .physical else { return events }
        events.append(contentsOf: afterPhysicalCardHit(
            actor: actor, sourceID: sourceID, critical: critical, blockBroken: blockBroken,
            triggers: triggers, in: &context,
        ))
        return events
    }

    private static func afterPhysicalCardHit(
        actor: Combatant,
        sourceID: String,
        critical: Bool,
        blockBroken: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if critical, triggers.physicalCritRemoveEnemyBlock {
            DefensePoolEngine.set(0, on: context.roster.enemy.combatant, in: &context)
        }
        if blockBroken, triggers.crackedGuard {
            context.roster.mutateRuntime(for: actor) { $0.talents.pending.nextAttackGuaranteedCritical = true }
        }
        guard triggers.physicalElementChancePercent > 0, triggers.physicalElementDamage > 0,
              context.claimHeroCardBonus("Prismatic Edge", actorID: sourceID),
              BattleChance.succeeds(probability: triggers.physicalElementChancePercent, using: &context.rng)
        else { return [] }
        let keyword: Keyword = Bool.random(using: &context.rng) ? .burn : .freeze
        return heroTalentDamage(
            keyword, amount: triggers.physicalElementDamage, source: actor,
            name: "Prismatic Edge", in: &context,
        )
    }

    private static func afterOtherCardHits(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        fullyBlocked: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if keyword == .burn, triggers.burnAttackBleedDamage > 0,
           context.claimHeroCardBonus("Bloodfire", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.burnAttackBleedChancePercent, using: &context.rng) {
            events.append(contentsOf: heroTalentDamage(
                .bleed, amount: triggers.burnAttackBleedDamage, source: actor,
                name: "Bloodfire", in: &context,
            ))
        }
        if fullyBlocked, triggers.blockedAttackFirstGold > 0,
           context.claimHeroTalent("Consolation Prize", actorID: actor.id, battle: true) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.blockedAttackFirstGold, to: actor, abilityName: "Consolation Prize",
            ))
        }
        if fullyBlocked, triggers.blockedAttackNextPhysicalDouble {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.doubleNextPhysicalAttack = true
                $0.talents.pending.nextPhysicalPreparedCardSerial = preparedCardSerial
            }
        }
        events.append(contentsOf: afterCompanionCardHit(
            keyword: keyword, actor: actor, critical: critical,
            healthLost: healthLost, triggers: triggers, in: &context,
        ))
        return events
    }

    static func afterHeroTalentHealthLoss(
        target: Combatant,
        sourceID: String?,
        keyword: Keyword?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction else { return [] }
        var events: [ActionEvent] = []
        if target.role == .hero,
           context.modifiers(for: target.id).triggers.healthLossManaGain > 0 {
            events.append(contentsOf: heroTalentMana(
                to: target, source: target, name: "Forbidden Lore", in: &context,
            ))
        }
        if target.role == .companion, sourceID == context.roster.enemy.id,
           context.roster.hero.isAlive,
           context.heroModifiers.triggers.poisonDoubleAfterCompanionHurt,
           context.roster.hasAffliction(.poison, on: context.roster.enemy.combatant) {
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.talents.pending.doubleNextPoisonDamage = true
            }
        }
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
        if triggers.dodgePreparesDoubleGoldSteal {
            context.roster.mutateRuntime(for: actor) { $0.talents.pending.doubleNextGoldSteal = true }
        }
        if triggers.dodgeNextAttackCritBonus > 0 {
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextAttackCriticalBonus = max(
                    $0.talents.pending.nextAttackCriticalBonus,
                    triggers.dodgeNextAttackCritBonus,
                )
            }
        }
        if triggers.dodgeBelowHalfDrawCard,
           context.roster.health(for: actor) * 2 < context.roster.maxHealth(for: actor),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(
                1, for: owner, actor: actor, abilityName: "Missed Opportunity", in: &context,
            ))
        }
        if triggers.passingLuck, context.roster.companion.isAlive {
            context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                $0.talents.pending.guaranteedCriticalAfterDodge = true
            }
        }
        if triggers.blindSpot {
            context.heroTalents.history[actor.id, default: HeroTalentHistory()].preparations.insert(.ignorePhysicalBlock)
        }
        return events
    }
}

// MARK: - Cleansing

package extension CombatTriggerEngine {
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
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        if triggers.perfectPurity {
            context.roster.mutateRuntime(for: target) { $0.talents.turn.negativeStatusImmune = true }
        }
        if removed.contains(.burn), triggers.heatRecovery {
            context.roster.mutateRuntime(for: source) { $0.talents.pending.nextBurnDamageBonus = 2 }
        }
        if removed.contains(.poison), triggers.antitoxinCoating {
            context.roster.mutateRuntime(for: target) {
                $0.talents.turn.cleansedKeywordProtection.insert(.poison)
            }
        }
        if !removed.isEmpty {
            if triggers.freshBatch {
                let healTarget = BattleTargetResolver.lowestHealthAlly(for: source, in: context)
                events.append(contentsOf: heroTalentHeal(
                    to: healTarget, source: source, amount: 2, name: "Fresh Batch", in: &context,
                ))
            }
            if triggers.clearMind {
                context.roster.mutateRuntime(for: source) {
                    $0.talents.pending.nextManaEmpowerDiscount = max($0.talents.pending.nextManaEmpowerDiscount, 1)
                }
            }
            if !context.hasTalentDebuff(on: target), triggers.cleanBreak,
               let owner = context.roster.participant(for: source) {
                events.append(contentsOf: drawCards(
                    1, for: owner, actor: source, abilityName: "Clean Break", in: &context,
                ))
            }
        }
        return events
    }
}

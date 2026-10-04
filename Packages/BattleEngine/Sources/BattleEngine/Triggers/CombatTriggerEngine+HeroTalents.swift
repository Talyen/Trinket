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
        if critical {
            events.append(contentsOf: afterTypedCriticalAttackHit(keyword: keyword, actor: actor, in: &context))
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
            actor: actor, sourceID: sourceID, critical: critical,
            triggers: triggers, in: &context,
        ))
        return events
    }

    static func afterTypedCriticalAttackHit(
        keyword: Keyword?,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction,
              let source = context.roster.runtime(for: actor), source.isAlive,
              actor.role != .enemy else { return [] }
        let sourceID = actor.id
        let triggers = context.modifiers(for: sourceID).triggers
        var events: [ActionEvent] = []
        if keyword == .freeze, triggers.freezeCriticalRestoreMana > 0 {
            events.append(contentsOf: heroTalentMana(to: actor, source: actor, name: "Frost Circuit", in: &context))
        }
        if keyword == .poison, triggers.poisonCritPreparesBleedCrit {
            context.roster.mutateRuntime(for: actor) { $0.talents.pending.guaranteedBleedCritical = true }
        }
        if keyword == .stun, triggers.stunCriticalStealGold > 0,
           context.claimTalentAbility("Cutpurse Cut", actorID: sourceID) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.stunCriticalStealGold,
                to: actor,
                abilityName: "Cutpurse Cut",
                isTheft: true,
            ))
        }
        if keyword == .burn, triggers.burnAttackCritDrawCard,
           context.claimTalentAbility("Ashen Arsenal", actorID: sourceID),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(
                1, for: owner, actor: actor, abilityName: "Ashen Arsenal", in: &context,
            ))
        }
        return events
    }

    static func removeBlockAfterPhysicalCriticalHit(by sourceID: String?, in context: inout BattleState) {
        guard let sourceID, let source = context.roster.combatant(for: sourceID), source.isAlive,
              source.role != .enemy, context.modifiers(for: sourceID).triggers.physicalCritRemoveEnemyBlock else { return }
        DefensePoolEngine.set(0, on: context.enemy, in: &context)
    }

    private static func afterPhysicalCardHit(
        actor: Combatant,
        sourceID: String,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if critical {
            removeBlockAfterPhysicalCriticalHit(by: sourceID, in: &context)
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
        if fullyBlocked, triggers.blockedAttackFirstRandomCard,
           !context.isBattleOver,
           context.claimHeroTalent("Consolation Prize", actorID: actor.id, battle: true),
           let owner = context.roster.participant(for: actor), owner.isPartyMember,
           let ability = AbilityCatalog.all.randomElement(using: &context.rng) {
            _ = BattleCardCombatEngine.deal(ability, owner: owner, context: &context)
            events.append(context.nextEvent(
                kind: .effect, effectKind: .cardsDrawn, actorName: actor.name,
                abilityName: "Consolation Prize", target: actor, amount: 1, keyword: .physical,
            ))
        }
        if fullyBlocked, triggers.blockedAttackNextPhysicalDouble {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.doubleNextPhysicalAttack = PreparedTalentBonus(value: true, cardSerial: preparedCardSerial)
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
                let prepared = $0.talents.pending.nextAttackCriticalBonus
                $0.talents.pending.nextAttackCriticalBonus = PreparedTalentBonus(
                    value: max(prepared?.value ?? 0, triggers.dodgeNextAttackCritBonus),
                    cardSerial: prepared?.cardSerial, actionID: prepared?.actionID,
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

    // MARK: - Cleansing

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
            let serial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: source) {
                $0.talents.pending.nextBurnDamageBonus = PreparedTalentBonus(
                    value: 2, cardSerial: serial, actionID: actionID,
                )
            }
        }
        if removed.contains(.poison), triggers.antitoxinCoating {
            context.roster.mutateRuntime(for: target) {
                $0.talents.turn.cleansedKeywordProtection.insert(.poison)
            }
        }
        if !removed.isEmpty {
            if triggers.freshBatch {
                let healTarget = BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context)
                events.append(contentsOf: heroTalentHeal(
                    to: healTarget, source: source, amount: 2, name: "Fresh Batch", in: &context,
                ))
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

    // MARK: - Turn lifecycle

    static func startHeroTalentTurn(in context: inout BattleState) -> [ActionEvent] {
        for owner in [BattleParticipant.hero, .companion] {
            let actor = context.roster[owner].combatant
            var history = context.heroTalents.history[actor.id, default: HeroTalentHistory()]
            history.spentMana = false
            context.heroTalents.history[actor.id] = history
        }
        return []
    }

    static func afterHeroTalentPoisonExpiry(sourceID: String?, target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard context.allowsHeroTalentReaction, let sourceID,
              let source = context.roster.combatant(for: sourceID), source.isAlive else { return [] }
        let triggers = context.modifiers(for: sourceID).triggers
        if triggers.unstableCulture, target.role == .enemy {
            context.heroTalents.history[sourceID, default: HeroTalentHistory()].preparations.insert(.doublePoison)
        }
        var events: [ActionEvent] = []
        if triggers.poisonExpiryManaRestore > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.poisonExpiryManaRestore,
                to: source.combatant,
                abilityName: "Spent Reagents",
            ))
        }
        if triggers.returningBloomHeal > 0 {
            let healTarget = BattleActionContext(actor: source.combatant, in: context).target(.lowestHealthAlly, in: context)
            events.append(contentsOf: heroTalentHeal(
                to: healTarget,
                source: source.combatant,
                amount: triggers.returningBloomHeal,
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
        if empowered, triggers.manaEmpowerPurgeCount > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: applyPurge(
                to: context.roster.enemy.combatant,
                source: actor,
                abilityName: triggerAbilityName("manaEmpowerPurgeCount", for: actor, fallback: "Hexing Rune", in: context),
                count: triggers.manaEmpowerPurgeCount,
                purgeAll: false,
                in: &context,
            ))
        }
        if empowered, triggers.barkweaveOnEmpowerBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.barkweaveOnEmpowerBlock,
                to: actor,
                source: actor,
                abilityName: "Barkweave",
            ))
        }
        if empowered, triggers.sharedCurrentCompanionNextAttackBonus > 0,
           context.roster.companion.isAlive {
            context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                $0.talents.pending.cardDamageBonus = max(
                    $0.talents.pending.cardDamageBonus,
                    triggers.sharedCurrentCompanionNextAttackBonus,
                )
            }
        }
        guard amount > 0 else { return events }
        context.heroTalents.history[actor.id, default: HeroTalentHistory()].spentMana = true
        let hero = context.roster.hero.combatant
        if context.roster.hero.isAlive, context.roster.companion.isAlive,
           context.heroTalents.history[hero.id]?.spentMana == true,
           context.heroTalents.history[context.roster.companion.id]?.spentMana == true,
           context.heroModifiers.triggers.groveAccord,
           context.claimHeroTalent("groveAccord", actorID: hero.id) {
            for target in [hero, context.roster.companion.combatant] {
                events.append(contentsOf: heroTalentThorns(to: target, source: hero, name: "Grove Accord", in: &context))
            }
        }
        return events
    }

    // MARK: - Reward emitters

    static func heroTalentThorns(
        to target: Combatant, source: Combatant, amount: Int = 1, name: String, in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let total = context.roster.activeEffects(for: target).reduce(amount) { sum, active in
                if case let .thorns(amount) = active.effect {
                    return sum + amount
                }
                return sum
            }
            ActiveEffectMutation.removeMatching(from: target, in: &context) { $0.kind == .thorns }
            context.appendEffect(.thorns(total), to: target, sourceID: source.id, remainingTurns: 0)
            return [context.nextEvent(
                kind: .effect,
                effectKind: .thornsApplied,
                actorName: source.name,
                abilityName: name,
                target: target,
                amount: amount,
                keyword: .thorns,
            )]
        }
    }

    static func heroTalentHeal(
        to target: Combatant,
        source: Combatant,
        amount: Int = 1,
        name: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let outcome = HealingEngine.resolveHeal(
                HealRequest(amount: amount, target: target, sourceActorID: source.id, logAs: .silent), in: &context,
            )
            guard outcome.healthRestored > 0 else { return outcome.events }
            return outcome.events + [context.nextEvent(
                kind: .effect, effectKind: .instantHeal, actorName: source.name,
                abilityName: name, target: target, amount: outcome.healthRestored, keyword: .health,
            )]
        }
    }

    static func heroTalentMana(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            context.restoreManaEmitting(1, to: target, abilityName: name)
        }
    }

    static func heroTalentDamage(
        _ keyword: Keyword,
        amount: Int = 1,
        source: Combatant,
        name: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.enemy.isAlive, context.roster.health(for: source) > 0 else { return [] }
        return withHeroReaction(in: &context) { context in
            let target = context.roster.enemy.combatant
            let outcome = context.resolveDamage(DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
                options: .reaction(),
            ))
            var events = outcome.events
            if outcome.healthLost > 0 {
                events.append(context.nextEvent(
                    kind: .abilityDamage,
                    actorName: source.name,
                    abilityName: name,
                    target: target,
                    amount: outcome.healthLost,
                    keyword: keyword,
                    origin: .automatic,
                ))
            }
            events.append(contentsOf: DoTApplicator.applyDoT(
                keyword: keyword,
                potency: keyword == .bleed ? amount : outcome.healthLost,
                to: target,
                sourceActorID: source.id,
                application: .afterHit,
                in: &context,
            ) ?? [])
            return events
        }
    }
}

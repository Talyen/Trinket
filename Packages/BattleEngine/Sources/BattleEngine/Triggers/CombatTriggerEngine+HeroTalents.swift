import TrinketContent
import TrinketCore

// MARK: - Card play

package extension CombatTriggerEngine {
    static func finishHeroCard(actor _: Combatant, in context: inout BattleState) {
        _ = context.resolution.finishCardTalents()
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
    ) async {
        guard let sourceID, context.hasHeroCard(for: sourceID),
              let runtime = context.roster.combatant(for: sourceID), runtime.isAlive else { return }
        let actor = runtime.combatant
        let triggers = context.modifiers(for: sourceID).triggers

        if critical {
            context.mutateHeroCard { $0.didCriticalHit = true }
        }
        if keyword == .freeze {
            drawOnFreezeCardHit(healthLost: healthLost, actor: actor, in: &context)
        }
        if critical {
            await afterTypedCriticalAttackHit(keyword: keyword, actor: actor, in: &context)
        }
        prepareTemperCycle(keyword: keyword, actor: actor, triggers: triggers, in: &context)
        await afterOtherCardHits(
            keyword: keyword, actor: actor,
            critical: critical, healthLost: healthLost, fullyBlocked: fullyBlocked,
            triggers: triggers, in: &context,
        )
        guard keyword == .physical else { return }
        if critical {
            removeBlockAfterPhysicalCriticalHit(by: sourceID, in: &context)
        }
        await prismaticEdgeDamage(actor: actor, triggers: triggers, in: &context)
    }

    static func afterNonCardAttackHit(
        keyword: Keyword?,
        sourceID: String?,
        fullyBlocked: Bool,
        options: DamageOperation,
        in context: inout BattleState,
    ) async {
        guard let sourceID, let source = context.roster.combatant(for: sourceID),
              source.isAlive, source.role != .enemy else { return }
        let actor = source.combatant
        let triggers = context.modifiers(for: sourceID).triggers
        prepareTemperCycle(keyword: keyword, actor: actor, triggers: triggers, in: &context)
        let allowsBonusDamage = !options.isRetaliation || options.isCounterattack
        if allowsBonusDamage {
            await bloodfireDamage(keyword: keyword, actor: actor, triggers: triggers, in: &context)
        }
        afterBlockedAttack(actor: actor, fullyBlocked: fullyBlocked, triggers: triggers, in: &context)
        if allowsBonusDamage, keyword == .physical {
            await prismaticEdgeDamage(actor: actor, triggers: triggers, in: &context)
        }
    }

    private static func prepareTemperCycle(
        keyword: Keyword?,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard keyword == .burn, triggers.burnPreparesBleedDamageBonus > 0 else { return }
        context.roster.mutateRuntime(for: actor) {
            $0.talents.pending.nextBleedDamageBonus = max(
                $0.talents.pending.nextBleedDamageBonus,
                triggers.burnPreparesBleedDamageBonus,
            )
        }
    }

    static func afterTypedCriticalAttackHit(
        keyword: Keyword?,
        actor: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.allowsHeroTalentReaction,
              let source = context.roster.runtime(for: actor), source.isAlive,
              actor.role != .enemy else { return }
        let sourceID = actor.id
        let triggers = context.modifiers(for: sourceID).triggers

        if keyword == .holy, triggers.holyCriticalPreventsBlock, context.roster.enemy.isAlive {
            context.roster.mutateRuntime(for: context.enemy) { $0.talents.turn.blockGainPrevented = true }
        }
        if keyword == .freeze, triggers.freezeCriticalRestoreMana > 0 {
            await heroTalentMana(to: actor, source: actor, name: "Frost Circuit", in: &context)
        }
        if keyword == .poison, triggers.poisonCritPreparesBleedCrit {
            context.roster.mutateRuntime(for: actor) { $0.talents.pending.guaranteedBleedCritical = true }
        }
        if keyword == .stun, triggers.stunCriticalStealGold > 0,
           context.claimTalentAbility(.cutpurseCut, actorID: sourceID) {
            _ = await context.grantGold(
                triggers.stunCriticalStealGold,
                to: actor,
                abilityName: "Cutpurse Cut",
                isTheft: true,
            )
        }
        if keyword == .burn, triggers.burnAttackCritDrawCard,
           context.claimTalentAbility(.ashenArsenal, actorID: sourceID),
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: "Ashen Arsenal", in: &context)
        }
    }

    static func removeBlockAfterPhysicalCriticalHit(by sourceID: String?, in context: inout BattleState) {
        guard let sourceID, let source = context.roster.combatant(for: sourceID), source.isAlive,
              source.role != .enemy, context.modifiers(for: sourceID).triggers.physicalCritRemoveEnemyBlock else { return }
        DefensePoolEngine.strip(
            Int.max, from: context.enemy, source: .init(source),
            abilityName: context.modifiers(for: sourceID).triggerAbilityName(.physicalCritRemoveEnemyBlock, fallback: "Pulverize"),
            in: &context,
        )
    }

    private static func prismaticEdgeDamage(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard triggers.physicalElementChancePercent > 0, triggers.physicalElementDamage > 0,
              context.claimTalentAbility(.prismaticEdge, actorID: actor.id),
              BattleChance.succeeds(probability: triggers.physicalElementChancePercent, using: &context.rng)
        else { return }
        let keyword: Keyword = Bool.random(using: &context.rng) ? .burn : .freeze
        await heroTalentDamage(keyword, amount: triggers.physicalElementDamage, source: actor, name: "Prismatic Edge", in: &context)
    }

    private static func afterOtherCardHits(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        fullyBlocked: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        await bloodfireDamage(keyword: keyword, actor: actor, triggers: triggers, in: &context)
        afterBlockedAttack(actor: actor, fullyBlocked: fullyBlocked, triggers: triggers, in: &context)
        await afterCompanionAttackHit(
            keyword: keyword, actor: actor, critical: critical,
            healthLost: healthLost, triggers: triggers, in: &context,
        )
    }

    private static func bloodfireDamage(
        keyword: Keyword?,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard keyword == .burn, triggers.burnAttackBleedDamage > 0,
              context.claimTalentAbility(.bloodfire, actorID: actor.id),
              BattleChance.succeeds(probability: triggers.burnAttackBleedChancePercent, using: &context.rng)
        else { return }
        await heroTalentDamage(.bleed, amount: triggers.burnAttackBleedDamage, source: actor, name: "Bloodfire", in: &context)
    }

    private static func afterBlockedAttack(
        actor: Combatant,
        fullyBlocked: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        if fullyBlocked, triggers.blockedAttackFirstRandomCard,
           !context.isBattleOver,
           context.claimHeroTalent(.consolationPrize, actorID: actor.id, battle: true),
           let owner = context.roster.participant(for: actor), owner.isPartyMember,
           let ability = AbilityCatalog.all.randomElement(using: &context.rng) {
            _ = BattleCardCombatEngine.deal(ability, owner: owner, context: &context)
            context.nextEvent(
                kind: .effect(.cardsDrawn), source: .init(actor),
                abilityName: "Consolation Prize", target: actor, amount: 1, keyword: .physical,
            )
        }
        if fullyBlocked, triggers.blockedAttackNextPhysicalDouble {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.doubleNextPhysicalAttack = PreparedTalentBonus(
                    value: true, cardSerial: preparedCardSerial, actionID: actionID,
                )
            }
        }
    }

    static func afterHeroTalentHealthLoss(
        target: Combatant,
        sourceID: String?,
        keyword: Keyword?,
        in context: inout BattleState,
    ) async {
        guard context.allowsHeroTalentReaction else { return }

        if target.role == .hero,
           context.modifiers(for: target.id).triggers.healthLossManaGain > 0 {
            await heroTalentMana(to: target, source: target, name: "Forbidden Lore", in: &context)
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
            await heroTalentThorns(to: context.roster.companion.combatant, source: source.combatant, name: "Barbed Spores", in: &context)
        }
    }

    static func afterHeroTalentDodge(by actor: Combatant, in context: inout BattleState) {
        guard context.allowsHeroTalentReaction, context.roster.health(for: actor) > 0 else { return }
        context.roster.mutateRuntime(for: actor) { $0.talents.history.dodgeGrowth = 0 }
        let triggers = context.modifiers(for: actor.id).triggers

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
           context.roster.isBelowHalfHealth(for: actor),
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: "Missed Opportunity", in: &context)
        }
        if triggers.passingLuck, context.roster.companion.isAlive {
            context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                $0.talents.pending.guaranteedCriticalAfterDodge = true
            }
        }
        if triggers.blindSpot {
            context.roster.mutateRuntime(for: actor) { $0.talents.history.preparations.insert(.ignorePhysicalBlock) }
        }
    }

    // MARK: - Cleansing

    static func afterHeroCleanse(
        source: Combatant,
        target: Combatant,
        removed: [Keyword],
        in context: inout BattleState,
    ) async {
        if source.role != .enemy, target.role != .enemy,
           context.roster.health(for: source) > 0,
           context.modifiers(for: source.id).triggers.lessonLearned {
            context.roster.mutateRuntime(for: target) { $0.talents.turn.cleansedKeywordProtection.formUnion(removed) }
        }
        guard context.allowsHeroTalentReaction, source.role != .enemy, target.role != .enemy,
              context.roster.health(for: source) > 0, context.roster.health(for: target) > 0 else { return }
        let triggers = context.modifiers(for: source.id).triggers

        if !removed.isEmpty, triggers.perfectPurity {
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
            if triggers.cleanseHolyDamage > 0 {
                await heroTalentDamage(
                    .holy, amount: triggers.cleanseHolyDamage, source: source,
                    name: triggerAbilityName(.cleanseHolyDamage, for: source, fallback: "Reproving Light", in: context),
                    in: &context,
                )
            }
            if triggers.freshBatch {
                let healTarget = BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context)
                await heroTalentHeal(to: healTarget, source: source, amount: 2, name: "Fresh Batch", in: &context)
            }
            if !context.hasTalentDebuff(on: target), triggers.cleanBreak,
               let owner = context.roster.participant(for: source) {
                drawCards(1, for: owner, actor: source, abilityName: "Clean Break", in: &context)
            }
        }
    }

    // MARK: - Turn lifecycle

    static func startHeroTalentTurn(in context: inout BattleState) {
        for owner in [BattleParticipant.hero, .companion] {
            let actor = context.roster[owner].combatant
            context.roster.mutateRuntime(for: actor) { $0.talents.history.spentMana = false }
        }
    }

    static func afterHeroTalentPoisonExpiry(sourceID: String?, target: Combatant, in context: inout BattleState) async {
        guard context.allowsHeroTalentReaction, let sourceID,
              let source = context.roster.combatant(for: sourceID), source.isAlive else { return }
        let triggers = context.modifiers(for: sourceID).triggers
        if triggers.unstableCulture, target.role == .enemy {
            context.roster.mutateRuntime(for: source.combatant) { $0.talents.history.preparations.insert(.doublePoison) }
        }

        if triggers.poisonExpiryManaRestore > 0 {
            await context.restoreManaEmitting(triggers.poisonExpiryManaRestore, to: source.combatant, abilityName: "Spent Reagents")
        }
        if triggers.returningBloomHeal > 0 {
            let healTarget = BattleActionContext(actor: source.combatant, in: context).target(.lowestHealthAlly, in: context)
            await heroTalentHeal(
                to: healTarget,
                source: source.combatant,
                amount: triggers.returningBloomHeal,
                name: "Returning Bloom",
                in: &context,
            )
        }
    }

    static func afterHeroTalentSpendMana(
        actor: Combatant,
        amount: Int,
        empowered: Bool = false,
        in context: inout BattleState,
    ) async {
        guard context.allowsHeroTalentReaction, context.roster.health(for: actor) > 0 else { return }
        let triggers = context.modifiers(for: actor.id).triggers

        if empowered, triggers.manaEmpowerPurgeCount > 0, context.roster.enemy.isAlive {
            await applyPurge(
                to: context.roster.enemy.combatant,
                source: actor,
                abilityName: triggerAbilityName(.manaEmpowerPurgeCount, for: actor, fallback: "Hexing Rune", in: context),
                count: triggers.manaEmpowerPurgeCount,
                purgeAll: false,
                in: &context,
            )
        }
        if empowered, triggers.barkweaveOnEmpowerBlock > 0 {
            context.applyBlockGain(triggers.barkweaveOnEmpowerBlock, to: actor, source: actor, abilityName: "Barkweave")
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
        guard amount > 0 else { return }
        context.roster.mutateRuntime(for: actor) { $0.talents.history.spentMana = true }
        let hero = context.roster.hero.combatant
        if context.roster.hero.isAlive, context.roster.companion.isAlive,
           context.roster.hero.talents.history.spentMana == true,
           context.roster.companion.talents.history.spentMana == true,
           context.heroModifiers.triggers.groveAccord,
           context.claimHeroTalent(.groveAccord, actorID: hero.id) {
            for target in [hero, context.roster.companion.combatant] {
                await heroTalentThorns(to: target, source: hero, name: "Grove Accord", in: &context)
            }
        }
    }

    // MARK: - Reward emitters

    static func heroTalentThorns(
        to target: Combatant, source: Combatant, amount: Int = 1, name: String, in context: inout BattleState,
    ) async {
        guard amount > 0, context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return }
        await withHeroReaction(in: &context) { context in
            let total = context.roster.activeEffects(for: target).reduce(amount) { sum, active in
                if case let .thorns(amount) = active.effect {
                    return SaturatedArithmetic.saturatingAdd(sum, amount)
                }
                return sum
            }
            ActiveEffectMutation.removeMatching(from: target, in: &context) { $0.kind == .thorns }
            context.insertEffect(.thorns(total), to: target, sourceID: source.id, remainingTurns: 0)
            context.nextEvent(
                kind: .effect(.thornsApplied),
                source: .init(source),
                abilityName: name,
                target: target,
                amount: amount,
                keyword: .thorns,
            )
        }
    }

    static func heroTalentHeal(
        to target: Combatant,
        source: Combatant,
        amount: Int = 1,
        name: String,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return }
        await withHeroReaction(in: &context) { context in
            let outcome = await HealingEngine.resolveHeal(
                HealRequest(amount: amount, target: target, sourceActorID: source.id, logAs: .silent), in: &context,
            )
            guard outcome.healthRestored > 0 else { return
            }
            context.nextEvent(
                kind: .effect(.instantHeal), source: .init(source),
                abilityName: name, target: target, amount: outcome.healthRestored, keyword: .health,
            )
        }
    }

    static func heroTalentMana(
        to target: Combatant,
        source: Combatant,
        name: String,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return }
        await withHeroReaction(in: &context) { context in
            await context.restoreManaEmitting(1, to: target, abilityName: name)
        }
    }

    static func heroTalentDamage(
        _ keyword: Keyword,
        amount: Int = 1,
        source: Combatant,
        name: String,
        in context: inout BattleState,
    ) async {
        guard context.roster.enemy.isAlive, context.roster.health(for: source) > 0 else { return }
        await withHeroReaction(in: &context) { context in
            let target = context.roster.enemy.combatant
            let outcome = await context.dealReactionDamage(amount, to: target, keyword: keyword, sourceActorID: source.id)

            if outcome.healthLost > 0 {
                context.nextEvent(
                    kind: .abilityDamage,
                    source: .init(source),
                    abilityName: name,
                    target: target,
                    amount: outcome.healthLost,
                    keyword: keyword,
                    origin: .automatic,
                )
            }
            await DoTApplicator.applyDoT(
                keyword: keyword,
                potency: keyword == .bleed ? amount : outcome.healthLost,
                to: target,
                sourceActorID: source.id,
                application: .afterHit,
                in: &context,
            )
        }
    }
}

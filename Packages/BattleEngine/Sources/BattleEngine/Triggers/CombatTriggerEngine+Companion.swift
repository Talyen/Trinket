import TrinketContent
import TrinketCore

// MARK: - Companion card hits

package extension CombatTriggerEngine {
    static func afterCompanionCardHit(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard actor.role == .companion else { return [] }
        var events: [ActionEvent] = []
        if critical, triggers.criticalGoldStealFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.criticalGoldStealFlat, to: actor,
                abilityName: "Pickpocket", isTheft: true,
            ))
        }
        if keyword == .poison,
           triggers.poisonAttackStunChancePercent > 0,
           context.claimTalentAbility("Paralysis", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.poisonAttackStunChancePercent, using: &context.rng),
           context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                ControlMeterEngine.threshold(for: enemy, in: context),
                keyword: .stun, to: enemy,
                sourceActorID: actor.id, applyFightPacing: false, in: &context,
            ))
        }
        if keyword == .burn {
            events.append(contentsOf: afterCompanionBurnHit(
                actor: actor, critical: critical, healthLost: healthLost,
                triggers: triggers, in: &context,
            ))
        }
        if keyword == .holy {
            events.append(contentsOf: afterCompanionHolyHit(
                actor: actor, critical: critical, triggers: triggers, in: &context,
            ))
        }
        if keyword == .bleed, critical {
            events.append(contentsOf: afterCompanionBleedCritical(actor: actor, triggers: triggers, in: &context))
        }
        events.append(contentsOf: afterFinalCompanionCardHit(
            keyword: keyword, actor: actor, critical: critical, triggers: triggers, in: &context,
        ))
        return events
    }

    private static func afterCompanionHolyHit(
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if critical, triggers.holyCriticalAllyIgnoreBlock, context.roster.hero.isAlive {
            let serial = context.resolution.cardTalents?.playSerial
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.talents.pending.nextAttackIgnoresBlock = true
                $0.talents.pending.nextAttackIgnorePreparedCardSerial = serial
            }
        }
        if critical, triggers.holyCriticalPurgeCount > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: applyPurge(
                to: context.roster.enemy.combatant, source: actor,
                abilityName: "Bane of Evil", count: triggers.holyCriticalPurgeCount,
                purgeAll: false, in: &context,
            ))
        }
        if triggers.holyAttackEnemyMissChance > 0, context.roster.enemy.isAlive {
            prepareEnemyNextAttackMiss(
                triggers.holyAttackEnemyMissChance, abilityName: "Blinding Light", in: &context,
            )
        }
        if triggers.holyAttackDrawChancePercent > 0,
           context.claimTalentAbility("Radiant Wisdom", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.holyAttackDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(1, for: owner, actor: actor, abilityName: "Radiant Wisdom", in: &context))
        }
        if triggers.holyAttackCleanseAllyChancePercent > 0, context.roster.hero.isAlive,
           context.hasTalentDebuff(on: context.roster.hero.combatant),
           context.claimTalentAbility("Purifying Light", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.holyAttackCleanseAllyChancePercent, using: &context.rng) {
            events.append(contentsOf: EffectRemovalOperation.resolveCleanse(
                .randomDebuff, source: actor, target: context.roster.hero.combatant,
                abilityName: "Purifying Light", in: &context,
            ).events)
        }
        return events
    }

    private static func afterCompanionBurnHit(
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if healthLost > 0, triggers.burnAttackBlockAmount > 0,
           context.claimTalentAbility("Flame Shield", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.burnAttackBlockChancePercent, using: &context.rng) {
            events.append(contentsOf: context.applyBlock(
                triggers.burnAttackBlockAmount, to: actor, source: actor, abilityName: "Flame Shield",
            ))
        }
        if healthLost > 0, triggers.burnAttackHealLowestAmount > 0,
           context.claimTalentAbility("Healing Flames", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.burnAttackHealLowestChancePercent, using: &context.rng) {
            let target = BattleConditionEvaluator.lowestHealthAlly(in: context)
            if context.roster.health(for: target) < context.roster.maxHealth(for: target) {
                events.append(contentsOf: context.healEmitting(
                    amount: triggers.burnAttackHealLowestAmount,
                    target: target, source: actor, abilityName: "Healing Flames",
                ))
            }
        }
        if critical {
            events.append(contentsOf: afterCompanionBurnCritical(actor: actor, in: &context))
        }
        return events
    }

    static func afterCompanionBurnCritical(actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        let name = triggerAbilityName("burnCriticalRestoreMana", for: actor, fallback: "Furnace Rhythm", in: context)
        guard context.allowsHeroTalentReaction, actor.role == .companion,
              context.roster.health(for: actor) > 0, triggers.burnCriticalRestoreMana > 0,
              context.claimTalentAbility(name, actorID: actor.id) else { return [] }
        return context.restoreManaEmitting(triggers.burnCriticalRestoreMana, to: actor, abilityName: name)
    }

    private static func afterCompanionBleedCritical(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.bleedCriticalPoisonDamage > 0 {
            events.append(contentsOf: heroTalentDamage(
                .poison, amount: triggers.bleedCriticalPoisonDamage,
                source: actor, name: "Cross-Contamination", in: &context,
            ))
        }
        if triggers.bleedCriticalThorns > 0 {
            events.append(contentsOf: heroTalentThorns(
                to: actor, source: actor, amount: triggers.bleedCriticalThorns,
                name: "Spiny Carapace", in: &context,
            ))
        }
        let drawName = triggerAbilityName(
            "bleedCriticalDrawChancePercent", for: actor, fallback: "Frenzied Tail", in: context,
        )
        if triggers.bleedCriticalDrawChancePercent > 0,
           context.claimTalentAbility(drawName, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.bleedCriticalDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(
                1, for: owner, actor: actor, abilityName: drawName, in: &context,
            ))
        }
        return events
    }

    // MARK: - Final-companion card hits

    static func afterFinalCompanionCardHit(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        events.append(contentsOf: finalCompanionGoldFromAttack(actor: actor, critical: critical, triggers: triggers, in: &context))
        if keyword == .physical {
            if triggers.firstPhysicalAttackBlockPerTurn > 0,
               context.claimHeroTalent("Bone Shield", actorID: actor.id) {
                events.append(contentsOf: context.applyBlock(
                    triggers.firstPhysicalAttackBlockPerTurn,
                    to: actor, source: actor, abilityName: "Bone Shield",
                ))
            }
            if critical, triggers.physicalCriticalBleedDamage > 0, context.roster.enemy.isAlive {
                events.append(contentsOf: heroTalentDamage(
                    .bleed, amount: triggers.physicalCriticalBleedDamage,
                    source: actor, name: "Cleaving Bones", in: &context,
                ))
            }
        }
        if keyword == .holy {
            if triggers.firstHolyAttackBlockPerTurn > 0,
               context.claimHeroTalent("Radiant Barrier", actorID: actor.id) {
                events.append(contentsOf: context.applyBlock(
                    triggers.firstHolyAttackBlockPerTurn,
                    to: actor, source: actor, abilityName: "Radiant Barrier",
                ))
            }
            if critical, triggers.holyCriticalStunDamage > 0, context.roster.enemy.isAlive {
                events.append(contentsOf: heroTalentDamage(
                    .stun, amount: triggers.holyCriticalStunDamage,
                    source: actor, name: "Stun Flare", in: &context,
                ))
            }
            if critical, triggers.holyCritEnemyNextAttackMissChance > 0, context.roster.enemy.isAlive {
                prepareEnemyNextAttackMiss(
                    triggers.holyCritEnemyNextAttackMissChance, abilityName: "Dazzling Guard", in: &context,
                )
            }
        }
        if keyword == .freeze, critical, triggers.freezeCritEnemyNextAttackMissChance > 0,
           context.roster.enemy.isAlive {
            prepareEnemyNextAttackMiss(
                triggers.freezeCritEnemyNextAttackMissChance, abilityName: "Blinding Frost", in: &context,
            )
        }
        return events
    }

    private static func finalCompanionGoldFromAttack(
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.attackGoldStealAmount > 0,
           context.claimTalentAbility("Snatch", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.attackGoldStealChancePercent, using: &context.rng) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.attackGoldStealAmount, to: actor, abilityName: "Snatch", isTheft: true,
            ))
        }
        if critical, triggers.criticalGoldStealAmount > 0,
           context.claimTalentAbility("Lucky Strike", actorID: actor.id),
           BattleChance.succeeds(probability: triggers.criticalGoldStealChancePercent, using: &context.rng) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.criticalGoldStealAmount, to: actor, abilityName: "Lucky Strike", isTheft: true,
            ))
        }
        return events
    }

    static func prepareEnemyNextAttackMiss(
        _ chance: Double,
        abilityName: String,
        in context: inout BattleState,
    ) {
        let enemy = context.roster.enemy.combatant
        context.roster.mutateRuntime(for: enemy) {
            if chance >= $0.talents.pending.nextAttackMissChance {
                $0.talents.pending.nextAttackMissChance = chance
                $0.talents.pending.nextAttackMissAbilityName = abilityName
            }
        }
    }

    // MARK: - Companion control

    static func drawOnFreezeCardHit(healthLost: Int, actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let chance = context.modifiers(for: actor.id).triggers.freezeAttackDrawChancePercent
        guard healthLost > 0, chance > 0,
              BattleChance.succeeds(probability: chance, using: &context.rng),
              let owner = context.roster.participant(for: actor)
        else { return [] }
        return drawCards(1, for: owner, actor: actor, abilityName: "Rimewind", in: &context)
    }

    static func afterEnemyFrozen(sourceActorID: String?, in context: inout BattleState) -> [ActionEvent] {
        guard let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.isAlive
        else { return [] }
        let actor = source.combatant
        let triggers = context.modifiers(for: sourceActorID).triggers
        var events: [ActionEvent] = []
        if triggers.onFreezeEnemyRestoreMana > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.onFreezeEnemyRestoreMana, to: actor, abilityName: "Frost Siphon",
            ))
        }
        if triggers.onFreezeEnemyGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.onFreezeEnemyGainBlock,
                to: actor, source: actor, abilityName: "Frost Guard",
            ))
        }
        if triggers.onFreezeBurningEnemyBurnDamage > 0,
           context.roster.hasAffliction(.burn, on: context.roster.enemy.combatant) {
            events.append(contentsOf: heroTalentDamage(
                .burn, amount: triggers.onFreezeBurningEnemyBurnDamage,
                source: actor, name: "Steam Explosion", in: &context,
            ))
        }
        if triggers.onFreezeEnemyDrawCard,
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(
                1, for: owner, actor: actor, abilityName: "Winter’s Dominion", in: &context,
            ))
        }
        return events
    }

    // MARK: - Companion dodge (including final-companion follow-ups)

    static func afterCompanionDodge(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.dodgeNextManaEmpowerFree || triggers.dodgeNextFreezeIgnoreBlock
            || triggers.dodgeNextAttackIgnoreBlock || triggers.firstDodgeDoubleNextAttack {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            let firstDodge = triggers.firstDodgeDoubleNextAttack
                && context.claimHeroTalent("Surprise Strike", actorID: actor.id, battle: true)
            context.roster.mutateRuntime(for: actor) {
                if firstDodge {
                    $0.talents.pending.doubleDamageAfterDodge = true
                }
                if triggers.dodgeNextManaEmpowerFree {
                    $0.talents.pending.nextManaEmpowerDiscount = max($0.talents.pending.nextManaEmpowerDiscount, 3)
                }
                if triggers.dodgeNextFreezeIgnoreBlock {
                    $0.talents.pending.nextFreezeIgnoresBlock = true
                    $0.talents.pending.nextFreezeIgnorePreparedCardSerial = preparedCardSerial
                }
                if triggers.dodgeNextAttackIgnoreBlock {
                    $0.talents.pending.nextAttackIgnoresBlock = true
                    $0.talents.pending.nextAttackIgnorePreparedCardSerial = preparedCardSerial
                }
            }
        }
        var events: [ActionEvent] = []
        if triggers.dodgeDealBleedFlat > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: applyDoT(
                keyword: .bleed,
                potency: triggers.dodgeDealBleedFlat,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                in: &context,
            ))
        }
        if triggers.firstDodgeDrawForAlly, context.roster.hero.isAlive,
           context.claimHeroTalent("Tailwind", actorID: actor.id, battle: true) {
            let ally = context.roster.hero.combatant
            events.append(contentsOf: drawCards(1, for: .hero, actor: ally, abilityName: "Tailwind", in: &context))
        }
        if triggers.dodgeDrawChancePercent > 0,
           BattleChance.succeeds(probability: triggers.dodgeDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(1, for: owner, actor: actor, abilityName: "Regroup", in: &context))
        }
        if actor.role == .companion {
            prepareFinalDodgeBonuses(by: actor, triggers: triggers, in: &context)
            events.append(contentsOf: finalDodgeResources(by: actor, triggers: triggers, in: &context))
            events.append(contentsOf: finalDodgeDamage(by: actor, triggers: triggers, in: &context))
        }
        return events
    }

    // MARK: - Final-companion dodge

    private static func prepareFinalDodgeBonuses(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let serial = context.resolution.cardTalents?.playSerial
        let firstFeint = triggers.firstDodgeNextAttackBonusPerTurn > 0
            && context.claimHeroTalent("Feint Strike", actorID: actor.id)
        context.roster.mutateRuntime(for: actor) {
            if triggers.dodgeNextBleedAttackMultiplier > 1 {
                $0.talents.pending.nextBleedAttackMultiplier = max(
                    $0.talents.pending.nextBleedAttackMultiplier, triggers.dodgeNextBleedAttackMultiplier,
                )
                $0.talents.pending.nextBleedMultiplierPreparedCardSerial = serial
            }
            if triggers.dodgeNextPhysicalDamageMultiplier > 1 {
                $0.talents.pending.nextPhysicalAttackMultiplier = max(
                    $0.talents.pending.nextPhysicalAttackMultiplier, triggers.dodgeNextPhysicalDamageMultiplier,
                )
                $0.talents.pending.nextPhysicalAttackPreparedCardSerial = serial
            }
            if triggers.dodgeNextCriticalDamageMultiplier > 1 {
                $0.talents.pending.nextCriticalHitMultiplier = max(
                    $0.talents.pending.nextCriticalHitMultiplier, triggers.dodgeNextCriticalDamageMultiplier,
                )
                $0.talents.pending.nextCriticalHitPreparedCardSerial = serial
            }
            if firstFeint {
                $0.talents.pending.feintStrikeDamageBonus = max(
                    $0.talents.pending.feintStrikeDamageBonus,
                    triggers.firstDodgeNextAttackBonusPerTurn,
                )
            }
        }
        if context.roster.hero.isAlive {
            let ally = context.roster.hero.combatant
            if triggers.dodgeAllyNextAttackCriticalBonus > 0 {
                context.roster.mutateRuntime(for: ally) {
                    $0.talents.pending.nextAttackCriticalBonus = max(
                        $0.talents.pending.nextAttackCriticalBonus,
                        triggers.dodgeAllyNextAttackCriticalBonus,
                    )
                    $0.talents.pending.nextAttackCriticalPreparedCardSerial = serial
                }
            }
            if triggers.firstDodgeAllyEvadeNextHit,
               context.claimHeroTalent("Evasive Pack", actorID: actor.id, battle: true) {
                context.prependEffect(.evadeNextHit, to: ally, remainingTurns: 0)
            }
        }
    }

    private static func finalDodgeResources(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.dodgeGoldAmount > 0,
           BattleChance.succeeds(probability: triggers.dodgeGoldChancePercent, using: &context.rng) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.dodgeGoldAmount, to: actor, abilityName: "Palmed Coin",
            ))
        }
        if triggers.belowHalfFirstDodgeHealPerTurn > 0,
           context.roster.enemy.isAlive,
           context.roster.health(for: actor) * 2 < context.roster.maxHealth(for: actor),
           context.claimHeroTalent("Stolen Breath", actorID: actor.id) {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.belowHalfFirstDodgeHealPerTurn,
                target: actor, source: actor, abilityName: "Stolen Breath",
            ))
        }
        return events
    }

    private static func finalDodgeDamage(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.enemy.isAlive else { return [] }
        var events: [ActionEvent] = []
        for (keyword, chance, amount, name) in [
            (Keyword.physical, triggers.dodgePhysicalChancePercent, triggers.dodgePhysicalDamage, "Snapping Jaws"),
            (.poison, triggers.dodgePoisonChancePercent, triggers.dodgePoisonDamage, "Poisonous Dash"),
            (.stun, triggers.dodgeStunChancePercent, triggers.dodgeStunDamage, "Dazzling Tail"),
        ] where amount > 0 && context.roster.enemy.isAlive {
            if BattleChance.succeeds(probability: chance, using: &context.rng) {
                events.append(contentsOf: heroTalentDamage(
                    keyword, amount: amount, source: actor, name: name, in: &context,
                ))
            }
        }
        return events
    }

    // MARK: - Companion resources

    static func afterFinalCompanionGoldGain(
        granted: Int,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: actor.id).triggers.belowHalfFirstGoldGainHealPerTurn
        guard granted > 0, amount > 0, context.roster.enemy.isAlive,
              context.roster.health(for: actor) * 2 < context.roster.maxHealth(for: actor),
              context.claimHeroTalent("Golden Recovery", actorID: actor.id) else { return [] }
        return context.healEmitting(amount: amount, target: actor, source: actor, abilityName: "Golden Recovery")
    }

    static func afterCompanionGoldTheft(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.goldTheftNextBlockMultiplier > 1 {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextBlockGainMultiplier = max(
                    $0.talents.pending.nextBlockGainMultiplier,
                    triggers.goldTheftNextBlockMultiplier,
                )
                $0.talents.pending.nextBlockGainPreparedCardSerial = preparedCardSerial
            }
        }
        if triggers.goldTheftNextAttackCriticalBonus > 0 {
            let serial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextAttackCriticalBonus = max(
                    $0.talents.pending.nextAttackCriticalBonus,
                    triggers.goldTheftNextAttackCriticalBonus,
                )
                $0.talents.pending.nextAttackCriticalPreparedCardSerial = serial
                $0.talents.pending.nextAttackCriticalPreparedActionID = actionID
            }
        }
        var events: [ActionEvent] = []
        if triggers.goldTheftStealEnemyBlockChancePercent > 0, context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: enemy))
            if block > 0,
               context.claimTalentAbility("Light-Fingered", actorID: actor.id),
               BattleChance.succeeds(
                   probability: triggers.goldTheftStealEnemyBlockChancePercent, using: &context.rng,
               ) {
                events.append(contentsOf: DefensePoolEngine.steal(
                    block, from: enemy, to: actor, abilityName: "Light-Fingered", in: &context,
                ))
            }
        }
        if triggers.goldTheftHealAllyFlat > 0, context.roster.hero.isAlive,
           context.roster.hero.currentHealth < context.roster.hero.maxHealth {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.goldTheftHealAllyFlat,
                target: context.roster.hero.combatant,
                source: actor,
                abilityName: "Shared Spoils",
            ))
        }
        if triggers.firstGoldTheftDrawBattle,
           context.claimHeroTalent("Fetch!", actorID: actor.id, battle: true),
           let owner = context.roster.participant(for: actor) {
            events.append(contentsOf: drawCards(1, for: owner, actor: actor, abilityName: "Fetch!", in: &context))
        }
        return events
    }

    // MARK: - Companion mana

    static func afterFinalCompanionManaSpend(
        actor: Combatant,
        amountSpent: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amountSpent > 0 else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.selfManaSpendNextAttackBonus > 0 {
            let serial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextManaSpendAttackBonus = max(
                    $0.talents.pending.nextManaSpendAttackBonus,
                    triggers.selfManaSpendNextAttackBonus,
                )
                $0.talents.pending.nextManaSpendAttackPreparedCardSerial = serial
                $0.talents.pending.nextManaSpendAttackPreparedActionID = actionID
            }
        }
        guard triggers.firstManaSpendRefundPerTurn > 0,
              context.claimHeroTalent("Aetherial Surge", actorID: actor.id) else { return [] }
        return context.restoreManaEmitting(
            triggers.firstManaSpendRefundPerTurn,
            to: actor,
            abilityName: "Aetherial Surge",
        )
    }

    static func drawOnFinalCompanionManaRestoration(
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let chance = context.modifiers(for: actor.id).triggers.manaRestorationDrawChancePercent
        guard chance > 0, context.claimTalentAbility("Prismatic Spark", actorID: actor.id),
              BattleChance.succeeds(probability: chance, using: &context.rng),
              let owner = context.roster.participant(for: actor)
        else { return [] }
        return drawCards(1, for: owner, actor: actor, abilityName: "Prismatic Spark", in: &context)
    }

    // MARK: - Companion thresholds

    static func preparePantherRedline(afterHealthLoss target: Combatant, in context: inout BattleState) {
        guard context.modifiers(for: target.id).triggers.belowHalfHealthNextBleedDouble,
              context.roster.health(for: target) > 0,
              context.roster.health(for: target) * 2 < context.roster.maxHealth(for: target),
              context.roster.runtime(for: target)?.talents.battle.wasBelowHalfHealth == false
        else { return }
        let preparedCardSerial = context.resolution.cardTalents?.playSerial
        context.roster.mutateRuntime(for: target) {
            $0.talents.battle.wasBelowHalfHealth = true
            $0.talents.pending.doubleNextBleedAttack = true
            $0.talents.pending.nextBleedAttackPreparedCardSerial = preparedCardSerial
        }
    }

    static func resetPantherRedline(afterHealthRestoration target: Combatant, in context: inout BattleState) {
        guard context.modifiers(for: target.id).triggers.belowHalfHealthNextBleedDouble,
              context.roster.health(for: target) * 2 >= context.roster.maxHealth(for: target)
        else { return }
        context.roster.mutateRuntime(for: target) { $0.talents.battle.wasBelowHalfHealth = false }
    }
}

import TrinketContent
import TrinketCore

// MARK: - Companion attack hits

package extension CombatTriggerEngine {
    static func afterCompanionAttackHit(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard context.allowsHeroTalentReaction, actor.role == .companion,
              context.roster.health(for: actor) > 0 else { return }

        if critical, triggers.criticalGoldStealFlat > 0 {
            _ = await context.grantGold(
                triggers.criticalGoldStealFlat, to: actor,
                abilityName: "Pickpocket", isTheft: true,
            )
        }
        guard context.roster.health(for: actor) > 0 else { return }
        if keyword == .poison,
           triggers.poisonAttackStunChancePercent > 0,
           context.claimTalentAbility(.paralysis, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.poisonAttackStunChancePercent, using: &context.rng),
           context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            await ControlMeterEngine.applyMeterCharge(
                ControlMeterEngine.threshold(for: enemy, in: context),
                keyword: .stun, to: enemy,
                sourceActorID: actor.id, applyFightPacing: false, in: &context,
            )
        }
        if keyword == .burn {
            await afterCompanionBurnHit(actor: actor, critical: critical, healthLost: healthLost, triggers: triggers, in: &context)
        }
        if keyword == .holy {
            await afterCompanionHolyHit(actor: actor, critical: critical, triggers: triggers, in: &context)
        }
        if keyword == .bleed, critical {
            await afterCompanionBleedCritical(actor: actor, triggers: triggers, in: &context)
        }
        guard context.roster.health(for: actor) > 0 else { return }
        await afterFinalCompanionCardHit(keyword: keyword, actor: actor, critical: critical, triggers: triggers, in: &context)
    }

    private static func afterCompanionHolyHit(
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if critical, triggers.holyCriticalAllyIgnoreBlock, context.roster.hero.isAlive {
            context.prepareTalentBonus(true, \.nextAttackIgnoresBlock, for: context.roster.hero.combatant, scope: .card)
        }
        if critical, triggers.holyCriticalPurgeCount > 0, context.roster.enemy.isAlive {
            await applyPurge(
                to: context.roster.enemy.combatant, source: actor,
                abilityName: "Bane of Evil", count: triggers.holyCriticalPurgeCount,
                purgeAll: false, in: &context,
            )
        }
        guard context.roster.health(for: actor) > 0 else { return }
        if triggers.holyAttackEnemyMissChance > 0, context.roster.enemy.isAlive {
            prepareEnemyNextAttackMiss(
                triggers.holyAttackEnemyMissChance, abilityName: "Blinding Light", in: &context,
            )
        }
        if triggers.holyAttackDrawChancePercent > 0,
           context.claimTalentAbility(.radiantWisdom, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.holyAttackDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: "Radiant Wisdom", in: &context)
        }
        if triggers.holyAttackCleanseAllyChancePercent > 0, context.roster.hero.isAlive,
           context.hasTalentDebuff(on: context.roster.hero.combatant),
           context.claimTalentAbility(.purifyingLight, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.holyAttackCleanseAllyChancePercent, using: &context.rng) {
            _ = await EffectRemovalOperation.resolveCleanse(
                .randomDebuff, source: actor, target: context.roster.hero.combatant,
                abilityName: "Purifying Light", in: &context,
            )
        }
    }

    private static func afterCompanionBurnHit(
        actor: Combatant,
        critical: Bool,
        healthLost: Int,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if healthLost > 0, triggers.burnAttackBlockAmount > 0,
           context.claimTalentAbility(.flameShield, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.burnAttackBlockChancePercent, using: &context.rng) {
            context.applyBlockGain(triggers.burnAttackBlockAmount, to: actor, source: actor, abilityName: "Flame Shield")
        }
        if healthLost > 0, triggers.burnAttackHealLowestAmount > 0,
           context.claimTalentAbility(.healingFlames, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.burnAttackHealLowestChancePercent, using: &context.rng) {
            let target = BattleActionContext(actor: actor, in: context).target(.lowestHealthAlly, in: context)
            if context.roster.health(for: target) < context.roster.maxHealth(for: target) {
                await context.healEmitting(
                    amount: triggers.burnAttackHealLowestAmount,
                    target: target, source: actor, abilityName: "Healing Flames",
                )
            }
        }
        if critical {
            await afterCompanionBurnCritical(actor: actor, in: &context)
        }
    }

    static func afterCompanionBurnCritical(actor: Combatant, in context: inout BattleState) async {
        let triggers = context.modifiers(for: actor.id).triggers
        let name = triggerAbilityName(.burnCriticalRestoreMana, for: actor, fallback: "Furnace Rhythm", in: context)
        guard context.allowsHeroTalentReaction, actor.role == .companion,
              context.roster.health(for: actor) > 0, triggers.burnCriticalRestoreMana > 0,
              context.claimTalentAbility(.burnCriticalMana, actorID: actor.id) else { return }
        await context.restoreManaEmitting(triggers.burnCriticalRestoreMana, to: actor, abilityName: name)
    }

    private static func afterCompanionBleedCritical(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if triggers.bleedCriticalPoisonDamage > 0 {
            await heroTalentDamage(
                .poison, amount: triggers.bleedCriticalPoisonDamage,
                source: actor, name: "Cross-Contamination", in: &context,
            )
        }
        guard context.roster.health(for: actor) > 0 else { return }
        if triggers.bleedCriticalThorns > 0 {
            heroTalentThorns(to: actor, source: actor, amount: triggers.bleedCriticalThorns, name: "Spiny Carapace", in: &context)
        }
        let drawName = triggerAbilityName(
            .bleedCriticalDrawChancePercent, for: actor, fallback: "Frenzied Tail", in: context,
        )
        if triggers.bleedCriticalDrawChancePercent > 0,
           context.claimTalentAbility(.bleedCriticalDraw, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.bleedCriticalDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: drawName, in: &context)
        }
    }

    // MARK: - Final-companion attack hits

    static func afterFinalCompanionCardHit(
        keyword: Keyword?,
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: actor) > 0 else { return }
        await finalCompanionGoldFromAttack(actor: actor, critical: critical, triggers: triggers, in: &context)
        guard context.roster.health(for: actor) > 0 else { return }
        if keyword == .physical {
            if triggers.firstPhysicalAttackBlockPerTurn > 0,
               context.claimHeroTalent(.boneShield, actorID: actor.id) {
                context.applyBlockGain(triggers.firstPhysicalAttackBlockPerTurn, to: actor, source: actor, abilityName: "Bone Shield")
            }
            if critical, triggers.physicalCriticalBleedDamage > 0, context.roster.enemy.isAlive {
                await heroTalentDamage(
                    .bleed, amount: triggers.physicalCriticalBleedDamage,
                    source: actor, name: "Cleaving Bones", in: &context,
                )
            }
        }
        if keyword == .holy {
            if triggers.firstHolyAttackBlockPerTurn > 0,
               context.claimHeroTalent(.radiantBarrier, actorID: actor.id) {
                context.applyBlockGain(triggers.firstHolyAttackBlockPerTurn, to: actor, source: actor, abilityName: "Radiant Barrier")
            }
            if critical, triggers.holyCriticalStunDamage > 0, context.roster.enemy.isAlive {
                await heroTalentDamage(.stun, amount: triggers.holyCriticalStunDamage, source: actor, name: "Stun Flare", in: &context)
            }
            guard context.roster.health(for: actor) > 0 else { return }
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
    }

    private static func finalCompanionGoldFromAttack(
        actor: Combatant,
        critical: Bool,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if triggers.attackGoldStealAmount > 0,
           context.claimTalentAbility(.snatch, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.attackGoldStealChancePercent, using: &context.rng) {
            _ = await context.grantGold(
                triggers.attackGoldStealAmount, to: actor, abilityName: "Snatch", isTheft: true,
            )
        }
        guard context.roster.health(for: actor) > 0 else { return }
        if critical, triggers.criticalGoldStealAmount > 0,
           context.claimTalentAbility(.luckyStrike, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.criticalGoldStealChancePercent, using: &context.rng) {
            _ = await context.grantGold(
                triggers.criticalGoldStealAmount, to: actor, abilityName: "Lucky Strike", isTheft: true,
            )
        }
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

    static func drawOnFreezeCardHit(healthLost: Int, actor: Combatant, in context: inout BattleState) {
        let chance = context.modifiers(for: actor.id).triggers.freezeAttackDrawChancePercent
        guard healthLost > 0, chance > 0,
              BattleChance.succeeds(probability: chance, using: &context.rng),
              let owner = context.roster.participant(for: actor)
        else { return }
        drawCards(1, for: owner, actor: actor, abilityName: "Rimewind", in: &context)
    }

    static func afterEnemyFrozen(sourceActorID: String?, in context: inout BattleState) async {
        guard let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.isAlive
        else { return }
        let actor = source.combatant
        let triggers = context.modifiers(for: sourceActorID).triggers

        if triggers.onFreezeEnemyRestoreMana > 0 {
            await context.restoreManaEmitting(triggers.onFreezeEnemyRestoreMana, to: actor, abilityName: "Frost Siphon")
        }
        if triggers.onFreezeEnemyGainBlock > 0 {
            context.applyBlockGain(triggers.onFreezeEnemyGainBlock, to: actor, source: actor, abilityName: "Frost Guard")
        }
        if triggers.onFreezeBurningEnemyBurnDamage > 0,
           context.roster.hasAffliction(.burn, on: context.roster.enemy.combatant) {
            await heroTalentDamage(
                .burn, amount: triggers.onFreezeBurningEnemyBurnDamage,
                source: actor, name: "Steam Explosion", in: &context,
            )
        }
        await afterAffixFreeze(sourceActorID: sourceActorID, in: &context)
        if triggers.onFreezeEnemyDrawCard,
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: "Winter’s Dominion", in: &context)
        }
    }

    // MARK: - Companion dodge (including final-companion follow-ups)

    static func afterCompanionDodge(by actor: Combatant, in context: inout BattleState) async {
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.dodgeNextManaEmpowerFree || triggers.dodgeNextFreezeIgnoreBlock
            || triggers.dodgeNextAttackIgnoreBlock || triggers.firstDodgeDoubleNextAttack {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            let firstDodge = triggers.firstDodgeDoubleNextAttack
                && context.claimHeroTalent(.surpriseStrike, actorID: actor.id, battle: true)
            context.roster.mutateRuntime(for: actor) {
                if firstDodge {
                    $0.talents.pending.doubleDamageAfterDodge = true
                }
                if triggers.dodgeNextManaEmpowerFree {
                    $0.talents.pending.nextManaEmpowerDiscount = max($0.talents.pending.nextManaEmpowerDiscount, 3)
                }
                if triggers.dodgeNextFreezeIgnoreBlock {
                    $0.talents.pending.nextFreezeIgnoresBlock = PreparedTalentBonus(value: true, cardSerial: preparedCardSerial)
                }
                if triggers.dodgeNextAttackIgnoreBlock {
                    $0.talents.pending.nextAttackIgnoresBlock = PreparedTalentBonus(value: true, cardSerial: preparedCardSerial)
                }
            }
        }

        if triggers.firstDodgeDrawForAlly, context.roster.hero.isAlive,
           context.claimHeroTalent(.tailwind, actorID: actor.id, battle: true) {
            let ally = context.roster.hero.combatant
            drawCards(1, for: .hero, actor: ally, abilityName: "Tailwind", in: &context)
        }
        if triggers.dodgeDrawChancePercent > 0,
           BattleChance.succeeds(probability: triggers.dodgeDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: "Regroup", in: &context)
        }
        if actor.role == .companion {
            prepareFinalDodgeBonuses(by: actor, triggers: triggers, in: &context)
            await finalDodgeResources(by: actor, triggers: triggers, in: &context)
            await finalDodgeDamage(by: actor, triggers: triggers, in: &context)
        }
    }

    // MARK: - Final-companion dodge

    private static func prepareFinalDodgeBonuses(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let serial = context.resolution.cardTalents?.playSerial
        let firstFeint = triggers.firstDodgeNextAttackBonusPerTurn > 0
            && context.claimHeroTalent(.feintStrike, actorID: actor.id)
        if triggers.dodgeNextBleedAttackMultiplier > 1 {
            context.prepareTalentBonus(
                triggers.dodgeNextBleedAttackMultiplier, \.nextBleedAttackMultiplier, for: actor, scope: .card, merging: max,
            )
        }
        if triggers.dodgeNextPhysicalDamageMultiplier > 1 {
            context.prepareTalentBonus(
                triggers.dodgeNextPhysicalDamageMultiplier, \.nextPhysicalAttackMultiplier, for: actor, scope: .card, merging: max,
            )
        }
        if triggers.dodgeNextCriticalDamageMultiplier > 1 {
            context.prepareTalentBonus(
                triggers.dodgeNextCriticalDamageMultiplier, \.nextCriticalHitMultiplier, for: actor, scope: .card, merging: max,
            )
        }
        context.roster.mutateRuntime(for: actor) {
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
                    $0.talents.pending.nextAttackCriticalBonus = PreparedTalentBonus(
                        value: max($0.talents.pending.nextAttackCriticalBonus?.value ?? 0, triggers.dodgeAllyNextAttackCriticalBonus),
                        cardSerial: serial, actionID: $0.talents.pending.nextAttackCriticalBonus?.actionID,
                    )
                }
            }
            if triggers.firstDodgeAllyEvadeNextHit,
               context.claimHeroTalent(.evasivePack, actorID: actor.id, battle: true) {
                context.insertEffect(.evadeNextHit, to: ally, remainingTurns: 0, at: 0)
            }
        }
    }

    private static func finalDodgeResources(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if triggers.dodgeGoldAmount > 0,
           BattleChance.succeeds(probability: triggers.dodgeGoldChancePercent, using: &context.rng) {
            _ = await context.grantGold(
                triggers.dodgeGoldAmount, to: actor, abilityName: "Palmed Coin",
                isTheft: triggers.dodgeGoldIsTheft,
            )
        }
        if triggers.belowHalfFirstDodgeHealPerTurn > 0,
           context.roster.health(for: actor) > 0,
           context.roster.isBelowHalfHealth(for: actor),
           context.claimHeroTalent(.stolenBreath, actorID: actor.id) {
            await context.healEmitting(
                amount: triggers.belowHalfFirstDodgeHealPerTurn,
                target: actor, source: actor, abilityName: "Stolen Breath",
            )
        }
    }

    private static func finalDodgeDamage(
        by actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard context.roster.enemy.isAlive else { return }

        for (keyword, chance, amount, name) in [
            (Keyword.physical, triggers.dodgePhysicalChancePercent, triggers.dodgePhysicalDamage, "Snapping Jaws"),
            (.poison, triggers.dodgePoisonChancePercent, triggers.dodgePoisonDamage, "Poisonous Dash"),
            (.stun, triggers.dodgeStunChancePercent, triggers.dodgeStunDamage, "Dazzling Tail"),
        ] where amount > 0 && context.roster.enemy.isAlive {
            if BattleChance.succeeds(probability: chance, using: &context.rng) {
                await heroTalentDamage(keyword, amount: amount, source: actor, name: name, in: &context)
            }
        }
    }

    // MARK: - Companion resources

    static func afterFinalCompanionGoldGain(
        granted: Int,
        actor: Combatant,
        in context: inout BattleState,
    ) async {
        let amount = context.modifiers(for: actor.id).triggers.belowHalfFirstGoldGainHealPerTurn
        guard granted > 0, amount > 0, context.roster.health(for: actor) > 0,
              context.roster.isBelowHalfHealth(for: actor),
              context.claimHeroTalent(.belowHalfGoldGainHeal, actorID: actor.id) else { return }
        await context.healEmitting(amount: amount, target: actor, source: actor, abilityName: "Golden Recovery")
    }

    static func afterCompanionGoldTheft(by actor: Combatant, in context: inout BattleState) async {
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.goldTheftNextBlockMultiplier > 1 {
            context.prepareTalentBonus(
                triggers.goldTheftNextBlockMultiplier, \.nextBlockGainMultiplier, for: actor, scope: .card, merging: max,
            )
        }
        if triggers.goldTheftNextAttackCriticalBonus > 0 {
            context.prepareTalentBonus(triggers.goldTheftNextAttackCriticalBonus, \.nextAttackCriticalBonus, for: actor, merging: max)
        }

        if triggers.firstGoldTheftStealHalfBlockPerTurn, context.roster.enemy.isAlive,
           context.claimHeroTalent(.firstGoldTheftHalfBlock, actorID: actor.id) {
            let enemy = context.roster.enemy.combatant
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: enemy))
            DefensePoolEngine.steal(block / 2, from: enemy, to: actor, abilityName: "Light-Fingered", in: &context)
        }
        if triggers.goldTheftStealEnemyBlockChancePercent > 0, context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: enemy))
            if block > 0,
               context.claimTalentAbility(.lightFingered, actorID: actor.id),
               BattleChance.succeeds(
                   probability: triggers.goldTheftStealEnemyBlockChancePercent, using: &context.rng,
               ) {
                DefensePoolEngine.steal(block, from: enemy, to: actor, abilityName: "Light-Fingered", in: &context)
            }
        }
        if triggers.goldTheftHealAllyFlat > 0, context.roster.hero.isAlive,
           context.roster.hero.currentHealth < context.roster.hero.maxHealth {
            await context.healEmitting(
                amount: triggers.goldTheftHealAllyFlat,
                target: context.roster.hero.combatant,
                source: actor,
                abilityName: "Shared Spoils",
            )
        }
        guard context.roster.health(for: actor) > 0 else { return }
        if triggers.firstGoldTheftDrawBattle,
           context.claimHeroTalent(.fetch, actorID: actor.id, battle: true),
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: "Fetch!", in: &context)
        }
    }

    // MARK: - Companion mana

    static func afterFinalCompanionManaSpend(
        actor: Combatant,
        amountSpent: Int,
        in context: inout BattleState,
    ) async {
        guard amountSpent > 0 else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.selfManaSpendNextAttackBonus > 0 {
            context.prepareTalentBonus(triggers.selfManaSpendNextAttackBonus, \.nextManaSpendAttackBonus, for: actor, merging: max)
        }
        guard triggers.firstManaSpendRefundPerTurn > 0,
              context.claimHeroTalent(.aetherialSurge, actorID: actor.id) else { return }
        await context.restoreManaEmitting(triggers.firstManaSpendRefundPerTurn, to: actor, abilityName: "Aetherial Surge")
    }

    static func drawOnFinalCompanionManaRestoration(
        actor: Combatant,
        in context: inout BattleState,
    ) {
        let chance = context.modifiers(for: actor.id).triggers.manaRestorationDrawChancePercent
        guard chance > 0, context.claimTalentAbility(.prismaticSpark, actorID: actor.id),
              BattleChance.succeeds(probability: chance, using: &context.rng),
              let owner = context.roster.participant(for: actor)
        else { return }
        drawCards(1, for: owner, actor: actor, abilityName: "Prismatic Spark", in: &context)
    }

    // MARK: - Companion thresholds

    static func preparePantherRedline(afterHealthLoss target: Combatant, in context: inout BattleState) {
        guard context.modifiers(for: target.id).triggers.belowHalfHealthNextBleedDouble,
              context.roster.health(for: target) > 0,
              context.roster.isBelowHalfHealth(for: target),
              context.roster.runtime(for: target)?.talents.battle.wasBelowHalfHealth == false
        else { return }
        let preparedCardSerial = context.resolution.cardTalents?.playSerial
        context.roster.mutateRuntime(for: target) {
            $0.talents.battle.wasBelowHalfHealth = true
            $0.talents.pending.doubleNextBleedAttack = PreparedTalentBonus(value: true, cardSerial: preparedCardSerial)
        }
    }

    static func resetPantherRedline(afterHealthRestoration target: Combatant, in context: inout BattleState) {
        guard context.modifiers(for: target.id).triggers.belowHalfHealthNextBleedDouble,
              !context.roster.isBelowHalfHealth(for: target)
        else { return }
        context.roster.mutateRuntime(for: target) { $0.talents.battle.wasBelowHalfHealth = false }
    }
}

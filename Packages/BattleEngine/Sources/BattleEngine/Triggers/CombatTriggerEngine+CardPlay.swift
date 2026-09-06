import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterCardPlayed(
        ability: Ability? = nil,
        by actor: Combatant,
        abilityTarget: Combatant? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []

        if let ability, let abilityTarget {
            events.append(contentsOf: spellEchoIfNeeded(
                ability: ability,
                actor: actor,
                owner: owner,
                abilityTarget: abilityTarget,
                in: &context,
            ))
            events.append(contentsOf: scholarlySmiteIfNeeded(ability: ability, actor: actor, in: &context))
            events.append(contentsOf: infernoBarrageIfNeeded(ability: ability, actor: actor, triggers: triggers, in: &context))
            events.append(contentsOf: blizzardIfNeeded(
                ability: ability,
                actor: actor,
                owner: owner,
                triggers: triggers,
                in: &context,
            ))
            events.append(contentsOf: talentPrimeIfNeeded(ability: ability, actor: actor, abilityTarget: abilityTarget, in: &context))
            events.append(contentsOf: talentRepeatIfNeeded(ability: ability, actor: actor, abilityTarget: abilityTarget, in: &context))
        }

        let count = context.turnCadence.cardsPlayed[owner, default: 0] + 1
        context.turnCadence.cardsPlayed[owner] = count

        if triggers.attackDelayEnemyTurnChancePercent > 0, context.roster.enemy.isAlive,
           BattleChance.succeeds(probability: triggers.attackDelayEnemyTurnChancePercent, using: &context.rng) {
            context.additionalControlSkipsByCombatantID[context.roster.enemy.id, default: 0] += 1
        }

        guard triggers.cardsPlayedManaThreshold > 0, triggers.cardsPlayedManaFlat > 0,
              count == triggers.cardsPlayedManaThreshold
        else { return events }

        events.append(contentsOf: context.restoreManaEmitting(
            triggers.cardsPlayedManaFlat,
            to: actor,
            abilityName: triggerAbilityName(
                "cardsPlayedManaThreshold",
                for: actor,
                fallback: "Resonant Chimes",
                in: context,
            ),
        ))
        return events
    }

    private static func spellEchoIfNeeded(
        ability: Ability,
        actor: Combatant,
        owner: BattleParticipant,
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard ability.tier == .skill else { return [] }
        let skillCount = context.turnCadence.skillCardsPlayed[owner, default: 0] + 1
        context.turnCadence.skillCardsPlayed[owner] = skillCount
        guard skillCount == 1,
              context.modifiers(for: actor.id).triggers.firstSkillCardPlaysTwicePerBattle,
              !context.skillEchoOwnersThisBattle.contains(actor.id)
        else { return [] }
        context.skillEchoOwnersThisBattle.insert(actor.id)
        return BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context,
        )
    }

    private static func scholarlySmiteIfNeeded(
        ability: Ability,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard actor.role == .hero, ability.keywords.contains(.holy),
              let companionTriggers = companionReactingToHeroTriggers(in: context),
              companionTriggers.onHeroHolyAbilityCompanionHolyDamage > 0,
              context.roster.enemy.isAlive
        else { return [] }
        return context.resolveDamage(
            DamageRequest(
                amount: companionTriggers.onHeroHolyAbilityCompanionHolyDamage,
                target: context.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: context.roster.companion.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: true,
                    applyDodge: false,
                ),
            ),
        ).events
    }

    private static func infernoBarrageIfNeeded(
        ability: Ability,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard ability.tier == .ultimate,
              triggers.ultimateAppliesBurnPotency > 0,
              context.roster.enemy.isAlive
        else { return [] }
        return context.applyDecayingDoT(
            keyword: .burn,
            potency: triggers.ultimateAppliesBurnPotency,
            to: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true,
        )
    }

    private static func blizzardIfNeeded(
        ability: Ability,
        actor: Combatant,
        owner: BattleParticipant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard ability.keywords.contains(.freeze) else { return [] }
        let freezeCount = context.turnCadence.freezeCardsPlayed[owner, default: 0] + 1
        context.turnCadence.freezeCardsPlayed[owner] = freezeCount
        let threshold = triggers.freezeCardsPlayedThisTurnFreezeAll
        guard threshold > 0, freezeCount >= threshold, context.roster.enemy.isAlive else { return [] }
        let enemyThreshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
        return ControlMeterEngine.applyMeterCharge(
            enemyThreshold,
            keyword: .freeze,
            to: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            applyFightPacing: false,
            in: &context,
        )
    }

    private static func talentPrimeIfNeeded(
        ability: Ability,
        actor: Combatant,
        abilityTarget _: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.talentReactionDepth < ReactionScope.maxTalentReactionDepth,
              !context.isResolvingAutoPlayCard else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if ability.keywords.contains(.burn) {
            if triggers.furnaceRhythm {
                context.primedRepeatKeywords.insert(.physical)
            }
            if triggers.temperCycle {
                context.primedRepeatKeywords.insert(.freeze)
            }
        }
        return []
    }

    private static func talentRepeatIfNeeded(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.talentReactionDepth < ReactionScope.maxTalentReactionDepth,
              !context.isResolvingAutoPlayCard
        else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if ability.keywords.contains(.physical), triggers.furnaceRhythm,
           context.primedRepeatKeywords.remove(.physical) != nil {
            context.talentReactionDepth += 1
            defer { context.talentReactionDepth -= 1 }
            return BattleTurnEngine.performAction(ability: ability, actor: actor, abilityTarget: abilityTarget, context: &context)
        }
        if ability.keywords.contains(.freeze), triggers.temperCycle,
           context.primedRepeatKeywords.remove(.freeze) != nil {
            context.talentReactionDepth += 1
            defer { context.talentReactionDepth -= 1 }
            return BattleTurnEngine.performAction(ability: ability, actor: actor, abilityTarget: abilityTarget, context: &context)
        }
        return []
    }

    static func drawAfterSpendMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnSpendMana
        guard count > 0, context.turnCadence.spendManaDrawOwners.insert(owner).inserted else { return [] }
        return drawCards(
            count,
            for: owner,
            actor: actor,
            abilityName: triggerAbilityName("drawOnSpendMana", for: actor, fallback: "Runic Quill", in: context),
            in: &context,
        )
    }

    static func drawAfterHealthLoss(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnHealthLoss
        guard count > 0, context.turnCadence.healthLossDrawOwners.insert(owner).inserted else { return [] }
        return drawCards(
            count,
            for: owner,
            actor: actor,
            abilityName: triggerAbilityName("drawOnHealthLoss", for: actor, fallback: "Bone Charm", in: context),
            in: &context,
        )
    }

    static func afterHealthRestored(
        _ amount: Int,
        to actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let percent = context.modifiers(for: actor.id).triggers.healthRestoredPoisonPercent
        guard amount > 0, percent > 0, context.roster.enemy.isAlive, !context.isResolvingTalentReaction else {
            return []
        }
        let damage = CombatRounding.scaled(amount, multiplier: percent)
        guard damage > 0 else { return [] }
        context.isResolvingTalentReaction = true
        defer { context.isResolvingTalentReaction = false }
        return context.resolveDamage(
            DamageRequest(
                amount: damage,
                target: context.roster.enemy.combatant,
                keyword: .poison,
                sourceActorID: actor.id,
                options: .flatReaction,
            ),
        ).events
    }

    static func drawCards(
        _ count: Int,
        for owner: BattleParticipant,
        actor: Combatant,
        abilityName: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: abilityName,
            target: actor,
            amount: drawn,
            keyword: .physical,
        )]
    }
}

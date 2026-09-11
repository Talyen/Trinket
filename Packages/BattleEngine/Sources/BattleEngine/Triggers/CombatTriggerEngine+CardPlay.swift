import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    internal static func afterCardPlayed(
        _ facts: ResolvedActionFacts,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let actor = facts.action.actor
        let ability = facts.originalAbility
        let abilityTarget = facts.action.selectedTarget
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster[owner].isAlive else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        let keywords = facts.damageKeywords
        var events = CombatCheckpoint.cardCompletion(actor.id).resolve([
            { spellEchoIfNeeded(ability: ability, actor: actor, owner: owner, abilityTarget: abilityTarget, in: &$0) },
            { scholarlySmiteIfNeeded(keywords: keywords, actor: actor, in: &$0) },
            { infernoBarrageIfNeeded(ability: ability, actor: actor, triggers: triggers, in: &$0) },
            { blizzardIfNeeded(keywords: keywords, actor: actor, owner: owner, triggers: triggers, in: &$0) },
            { talentPrimeIfNeeded(keywords: keywords, actor: actor, in: &$0) },
            { talentRepeatIfNeeded(ability: ability, keywords: keywords, actor: actor, abilityTarget: abilityTarget, in: &$0) },
        ], in: &context)

        let count = context.turnCadence.cardsPlayed[owner, default: 0] + 1
        context.turnCadence.cardsPlayed[owner] = count

        guard context.roster[owner].isAlive else { return events }
        if !keywords.isEmpty, triggers.attackDelayEnemyTurnChancePercent > 0, context.roster.enemy.isAlive,
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
        guard ability.tier == .skill, !context.isEchoingSkill else { return [] }
        let skillCount = context.turnCadence.skillCardsPlayed[owner, default: 0] + 1
        context.turnCadence.skillCardsPlayed[owner] = skillCount
        var empowered = false
        context.roster.mutateRuntime(for: actor) { empowered = $0.talents.consumeActionEmpowerment() }
        guard empowered,
              context.modifiers(for: actor.id).triggers.empoweredSkillEchoes
        else { return [] }
        context.isEchoingSkill = true
        defer { context.isEchoingSkill = false }
        return BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            origin: .card,
            context: &context,
        )
    }

    private static func scholarlySmiteIfNeeded(
        keywords: Set<Keyword>,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard actor.role == .hero, keywords.contains(.holy),
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
                options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
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
            application: .attached,
        )
    }

    private static func blizzardIfNeeded(
        keywords: Set<Keyword>,
        actor: Combatant,
        owner: BattleParticipant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard keywords.contains(.freeze) else { return [] }
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
        keywords: Set<Keyword>,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.resolution.depth(.damage) < ReactionScope.maxTalentReactionDepth,
              !context.resolution.isAutomaticPlay else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if keywords.contains(.burn) {
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
        keywords: Set<Keyword>,
        actor: Combatant,
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.resolution.depth(.damage) < ReactionScope.maxTalentReactionDepth,
              !context.resolution.isAutomaticPlay
        else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if keywords.contains(.physical), triggers.furnaceRhythm,
           context.primedRepeatKeywords.remove(.physical) != nil {
            context.resolution.enter(.damage)
            defer { context.resolution.leave(.damage) }
            return BattleTurnEngine.performAction(
                ability: ability,
                actor: actor,
                abilityTarget: abilityTarget,
                origin: .cardRepeat,
                context: &context,
            )
        }
        if keywords.contains(.freeze), triggers.temperCycle,
           context.primedRepeatKeywords.remove(.freeze) != nil {
            context.resolution.enter(.damage)
            defer { context.resolution.leave(.damage) }
            return BattleTurnEngine.performAction(
                ability: ability,
                actor: actor,
                abilityTarget: abilityTarget,
                origin: .cardRepeat,
                context: &context,
            )
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
        guard amount > 0, percent > 0, context.roster.enemy.isAlive, context.resolution.depth(.talentReaction) == 0 else {
            return []
        }
        let damage = CombatRounding.scaled(amount, multiplier: percent)
        guard damage > 0 else { return [] }
        context.resolution.enter(.talentReaction)
        defer { context.resolution.leave(.talentReaction) }
        return DamagePipeline.resolveRetaliation(
            amount: damage,
            keyword: .poison,
            target: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            in: &context,
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

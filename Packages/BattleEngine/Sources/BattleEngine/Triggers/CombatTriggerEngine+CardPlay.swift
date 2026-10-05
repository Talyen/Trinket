import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    internal static func afterCardPlayed(
        _ facts: ResolvedActionFacts,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let actor = facts.action.actor
        let ability = facts.originalAbility
        let abilityTarget = facts.action.selectedTarget
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster[owner].isAlive else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        let keywords = facts.damageKeywords
        var events = await CombatCheckpoint.cardCompletion(actor.id).resolve([
            { await spellEchoIfNeeded(ability: ability, actor: actor, owner: owner, abilityTarget: abilityTarget, in: &$0) },
            { await scholarlySmiteIfNeeded(keywords: keywords, actor: actor, in: &$0) },
            { await infernoBarrageIfNeeded(ability: ability, actor: actor, triggers: triggers, in: &$0) },
            { await blizzardIfNeeded(keywords: keywords, actor: actor, owner: owner, triggers: triggers, in: &$0) },
            { await talentRepeatIfNeeded(ability: ability, keywords: keywords, actor: actor, abilityTarget: abilityTarget, in: &$0) },
            { talentPrimeIfNeeded(keywords: keywords, actor: actor, in: &$0) },
        ], in: &context)

        let count = context.turnCadence.cardsPlayed[owner, default: 0] + 1
        context.turnCadence.cardsPlayed[owner] = count

        guard context.roster[owner].isAlive else { return events }
        if !keywords.isEmpty, triggers.attackDelayEnemyTurnChancePercent > 0, context.roster.enemy.isAlive,
           BattleChance.succeeds(probability: triggers.attackDelayEnemyTurnChancePercent, using: &context.rng) {
            context.additionalControlSkipsByCombatantID[context.roster.enemy.id, default: 0] += 1
        }

        await events.append(contentsOf: cardsPlayedManaIfNeeded(count: count, actor: actor, triggers: triggers, in: &context))
        return events
    }

    private static func spellEchoIfNeeded(
        ability: Ability,
        actor: Combatant,
        owner: BattleParticipant,
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
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
        return await BattleTurnEngine.performAction(
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
    ) async -> [ActionEvent] {
        guard actor.role == .hero, keywords.contains(.holy),
              let companionTriggers = companionReactingToHeroTriggers(in: context),
              companionTriggers.onHeroHolyAbilityCompanionHolyDamage > 0,
              context.roster.enemy.isAlive
        else { return [] }
        return await context.resolveDamage(
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
    ) async -> [ActionEvent] {
        guard ability.tier == .ultimate,
              triggers.ultimateAppliesBurnPotency > 0,
              context.roster.enemy.isAlive
        else { return [] }
        return await context.applyDecayingDoT(
            keyword: .burn,
            potency: triggers.ultimateAppliesBurnPotency,
            to: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            application: .reaction,
        )
    }

    private static func blizzardIfNeeded(
        keywords: Set<Keyword>,
        actor: Combatant,
        owner: BattleParticipant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        guard keywords.contains(.freeze) else { return [] }
        let freezeCount = context.turnCadence.freezeCardsPlayed[owner, default: 0] + 1
        context.turnCadence.freezeCardsPlayed[owner] = freezeCount
        let threshold = triggers.freezeCardsPlayedThisTurnFreezeAll
        guard threshold > 0, freezeCount == threshold, context.roster.enemy.isAlive else { return [] }
        let enemyThreshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
        return await ControlMeterEngine.applyMeterCharge(
            enemyThreshold,
            keyword: .freeze,
            to: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            applyFightPacing: false,
            in: &context,
        )
    }

    /// Keywords that repeat this turn when primed: burn primes both, and the
    /// matching physical/freeze card consumes the priming. Shared by the prime
    /// and repeat steps, which differ only in which side they check.
    private static func repeatPairs(triggers: CombatTraitTriggers) -> [(keyword: Keyword, enabled: Bool)] {
        [
            (Keyword.physical, triggers.furnaceRhythm),
            (Keyword.freeze, triggers.temperCycle),
        ]
    }

    private static func talentPrimeIfNeeded(
        keywords: Set<Keyword>,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.resolution.depth(.damage) < ReactionScope.maxDepth,
              !context.resolution.isAutomaticPlay else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        if keywords.contains(.burn) {
            for (keyword, enabled) in repeatPairs(triggers: triggers) where enabled {
                context.primedRepeatKeywords.insert(keyword)
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
    ) async -> [ActionEvent] {
        guard context.resolution.depth(.damage) < ReactionScope.maxDepth,
              !context.resolution.isAutomaticPlay
        else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        for (keyword, enabled) in repeatPairs(triggers: triggers) where keywords.contains(keyword) && enabled
            && context.primedRepeatKeywords.remove(keyword) != nil {
            context.resolution.enter(.damage)
            defer { context.resolution.leave(.damage) }
            return await BattleTurnEngine.performAction(
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
        return drawClaimedCards(
            count,
            for: owner,
            actor: actor,
            abilityKey: "drawOnSpendMana",
            fallback: "Runic Quill",
            in: &context,
        )
    }

    static func drawAfterHealthLoss(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster.health(for: actor) > 0 else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnHealthLoss
        guard count > 0, context.turnCadence.healthLossDrawOwners.insert(owner).inserted else { return [] }
        return drawClaimedCards(
            count,
            for: owner,
            actor: actor,
            abilityKey: "drawOnHealthLoss",
            fallback: "Bone Charm",
            in: &context,
        )
    }

    private static func drawClaimedCards(
        _ count: Int,
        for owner: BattleParticipant,
        actor: Combatant,
        abilityKey: String,
        fallback: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        drawCards(
            count,
            for: owner,
            actor: actor,
            abilityName: triggerAbilityName(abilityKey, for: actor, fallback: fallback, in: context),
            in: &context,
        )
    }

    static func afterHealthRestored(
        _ amount: Int,
        to actor: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        resetPantherRedline(afterHealthRestoration: actor, in: &context)
        let percent = context.modifiers(for: actor.id).triggers.healthRestoredPoisonPercent
        guard amount > 0, percent > 0, context.roster.enemy.isAlive, context.resolution.depth(.talentReaction) == 0 else {
            return []
        }
        let damage = CombatRounding.scaled(amount, multiplier: percent)
        guard damage > 0 else { return [] }
        context.resolution.enter(.talentReaction)
        defer { context.resolution.leave(.talentReaction) }
        return await DamagePipeline.resolveNestedDamage(
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

// MARK: - Party cards

package extension CombatTriggerEngine {
    static func afterPartyCardPlayed(in context: inout BattleState) async -> [ActionEvent] {
        let count = context.turnCadence.cardsPlayed.values.reduce(0, +)
        var events: [ActionEvent] = []
        for (_, actor) in livingPartyMembers(in: context) {
            let triggers = context.modifiers(for: actor.id).triggers
            guard triggers.cardsPlayedHealPartyThreshold > 0,
                  count == triggers.cardsPlayedHealPartyThreshold,
                  context.resolution.claim(.heroTalent("playfulEnergy"), actorID: actor.id, cadence: .turn(context.turnCount))
            else { continue }
            for (_, target) in livingPartyMembers(in: context) {
                await events.append(contentsOf: emitHeal(
                    "cardsPlayedHealPartyThreshold", "Playful Energy",
                    amount: triggers.cardsPlayedHealPartyAmount,
                    to: target.combatant, source: actor.combatant, in: &context,
                ))
            }
        }
        return events
    }
}

import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    internal static func afterCardPlayed(
        _ facts: ResolvedActionFacts,
        in context: inout BattleState,
    ) async {
        let actor = facts.action.actor
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster[owner].isAlive else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        await cardCompletionReactions(facts, owner: owner, in: &context)

        // Completion reactions may defeat the owner; the played card still counts.
        let count = context.turnCadence.cardsPlayed[owner, default: 0] + 1
        context.turnCadence.cardsPlayed[owner] = count

        guard context.roster[owner].isAlive else { return }
        QuietAffixRules.afterAttackCard(facts, in: &context)
        if !facts.damageKeywords.isEmpty, triggers.attackDelayEnemyTurnChancePercent > 0, context.roster.enemy.isAlive,
           BattleChance.succeeds(probability: triggers.attackDelayEnemyTurnChancePercent, using: &context.rng) {
            context.roster.enemy.talents.delayAction()
        }

        await cardsPlayedManaIfNeeded(count: count, actor: actor, triggers: triggers, in: &context)
    }

    private static func cardCompletionReactions(
        _ facts: ResolvedActionFacts,
        owner: BattleParticipant,
        in context: inout BattleState,
    ) async {
        let actor = facts.action.actor
        let ability = facts.originalAbility
        let abilityTarget = facts.action.selectedTarget
        let keywords = facts.damageKeywords
        let triggers = context.modifiers(for: actor.id).triggers
        let checkpoint = CombatCheckpoint.cardCompletion(actor.id)
        guard checkpoint.allowsContinuation(in: context) else { return }
        await spellEchoIfNeeded(ability: ability, actor: actor, owner: owner, abilityTarget: abilityTarget, in: &context)
        guard checkpoint.allowsContinuation(in: context) else { return }
        if actor.role == .hero, keywords.contains(.holy),
           let companionTriggers = companionReactingToHeroTriggers(in: context),
           companionTriggers.onHeroHolyAbilityCompanionHolyDamage > 0,
           context.roster.enemy.isAlive {
            _ = await context.resolveDamage(
                DamageRequest(
                    amount: companionTriggers.onHeroHolyAbilityCompanionHolyDamage,
                    target: context.roster.enemy.combatant,
                    keyword: .holy,
                    sourceActorID: context.roster.companion.id,
                    options: DamageOperation.effect(scaling: .items, accuracy: .unavoidable),
                ),
            )
        }
        guard checkpoint.allowsContinuation(in: context) else { return }
        if ability.tier == .ultimate,
           triggers.ultimateAppliesBurnPotency > 0,
           context.roster.enemy.isAlive {
            await context.applyDecayingDoT(
                keyword: .burn,
                potency: triggers.ultimateAppliesBurnPotency,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                application: .reaction,
            )
        }
        guard checkpoint.allowsContinuation(in: context) else { return }
        await blizzardIfNeeded(keywords: keywords, actor: actor, owner: owner, triggers: triggers, in: &context)
        guard checkpoint.allowsContinuation(in: context) else { return }
        await talentRepeatIfNeeded(ability: ability, keywords: keywords, actor: actor, abilityTarget: abilityTarget, in: &context)
        guard checkpoint.allowsContinuation(in: context) else { return }
        guard context.resolution.depth(.damage) < ReactionScope.maxDepth,
              !context.resolution.isAutomaticPlay else { return }
        let primingTriggers = context.modifiers(for: actor.id).triggers
        if keywords.contains(.burn) {
            for (keyword, enabled) in repeatPairs(triggers: primingTriggers) where enabled {
                context.roster.mutateRuntime(for: actor) { $0.talents.turn.primedRepeatKeywords.insert(keyword) }
            }
        }
    }

    private static func spellEchoIfNeeded(
        ability: Ability,
        actor: Combatant,
        owner: BattleParticipant,
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) async {
        guard ability.tier == .skill, !context.isEchoingSkill else { return }
        let skillCount = context.turnCadence.skillCardsPlayed[owner, default: 0] + 1
        context.turnCadence.skillCardsPlayed[owner] = skillCount
        let empowered = context.resolution.consumeCardEmpowerment(by: actor.id)
        guard empowered,
              context.modifiers(for: actor.id).triggers.empoweredSkillEchoes
        else { return }
        context.isEchoingSkill = true
        defer { context.isEchoingSkill = false }
        await BattleTurnEngine.performAction(ability: ability, actor: actor, abilityTarget: abilityTarget, origin: .card, context: &context)
    }

    private static func blizzardIfNeeded(
        keywords: Set<Keyword>,
        actor: Combatant,
        owner: BattleParticipant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard keywords.contains(.freeze) else { return }
        let freezeCount = context.turnCadence.freezeCardsPlayed[owner, default: 0] + 1
        context.turnCadence.freezeCardsPlayed[owner] = freezeCount
        let threshold = triggers.freezeCardsPlayedThisTurnFreezeAll
        guard threshold > 0, freezeCount == threshold, context.roster.enemy.isAlive else { return }
        let enemyThreshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
        await ControlMeterEngine.applyMeterCharge(
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

    private static func talentRepeatIfNeeded(
        ability: Ability,
        keywords: Set<Keyword>,
        actor: Combatant,
        abilityTarget: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.resolution.depth(.damage) < ReactionScope.maxDepth,
              !context.resolution.isAutomaticPlay
        else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        for (keyword, enabled) in repeatPairs(triggers: triggers) where keywords.contains(keyword) && enabled {
            var prepared = false
            context.roster.mutateRuntime(for: actor) { prepared = $0.talents.turn.primedRepeatKeywords.remove(keyword) != nil }
            guard prepared else { continue }
            context.resolution.enter(.damage)
            defer { context.resolution.leave(.damage) }
            await BattleTurnEngine.performAction(
                ability: ability,
                actor: actor,
                abilityTarget: abilityTarget,
                origin: .cardRepeat,
                context: &context,
            )
            return
        }
    }

    static func drawAfterSpendMana(by actor: Combatant, in context: inout BattleState) {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return }
        let count = context.modifiers(for: actor.id).triggers.drawOnSpendMana
        guard count > 0, context.turnCadence.spendManaDrawOwners.insert(owner).inserted else { return }
        emitDraw(.drawOnSpendMana, "Runic Quill", count: count, for: owner, actor: actor, in: &context)
    }

    static func drawAfterHealthLoss(by actor: Combatant, in context: inout BattleState) {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster.health(for: actor) > 0 else { return }
        let count = context.modifiers(for: actor.id).triggers.drawOnHealthLoss
        guard count > 0, context.turnCadence.healthLossDrawOwners.insert(owner).inserted else { return }
        emitDraw(.drawOnHealthLoss, "Bone Charm", count: count, for: owner, actor: actor, in: &context)
    }

    static func afterHealthRestored(
        _ amount: Int,
        to actor: Combatant,
        in context: inout BattleState,
    ) {
        resetPantherRedline(afterHealthRestoration: actor, in: &context)
        let percent = context.modifiers(for: actor.id).triggers.healthRestoredNextPoisonDamagePercent
        guard amount > 0, percent > 0, context.roster.runtime(for: actor)?.isAlive == true else {
            return
        }
        context.prepareTalentBonus(CombatRounding.scaled(amount, multiplier: percent), \.nextToxicRemedyDamageBonus, for: actor)
    }

    static func drawCards(
        _ count: Int,
        for owner: BattleParticipant,
        actor: Combatant,
        abilityName: String,
        in context: inout BattleState,
    ) {
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else { return }
        context.nextEvent(
            kind: .effect(.cardsDrawn),
            source: .init(actor),
            abilityName: abilityName,
            target: actor,
            amount: drawn,
            keyword: .physical,
        )
    }
}

// MARK: - Party cards

package extension CombatTriggerEngine {
    static func afterPartyCardPlayed(in context: inout BattleState) async {
        let count = context.turnCadence.cardsPlayed.values.reduce(0, +)

        for owner in BattleParticipant.party {
            let actor = context.roster[owner].combatant
            let triggers = context.modifiers(for: actor.id).triggers
            guard context.roster[owner].isAlive, triggers.cardsPlayedHealPartyThreshold > 0,
                  count == triggers.cardsPlayedHealPartyThreshold,
                  context.resolution.claim(.heroTalent(.playfulEnergy), actorID: actor.id, cadence: .turn(context.turnCount))
            else { continue }
            for (_, target) in livingPartyMembers(in: context) {
                guard context.roster[owner].isAlive else { break }
                await emitHeal(
                    .cardsPlayedHealPartyThreshold, "Playful Energy",
                    amount: triggers.cardsPlayedHealPartyAmount,
                    to: target.combatant, source: actor, in: &context,
                )
            }
        }
    }
}

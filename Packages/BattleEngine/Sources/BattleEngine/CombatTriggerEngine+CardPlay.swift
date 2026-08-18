import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterCardPlayed(
        ability: Ability? = nil,
        by actor: Combatant,
        abilityTarget: Combatant? = nil,
        in context: inout BattleState
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
                in: &context
            ))
            events.append(contentsOf: scholarlySmiteIfNeeded(ability: ability, actor: actor, in: &context))
            events.append(contentsOf: infernoBarrageIfNeeded(ability: ability, actor: actor, triggers: triggers, in: &context))
            events.append(contentsOf: blizzardIfNeeded(
                ability: ability,
                actor: actor,
                owner: owner,
                triggers: triggers,
                in: &context
            ))
        }

        let count = context.cardsPlayedThisTurn[owner, default: 0] + 1
        context.cardsPlayedThisTurn[owner] = count

        if triggers.attackDelayEnemyTurnChancePercent > 0, context.roster.enemy.isAlive,
           BattleChance.succeeds(probability: triggers.attackDelayEnemyTurnChancePercent, using: &context.rng) {
            context.additionalControlSkipsByCombatantID[context.roster.enemy.id, default: 0] += 1
        }

        guard triggers.cardsPlayedManaThreshold > 0, triggers.cardsPlayedManaFlat > 0,
              count == triggers.cardsPlayedManaThreshold
        else { return events }

        let restored = context.restoreMana(triggers.cardsPlayedManaFlat, to: actor)
        guard restored > 0 else { return events }
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: actor.name,
            abilityName: triggerAbilityName(
                "cardsPlayedManaThreshold",
                for: actor,
                fallback: "Resonant Chimes",
                in: context
            ),
            target: actor,
            amount: restored,
            keyword: .mana
        ))
        events.append(contentsOf: afterGainMana(by: actor, in: &context))
        return events
    }

    private static func spellEchoIfNeeded(
        ability: Ability,
        actor: Combatant,
        owner: BattleParticipant,
        abilityTarget: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard ability.tier == .skill else { return [] }
        let skillCount = context.skillCardsPlayedThisTurn[owner, default: 0] + 1
        context.skillCardsPlayedThisTurn[owner] = skillCount
        guard skillCount == 1,
              context.modifiers(for: actor.id).triggers.firstSkillCardPlaysTwicePerBattle,
              !context.skillEchoOwnersThisBattle.contains(actor.id)
        else { return [] }
        context.skillEchoOwnersThisBattle.insert(actor.id)
        return BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context
        )
    }

    private static func scholarlySmiteIfNeeded(
        ability: Ability,
        actor: Combatant,
        in context: inout BattleState
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
                    applyDodge: false
                )
            )
        ).events
    }

    private static func infernoBarrageIfNeeded(
        ability: Ability,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
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
            suppressAffixReactions: true
        )
    }

    private static func blizzardIfNeeded(
        ability: Ability,
        actor: Combatant,
        owner: BattleParticipant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard ability.keywords.contains(.freeze) else { return [] }
        let freezeCount = context.freezeCardsPlayedThisTurn[owner, default: 0] + 1
        context.freezeCardsPlayedThisTurn[owner] = freezeCount
        let threshold = triggers.freezeCardsPlayedThisTurnFreezeAll
        guard threshold > 0, freezeCount >= threshold, context.roster.enemy.isAlive else { return [] }
        let enemyThreshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
        return ControlMeterEngine.applyMeterCharge(
            enemyThreshold,
            keyword: .freeze,
            to: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            applyFightPacing: false,
            in: &context
        )
    }

    static func drawAfterSpendMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnSpendMana
        guard count > 0, context.spendManaDrawOwnersThisTurn.insert(owner).inserted else { return [] }
        return drawCards(
            count,
            for: owner,
            actor: actor,
            abilityName: triggerAbilityName("drawOnSpendMana", for: actor, fallback: "Runic Quill", in: context),
            in: &context
        )
    }

    static func drawAfterHealthLoss(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnHealthLoss
        guard count > 0, context.healthLossDrawOwnersThisTurn.insert(owner).inserted else { return [] }
        return drawCards(
            count,
            for: owner,
            actor: actor,
            abilityName: triggerAbilityName("drawOnHealthLoss", for: actor, fallback: "Bone Charm", in: context),
            in: &context
        )
    }

    static func afterHealthRestored(
        _ amount: Int,
        to actor: Combatant,
        in context: inout BattleState
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
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: true
                )
            )
        ).events
    }

    static func afterBlockGained(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = context.modifiers(for: actor.id).triggers.blockGainThornsPercent
        let gained = CombatRounding.scaled(amount, multiplier: percent)
        guard amount > 0, gained > 0 else { return [] }

        var effects = context.roster.activeEffects(for: actor)
        let existing = effects.reduce(0) { total, active in
            if case let .thorns(stacks) = active.effect {
                return total + stacks
            }
            return total
        }
        effects.removeAll {
            if case .thorns = $0.effect {
                return true
            }
            return false
        }
        let total = existing + gained
        effects.append(ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: .thorns(total),
            remainingTurns: 0,
            sourceActorID: actor.id
        ))
        context.roster.setActiveEffects(effects, for: actor)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: actor.name,
            abilityName: triggerAbilityName(
                "blockGainThornsPercent",
                for: actor,
                fallback: "Thorns",
                in: context
            ),
            target: actor,
            amount: total,
            keyword: .physical
        )]
    }

    static func drawCards(
        _ count: Int,
        for owner: BattleParticipant,
        actor: Combatant,
        abilityName: String,
        in context: inout BattleState
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
            keyword: .physical
        )]
    }
}

import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyTalentMirroredReactions(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let keyword = state.damageKeyword,
              let source = state.partySource(in: context),
              state.combatant.role == .enemy,
              state.amount > 0
        else { return }
        let triggers = context.modifiers(for: source.id).triggers
        applyTalentMirroredDoTs(to: &state, triggers: triggers, keyword: keyword, source: source, in: &context)
        applyTalentBlockAndManaReactions(to: &state, triggers: triggers, keyword: keyword, source: source, in: &context)
        applyTalentDetonations(to: &state, triggers: triggers, keyword: keyword, source: source, in: &context)
        applyTalentCardAndEconomyReactions(to: &state, triggers: triggers, keyword: keyword, source: source, in: &context)
    }

    private static func applyTalentMirroredDoTs(
        to state: inout DamageResolutionState,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        source: CombatantRuntime,
        in context: inout BattleState,
    ) {
        guard state.buildupDamage > 0 else { return }
        let scaled = CombatRounding.scaled(state.buildupDamage, multiplier: 0.5)
        guard scaled > 0 else { return }

        var destinations: [Keyword] = []
        switch keyword {
        case .physical:
            if triggers.toxicTransfusion {
                destinations.append(.poison)
            }
            if triggers.firebrand {
                destinations.append(.burn)
            }
            if triggers.butchersLedger {
                destinations.append(.bleed)
            }
        case .poison:
            if triggers.nerveAgent {
                destinations.append(.stun)
            }
        case .bleed:
            if triggers.crossContamination {
                destinations.append(.poison)
            }
        case .burn:
            if triggers.frostfire {
                destinations.append(.freeze)
            }
        default:
            break
        }

        for dst in destinations {
            state.damageEvents.append(contentsOf: dealTalentMirroredDamage(
                scaled,
                keyword: dst,
                target: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        }
    }

    private static func applyTalentBlockAndManaReactions(
        to state: inout DamageResolutionState,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        source: CombatantRuntime,
        in context: inout BattleState,
    ) {
        if triggers.sunwall, keyword == .holy {
            state.damageEvents.append(contentsOf: grantTalentPartyBlock(
                state.buildupDamage,
                source: source.combatant,
                in: &context,
            ))
        }
        if triggers.iceboundExchange, keyword == .freeze {
            state.damageEvents.append(contentsOf: grantTalentPartyBlockFromBlockedAmount(
                state.blockedAmount,
                source: source.combatant,
                in: &context,
            ))
        }
        if triggers.eyeOfTheStorm, keyword == .stun {
            state.damageEvents.append(contentsOf: context.restoreManaEmitting(
                state.buildupDamage,
                to: source.combatant,
                abilityName: "Eye of the Storm",
            ))
        }
    }

    private static func applyTalentDetonations(
        to state: inout DamageResolutionState,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        source: CombatantRuntime,
        in context: inout BattleState,
    ) {
        if triggers.shatterpoint, keyword == .freeze {
            state.damageEvents.append(contentsOf: detonateTalent(
                .bleed,
                on: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        }
        if triggers.steamExplosion, keyword == .freeze {
            state.damageEvents.append(contentsOf: detonateTalent(
                .burn,
                on: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        }
        if triggers.backdraft, keyword == .burn, state.isCritical {
            state.damageEvents.append(contentsOf: detonateTalent(
                .burn,
                on: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        }
        if triggers.arterialCascade, keyword == .physical, state.isCritical {
            state.damageEvents.append(contentsOf: detonateTalent(
                .bleed,
                on: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        }
    }

    private static func applyTalentCardAndEconomyReactions(
        to state: inout DamageResolutionState,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        source: CombatantRuntime,
        in context: inout BattleState,
    ) {
        if triggers.ashenArsenal, keyword == .burn {
            state.damageEvents.append(contentsOf: drawTalentCard(
                .physical,
                for: source.combatant,
                in: &context,
            ))
        }
        if triggers.bloodrush, keyword == .bleed {
            state.damageEvents.append(contentsOf: drawTalentCard(
                .physical,
                for: source.combatant,
                in: &context,
            ))
        }
        if triggers.bountyBlade, state.isCritical {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                3,
                to: source.combatant,
                abilityName: "Bounty Blade",
            ))
            if let owner = context.roster.participant(for: source.combatant) {
                state.damageEvents.append(contentsOf: CombatTriggerEngine.drawCards(
                    1,
                    for: owner,
                    actor: source.combatant,
                    abilityName: "Bounty Blade",
                    in: &context,
                ))
            }
        }
        if triggers.perfectTempo, keyword == .physical, state.isCritical {
            context.prependEffect(.evadeNextHit, to: source.combatant, remainingTurns: 0)
        }
    }

    private static func dealTalentMirroredDamage(
        _ amount: Int,
        keyword: Keyword,
        target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: target) > 0 else { return [] }
        switch keyword {
        case .burn, .poison:
            return context.applyDecayingDoT(
                keyword: keyword,
                potency: amount,
                to: target,
                sourceActorID: source.id,
                dealImmediateDamage: true,
                suppressAffixReactions: true,
            )
        case .bleed:
            return DoTApplicator.applyBleed(
                potency: amount,
                to: target,
                sourceActorID: source.id,
                dealImmediateDamage: true,
                suppressAffixReactions: true,
                in: &context,
            )
        case .stun, .freeze:
            return context.resolveDamage(DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: false,
                    applyControlMeter: true,
                ),
            )).events
        default:
            return context.resolveDamage(DamageRequest(
                amount: amount,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: false,
                ),
            )).events
        }
    }

    private static func grantTalentPartyBlock(
        _ amount: Int,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return [BattleParticipant.hero, .companion].flatMap { owner -> [ActionEvent] in
            let member = context.roster[owner]
            guard member.isAlive else { return [] }
            return context.applyBlock(amount, to: member.combatant, source: source, abilityName: "Sunwall")
        }
    }

    private static func grantTalentPartyBlockFromBlockedAmount(
        _ amount: Int,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        return grantTalentPartyBlock(amount, source: source, in: &context)
    }

    private static func detonateTalent(
        _ keyword: Keyword,
        on target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if keyword == .bleed {
            return CombatTriggerEngine.detonateBleed(on: target, sourceActorID: source.id, in: &context)
        }
        guard !context.isResolvingDoTDetonation else { return [] }
        context.isResolvingDoTDetonation = true
        defer { context.isResolvingDoTDetonation = false }
        var effects = context.roster.activeEffects(for: target)
        let matching = effects.filter { $0.effect.keyword == keyword }
        effects.removeAll { $0.effect.keyword == keyword }
        context.roster.setActiveEffects(effects, for: target)
        return matching.flatMap { effect in
            DoTDamage.resolveTurnDamage(
                basePotency: effect.effect.potency ?? 0,
                keyword: keyword,
                target: target,
                sourceActorID: source.id,
                in: &context,
            ).events
        }
    }

    private static func drawTalentCard(
        _ keyword: Keyword,
        for actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor) else { return [] }
        let before = context.hand.totalCount
        guard BattleCardCombatEngine.drawFirstCard(matching: keyword, for: owner, context: &context) != nil else { return [] }
        guard context.hand.totalCount > before else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: "Talent Draw",
            target: actor,
            amount: 1,
            keyword: keyword,
        )]
    }
}

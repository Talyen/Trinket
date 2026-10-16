import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    // swiftlint:disable:next function_body_length cyclomatic_complexity - dodge triggers share one ordered cadence
    static func afterDodge(
        by combatant: Combatant,
        attackerID: String?,
        allowsCounterattacks: Bool = true,
        in context: inout BattleState,
    ) async {
        guard context.health(of: combatant) > 0 else { return }
        let profile = context.modifiers(for: combatant.id)
        let triggers = profile.triggers

        context.roster.mutateRuntime(for: combatant) { runtime in
            if triggers.damageAfterDodgeBonus > 0 {
                runtime.talents.pending.damageAfterDodge = SaturatedArithmetic.saturatingAdd(
                    runtime.talents.pending.damageAfterDodge, triggers.damageAfterDodgeBonus,
                )
            }
            if triggers.nextAttackDoubleAfterDodge {
                runtime.talents.pending.doubleDamageAfterDodge = true
            }
            if triggers.onDodgeNextPartyHitGuaranteedCritical {
                runtime.talents.pending.guaranteedCriticalAfterDodge = true
            }
            if triggers.onDodgeNextAttackGuaranteedCritical {
                runtime.talents.pending.guaranteedCriticalAfterDodge = true
            }
            if triggers.nextAttackBleedAfterDodge > 0 {
                runtime.talents.pending.bleedAfterDodge = triggers.nextAttackBleedAfterDodge
            }
            if triggers.critMultiplierPerDodge > 0 {
                runtime.talents.battle.criticalMultiplierBonus = min(
                    1.0,
                    runtime.talents.battle.criticalMultiplierBonus + triggers.critMultiplierPerDodge,
                )
            }
        }
        if triggers.onDodgePartyNextCardDamageBonus > 0 {
            context.resolution.preparePartyCardDamage(triggers.onDodgePartyNextCardDamageBonus, sourceID: combatant.id)
        }
        if triggers.onCompanionDodgeGrantHeroDodgePercent > 0,
           combatant.id == context.roster.companion.id,
           context.roster.hero.isAlive {
            context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                $0.talents.grantDodgeUntilNextTurn(triggers.onCompanionDodgeGrantHeroDodgePercent)
            }
        }

        if triggers.dodgeGoldFlat > 0 {
            await emitGold(.dodgeGoldFlat, "Payday", amount: triggers.dodgeGoldFlat, to: combatant, in: &context)
        }

        // Gold and Mana gains can heal and provoke lethal retaliation before the next Dodge reward.
        guard context.health(of: combatant) > 0 else { return }
        if triggers.dodgeBlockFlat > 0 {
            emitBlock(.dodgeBlockFlat, "Untouchable", amount: triggers.dodgeBlockFlat, to: combatant, source: combatant, in: &context)
        }

        if triggers.onDodgeGrantHeroBlock > 0, context.roster.hero.isAlive {
            emitBlock(
                .onDodgeGrantHeroBlock, "Aerial Cover",
                amount: triggers.onDodgeGrantHeroBlock,
                to: context.roster.hero.combatant, source: combatant, in: &context,
            )
        }

        if triggers.onDodgePartyMana > 0 {
            for (_, member) in livingPartyMembers(in: context) {
                guard context.health(of: combatant) > 0 else { return }
                await emitMana(
                    .onDodgePartyMana, "Dodge",
                    amount: triggers.onDodgePartyMana, to: member.combatant, nameFrom: combatant, in: &context,
                )
            }
        }

        guard context.health(of: combatant) > 0 else { return }
        if triggers.onDodgeDrawCardForHero > 0, context.roster.hero.isAlive {
            let drawn = BattleCardCombatEngine.drawCards(count: triggers.onDodgeDrawCardForHero, for: .hero, context: &context)
            if drawn > 0 {
                context.nextEvent(
                    kind: .effect(.cardsDrawn),
                    source: .init(context.roster.hero),
                    abilityName: triggerAbilityName(.onDodgeDrawCardForHero, for: combatant, fallback: "Tailwind", in: context),
                    target: context.roster.hero.combatant,
                    amount: drawn,
                    keyword: .physical,
                )
            }
        }

        if allowsCounterattacks, triggers.onDodgeDrawAndPlayCardChainOnCrit {
            await drawPlayCascade(for: combatant, in: &context)
        }

        guard context.health(of: combatant) > 0 else { return }
        await applySidestepHeal(for: combatant, profile: profile, in: &context)
        guard context.health(of: combatant) > 0 else { return }
        if allowsCounterattacks, context.roster.enemy.isAlive {
            for (keyword, chance, potency) in [
                (Keyword.bleed, triggers.dodgeBleedChancePercent, triggers.dodgeBleedDamage),
                (Keyword.burn, triggers.dodgeBurnChancePercent, triggers.dodgeBurnDamage),
            ] {
                guard context.health(of: combatant) > 0 else { return }
                guard context.roster.enemy.isAlive else { break }
                guard potency > 0, BattleChance.succeeds(probability: chance, using: &context.rng) else { continue }
                await DoTApplicator.applyDoT(
                    keyword: keyword,
                    potency: potency,
                    to: context.roster.enemy.combatant,
                    sourceActorID: combatant.id,
                    in: &context,
                )
            }
        }
        guard context.health(of: combatant) > 0 else { return }
        if triggers.dodgeApplyPoison > 0, context.roster.enemy.isAlive {
            await context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.dodgeApplyPoison,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                application: .ability,
            )
        }

        guard context.health(of: combatant) > 0 else { return }
        if triggers.onDodgeDelayAttackerTurn, let attackerID,
           let attacker = context.roster.combatant(for: attackerID),
           attacker.role == .enemy {
            context.additionalControlSkipsByCombatantID[attackerID, default: 0] += 1
        }

        var pendingCounterIndex: Int?
        if let attackerID, let attackerRuntime = context.roster.combatant(for: attackerID), attackerRuntime.isAlive {
            let target = attackerRuntime.combatant

            if allowsCounterattacks, triggers.onDodgeCounterDamage > 0 {
                _ = await context.dealReactionDamage(
                    triggers.onDodgeCounterDamage, to: target, keyword: .physical, sourceActorID: combatant.id,
                )
            }
            guard context.health(of: combatant) > 0 else { return }
            if allowsCounterattacks, triggers.onDodgeCounterBasicAttack {
                pendingCounterIndex = await counterWithBasicAttack(by: combatant, in: &context)
            }
            guard context.health(of: combatant) > 0 else { return }
            if triggers.onDodgeApplyPoisonOrBleed > 0, context.health(of: target) > 0 {
                // `applyDoT` routes bleed to its dedicated applicator and
                // everything else to decaying DoTs, matching the two direct
                // calls this replaces with one RNG draw either way.
                let keyword: Keyword = BattleChance.succeeds(probability: 0.5, using: &context.rng) ? .poison : .bleed
                await DoTApplicator.applyDoT(
                    keyword: keyword,
                    potency: triggers.onDodgeApplyPoisonOrBleed,
                    to: target,
                    sourceActorID: combatant.id,
                    application: .reaction,
                    in: &context,
                )
            }
            guard context.health(of: combatant) > 0 else { return }
            if triggers.onDodgeAttackerStunBuildup > 0, context.health(of: target) > 0 {
                await ControlMeterEngine.applyMeterCharge(
                    triggers.onDodgeAttackerStunBuildup,
                    keyword: .stun,
                    to: target,
                    sourceActorID: combatant.id,
                    applyFightPacing: false,
                    in: &context,
                )
            }
        }

        guard context.health(of: combatant) > 0 else { return }
        if allowsCounterattacks, triggers.phantomCounter,
           context.resolution.depth(.damage) < ReactionScope.maxDepth,
           context.resolution.depth(.dot) < ReactionScope.maxDepth,
           context.resolution.depth(.draw) < BattleState.maxDrawAndPlayDepth,
           !context.resolution.isAutomaticPlay,
           let owner = context.roster.participant(for: combatant),
           let card = BattleCardCombatEngine.drawFirstCard(matching: .physical, for: owner, context: &context) {
            context.resolution.enter(.damage)
            context.resolution.enter(.dot)
            context.resolution.enter(.draw)
            defer {
                context.resolution.leave(.damage)
                context.resolution.leave(.dot)
                context.resolution.leave(.draw)
            }
            _ = await context.withAutomaticPlay { context in
                await (try? BattleCardCombatEngine.playDrawnCard(card, context: &context)) ?? []
            }
        }

        guard context.health(of: combatant) > 0 else { return }
        await afterCompanionDodge(by: combatant, in: &context)
        // Deferred Basics must finish before these preparations replace any older readiness.
        if let pendingCounterIndex {
            context.uniques.pendingCounterAttacks[pendingCounterIndex].preparesDodgeAttackBonuses = true
        } else {
            prepareDodgeAttackBonuses(for: combatant, in: &context)
        }
    }

    private static func prepareDodgeAttackBonuses(for combatant: Combatant, in context: inout BattleState) {
        let triggers = context.modifiers(for: combatant.id).triggers
        context.prepareAttackBonus(triggers.dodgeNextStunAttackBonus, \.nextDodgeStunAttackBonus, for: combatant)
        context.prepareAttackBonus(triggers.dodgeNextFreezeAttackBonus, \.nextDodgeFreezeAttackBonus, for: combatant)
        context.prepareAttackBonus(triggers.dodgeNextBleedAttackBonus, \.nextDodgeBleedAttackBonus, for: combatant)
    }

    private static func counterWithBasicAttack(
        by actor: Combatant,
        in context: inout BattleState,
    ) async -> Int? {
        guard !context.isBattleOver, context.roster.health(for: actor) > 0,
              let owner = context.roster.participant(for: actor),
              !context.ownersSkippingThisPlayerTurn.contains(owner),
              !context.roster.hasPendingActionSkip(for: actor),
              let ability = actor.abilityLoadout.basic,
              BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context)
        else { return nil }
        // Defer while inside damage resolution, like UniqueCombatEngine's
        // out-of-turn summons: a full Basic nested in the damage pipeline
        // overflows small worker-thread stacks.
        guard context.resolution.depth(.damage) == 0 else {
            let index = context.uniques.pendingCounterAttacks.count
            context.uniques.pendingCounterAttacks.append(.init(actorID: actor.id))
            return index
        }
        await BattleTurnEngine.performAction(
            ability: ability,
            actor: actor,
            abilityTarget: BattleActionContext(actor: actor, in: context).selectedTarget,
            origin: .counterattack,
            context: &context,
        )
        return nil
    }

    static func drainPendingCounterAttacks(in context: inout BattleState) async {
        guard !context.uniques.pendingCounterAttacks.isEmpty else { return }

        while !context.uniques.pendingCounterAttacks.isEmpty {
            let counter = context.uniques.pendingCounterAttacks.removeFirst()
            guard let actor = context.roster.combatant(for: counter.actorID)?.combatant else { continue }
            _ = await counterWithBasicAttack(by: actor, in: &context)
            if counter.preparesDodgeAttackBonuses {
                prepareDodgeAttackBonuses(for: actor, in: &context)
            }
        }
    }

    private static func drawPlayCascade(
        for combatant: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: combatant) > 0 else { return }
        let cascadeAbility = Ability(id: "dance-of-blades", name: "Dance of Blades", tier: .basic)

        for _ in 0 ..< BattleState.maxDrawAndPlayDepth {
            guard context.health(of: combatant) > 0 else { return }
            let played = await EffectApplication(
                effect: .drawAndPlayCards(1),
                ability: cascadeAbility,
                source: combatant,
                target: combatant,
            ).apply(in: &context)
            guard played.didApply else { break }

            guard played.criticalAttackActorIDs.contains(combatant.id) else { break }
        }
    }

    private static func applySidestepHeal(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState,
    ) async {
        guard context.health(of: combatant) > 0, profile.triggers.dodgeHealFlat > 0 else { return }
        let target = BattleActionContext(actor: combatant, in: context).target(.lowestHealthAlly, in: context)
        await emitHeal(.dodgeHealFlat, "Sidestep", amount: profile.triggers.dodgeHealFlat, to: target, source: combatant, in: &context)
    }
}

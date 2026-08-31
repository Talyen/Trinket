import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func drawOppositeElement(
        afterEmpowering keyword: Keyword,
        by actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.modifiers(for: actor.id).triggers.empoweredElementDrawOpposite,
              let owner = context.roster.participant(for: actor),
              owner.isPartyMember
        else { return [] }
        let opposite: Keyword = keyword == .burn ? .freeze : .burn
        guard BattleCardCombatEngine.drawFirstCard(
            matching: opposite,
            for: owner,
            context: &context,
        ) != nil else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: triggerAbilityName(
                "empoweredElementDrawOpposite",
                for: actor,
                fallback: "Twin Casting",
                in: context,
            ),
            target: actor,
            amount: 1,
            keyword: .physical,
        )]
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func afterSpendMana(by actor: Combatant, amountSpent: Int, in context: inout BattleState) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        let triggers = profile.triggers
        var events: [ActionEvent] = []
        events.append(contentsOf: drawAfterSpendMana(by: actor, in: &context))

        if triggers.spendManaBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.spendManaBlockFlat,
                to: actor,
                source: actor,
                abilityName: triggerAbilityName("spendManaBlockFlat", for: actor, fallback: "Aetherward", in: context),
            ))
        }

        if actor.role == .hero, let companionTriggers = companionReactingToHeroTriggers(in: context) {
            if companionTriggers.onHeroSpendManaGainBlock > 0 {
                events.append(contentsOf: context.applyBlock(
                    companionTriggers.onHeroSpendManaGainBlock,
                    to: context.roster.companion.combatant,
                    source: actor,
                    abilityName: triggerAbilityName(
                        "onHeroSpendManaGainBlock",
                        for: context.roster.companion.combatant,
                        fallback: "Mana Absorption",
                        in: context,
                    ),
                ))
            }
            if companionTriggers.onHeroSpendManaCompanionNextAttackBonus > 0 {
                context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                    $0.pendingCardDamageBonus += companionTriggers.onHeroSpendManaCompanionNextAttackBonus
                }
            }
        }

        if triggers.spendManaRefundChancePercent > 0,
           BattleChance.succeeds(probability: triggers.spendManaRefundChancePercent, using: &context.rng) {
            events.append(contentsOf: context.restoreManaEmitting(
                amountSpent,
                to: actor,
                abilityName: triggerAbilityName(
                    "spendManaRefundChancePercent",
                    for: actor,
                    fallback: "Mana Flow",
                    in: context,
                ),
            ))
        }

        if triggers.onSpendManaBurnBurningEnemies > 0, context.roster.enemy.isAlive,
           context.roster.activeEffects(for: context.roster.enemy.combatant).contains(where: { $0.effect.keyword == .burn }) {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: triggers.onSpendManaBurnBurningEnemies,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
            ))
        }

        if actor.role == .hero, triggers.onHeroSpendManaApplyRandomAffliction, context.roster.enemy.isAlive {
            let keywords: [Keyword] = [.bleed, .burn, .poison]
            let keyword = keywords.randomElement(using: &context.rng) ?? .burn
            if keyword == .bleed {
                events.append(contentsOf: DoTApplicator.applyBleed(
                    potency: 1,
                    to: context.roster.enemy.combatant,
                    sourceActorID: actor.id,
                    dealImmediateDamage: false,
                    suppressAffixReactions: true,
                    in: &context,
                ))
            } else {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: keyword,
                    potency: 1,
                    to: context.roster.enemy.combatant,
                    sourceActorID: actor.id,
                    dealImmediateDamage: false,
                    suppressAffixReactions: true,
                ))
            }
        }

        let cocoonMet = triggers.spendManaThresholdBlockThreshold > 0
            && amountSpent >= triggers.spendManaThresholdBlockThreshold
        if cocoonMet, context.claimActionGuard(.spendCocoon, actorID: actor.id) {
            if triggers.spendManaThresholdBlockBlock > 0 {
                events.append(contentsOf: context.applyBlock(
                    triggers.spendManaThresholdBlockBlock,
                    to: actor,
                    source: actor,
                    abilityName: triggerAbilityName(
                        "spendManaThresholdBlockThreshold",
                        for: actor,
                        fallback: "Mana Cocoon",
                        in: context,
                    ),
                ))
            }
            if triggers.spendManaThresholdBlockHealth > 0 {
                events.append(contentsOf: context.healEmitting(
                    amount: triggers.spendManaThresholdBlockHealth,
                    target: actor,
                    source: actor,
                    abilityName: triggerAbilityName(
                        "spendManaThresholdBlockThreshold",
                        for: actor,
                        fallback: "Mana Cocoon",
                        in: context,
                    ),
                ))
            }
        }
        let overchargeMet = triggers.spendManaEmpowerNextCardThreshold > 0
            && amountSpent >= triggers.spendManaEmpowerNextCardThreshold
        if overchargeMet, context.claimActionGuard(.spendOvercharge, actorID: actor.id) {
            if triggers.nextCardEmpowerPercent > 0 {
                context.roster.mutateRuntime(for: actor) {
                    $0.pendingCardDamagePercent += triggers.nextCardEmpowerPercent
                }
            }
        }
        let cleanseMet = triggers.spendManaThresholdCleanseCount > 0
            && amountSpent >= triggers.spendManaThresholdCleanseCount
        if cleanseMet, context.claimActionGuard(.spendCleanse, actorID: actor.id) {
            events.append(contentsOf: performRandomCleanses(
                source: actor,
                target: actor,
                count: 1,
                abilityName: triggerAbilityName(
                    "spendManaThresholdCleanseCount",
                    for: actor,
                    fallback: "Arcane Cleansing",
                    in: context,
                ),
                in: &context,
            ))
        }
        let chaosRiftMet = triggers.spendManaChaosRiftThreshold > 0
            && amountSpent >= triggers.spendManaChaosRiftThreshold
            && triggers.spendManaChaosRiftDamage > 0
            && context.roster.enemy.isAlive
        if chaosRiftMet, context.claimActionGuard(.spendChaosRift, actorID: actor.id) {
            let half = triggers.spendManaChaosRiftDamage / 2
            let keywords = [Keyword.freeze, .burn, .poison, .holy].shuffled(using: &context.rng)
            for keyword in keywords.prefix(2) {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: half,
                        target: context.roster.enemy.combatant,
                        keyword: keyword,
                        sourceActorID: actor.id,
                        options: .flatReaction,
                    ),
                ).events)
            }
        }
        let freezeMet = triggers.spendManaFreezeThreshold > 0
            && amountSpent >= triggers.spendManaFreezeThreshold
            && context.roster.enemy.isAlive
        if freezeMet, context.claimActionGuard(.spendFreeze, actorID: actor.id) {
            let freezeAmount = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                freezeAmount,
                keyword: .freeze,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                in: &context,
            ))
        }

        if triggers.spendManaDamageBonusPerMana > 0,
           amountSpent >= BattleTurnEngine.manaEmpowermentCost {
            context.roster.mutateRuntime(for: actor) {
                $0.pendingCardDamageBonus += amountSpent * triggers.spendManaDamageBonusPerMana
            }
        }

        if triggers.onReachZeroManaRestoreMana > 0,
           context.roster.runtime(for: actor)?.currentMana == 0,
           context.claimBattleGuard(.darkRecovery, actorID: actor.id) {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.onReachZeroManaRestoreMana,
                to: actor,
                abilityName: triggerAbilityName(
                    "onReachZeroManaRestoreMana",
                    for: actor,
                    fallback: "Dark Recovery",
                    in: context,
                ),
            ))
        }

        if triggers.closedCircuit, amountSpent > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: context.resolveDamage(DamageRequest(
                amount: amountSpent,
                target: context.roster.enemy.combatant,
                keyword: .stun,
                sourceActorID: actor.id,
                options: .flatReaction,
            )).events)
        }

        if triggers.spendManaThresholdAutoPlayCard > 0, !context.isResolvingAutoPlayCard {
            if context.claimActionGuard(.arcaneBurst, actorID: actor.id) {
                context.roster.mutateRuntime(for: actor) { $0.manaSpentThisCardPlay = 0 }
            }
            let totalSpent = (context.roster.runtime(for: actor)?.manaSpentThisCardPlay ?? 0) + amountSpent
            context.roster.mutateRuntime(for: actor) { $0.manaSpentThisCardPlay = totalSpent }
            if totalSpent >= triggers.spendManaThresholdAutoPlayCard {
                context.roster.mutateRuntime(for: actor) { $0.manaSpentThisCardPlay = 0 }
                context.isResolvingAutoPlayCard = true
                defer { context.isResolvingAutoPlayCard = false }
                let outcome = DrawAndPlayCardsHandler().apply(
                    .drawAndPlayCards(1),
                    ability: actor.abilityLoadout.basic ?? Ability(
                        id: "arcane-burst",
                        name: "Arcane Burst",
                        tier: .basic,
                        directDamage: 0,
                        damageKeyword: .physical,
                        description: "",
                    ),
                    source: actor,
                    target: actor,
                    in: &context,
                )
                events.append(contentsOf: outcome.events)
            }
        }

        let randomDoT = triggers.spendManaRandomDoTFlat
        if randomDoT > 0, context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: randomDoT,
                    to: enemy,
                    sourceActorID: actor.id,
                    dealImmediateDamage: true,
                ))
            } else {
                events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                    randomDoT,
                    keyword: .freeze,
                    to: enemy,
                    sourceActorID: actor.id,
                    applyFightPacing: false,
                    in: &context,
                ))
            }
        }

        return events
    }

    static func afterGainMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        let amount = triggers.gainManaBlockFlat
        if amount > 0 {
            events.append(contentsOf: context.applyBlock(
                amount,
                to: actor,
                source: actor,
                abilityName: triggerAbilityName("gainManaBlockFlat", for: actor, fallback: "Arcane Ward", in: context),
            ))
        }
        if triggers.onGainManaHealFlat > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.onGainManaHealFlat,
                target: actor,
                source: actor,
                abilityName: triggerAbilityName(
                    "onGainManaHealFlat",
                    for: actor,
                    fallback: "Life Tap",
                    in: context,
                ),
            ))
        }
        return events
    }
}

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

    // swiftlint:disable:next function_body_length cyclomatic_complexity - mana triggers share one ordered cadence
    internal static func afterSpendMana(_ payment: ManaPayment, in context: inout BattleState) -> [ActionEvent] {
        guard let actor = context.roster.combatant(for: payment.payerID)?.combatant else { return [] }
        let amountSpent = payment.amountSpent
        let spentLastMana = payment.spentLastMana
        let triggers = context.modifiers(for: actor.id).triggers
        return CombatCheckpoint.payment(payment).resolve([
            { afterHeroTalentSpendMana(actor: actor, amount: amountSpent, in: &$0) },
            { drawAfterSpendMana(by: actor, in: &$0) },
            { context in
                var events: [ActionEvent] = []
                if triggers.spendManaBlockFlat > 0 {
                    events.append(contentsOf: context.applyBlock(
                        triggers.spendManaBlockFlat,
                        to: actor,
                        source: actor,
                        abilityName: triggerAbilityName("spendManaBlockFlat", for: actor, fallback: "Aetherward", in: context),
                    ))
                }
                return events
            },
            { context in
                var events: [ActionEvent] = []
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
                    if companionTriggers.onHeroSpendManaCompanionNextAttackBonus > 0,
                       context.roster.health(for: actor) > 0, context.roster.companion.isAlive {
                        context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                            $0.talents.pending.cardDamageBonus += companionTriggers.onHeroSpendManaCompanionNextAttackBonus
                        }
                    }
                }
                return events
            },
            { context in
                var events: [ActionEvent] = []
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
                return events
            },
            { context in
                var events: [ActionEvent] = []
                if triggers.onSpendManaBurnBurningEnemies > 0, context.roster.enemy.isAlive,
                   context.roster.hasAffliction(.burn, on: context.enemy) {
                    events.append(contentsOf: applyDoT(
                        keyword: .burn,
                        potency: triggers.onSpendManaBurnBurningEnemies,
                        to: context.roster.enemy.combatant,
                        sourceActorID: actor.id,
                        in: &context,
                    ))
                }
                return events
            },
            { context in
                var events: [ActionEvent] = []
                if actor.role == .hero, triggers.onHeroSpendManaApplyRandomAffliction, context.roster.enemy.isAlive {
                    let keywords: [Keyword] = [.bleed, .burn, .poison]
                    let keyword = keywords.randomElement(using: &context.rng) ?? .burn
                    if keyword == .bleed {
                        events.append(contentsOf: DoTApplicator.applyBleed(
                            potency: 1,
                            to: context.roster.enemy.combatant,
                            sourceActorID: actor.id,
                            application: .attached,
                            in: &context,
                        ))
                    } else {
                        events.append(contentsOf: context.applyDecayingDoT(
                            keyword: keyword,
                            potency: 1,
                            to: context.roster.enemy.combatant,
                            sourceActorID: actor.id,
                            application: .attached,
                        ))
                    }
                }
                return events
            },
            { context in
                var events: [ActionEvent] = []
                if triggers.spendManaGrantsEqualBlock, amountSpent > 0 {
                    events.append(contentsOf: context.applyBlock(
                        amountSpent, to: actor, source: actor, abilityName: "Mana Cocoon",
                    ))
                }
                return events
            },
            { context in
                let overchargeMet = triggers.spendManaEmpowerNextCardThreshold > 0
                    && amountSpent >= triggers.spendManaEmpowerNextCardThreshold
                if overchargeMet, context.claimActionGuard(.spendOvercharge, actorID: actor.id) {
                    if triggers.nextCardEmpowerPercent > 0 {
                        context.roster.mutateRuntime(for: actor) {
                            $0.talents.pending.cardDamagePercent += triggers.nextCardEmpowerPercent
                        }
                    }
                }
                return []
            },
            { context in
                if triggers.spendManaRemovesAfflictions, amountSpent > 0 {
                    let keywords = [Keyword.burn, .poison].filter { keyword in
                        context.roster.activeEffects(for: actor).contains { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }
                    }
                    if let keyword = keywords.randomElement(using: &context.rng) {
                        _ = DoTApplicator.consume(keyword, upTo: amountSpent, on: actor, in: &context)
                    }
                }
                return []
            },
            { context in
                var events: [ActionEvent] = []
                if triggers.spendManaRandomElementDamage, amountSpent > 0, context.roster.enemy.isAlive {
                    let keywords = [Keyword.freeze, .burn, .poison, .holy].shuffled(using: &context.rng)
                    let amounts = [amountSpent / 2 + amountSpent % 2, amountSpent / 2]
                    for (keyword, amount) in zip(keywords.prefix(2), amounts) where amount > 0 {
                        guard CombatCheckpoint.payment(payment).allowsContinuation(in: context) else { break }
                        events.append(contentsOf: context.resolveDamage(
                            DamageRequest(
                                amount: amount,
                                target: context.roster.enemy.combatant,
                                keyword: keyword,
                                sourceActorID: actor.id,
                                options: .reaction(),
                            ),
                        ).events)
                    }
                }
                return events
            },
            { context in
                if triggers.spendManaDamageBonusPerMana > 0,
                   amountSpent >= BattleTurnEngine.manaEmpowermentCost {
                    context.roster.mutateRuntime(for: actor) {
                        $0.talents.pending.cardDamageBonus += amountSpent * triggers.spendManaDamageBonusPerMana
                    }
                }
                return []
            },
            { context in
                var events: [ActionEvent] = []
                if triggers.onReachZeroManaRestoreMana > 0,
                   spentLastMana,
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
                return events
            },
            { context in
                var events: [ActionEvent] = []
                if triggers.closedCircuit, amountSpent > 0, context.roster.enemy.isAlive {
                    events.append(contentsOf: context.resolveDamage(DamageRequest(
                        amount: amountSpent,
                        target: context.roster.enemy.combatant,
                        keyword: .stun,
                        sourceActorID: actor.id,
                        options: .reaction(),
                    )).events)
                }
                return events
            },
            { context in
                var events: [ActionEvent] = []
                if triggers.spendLastManaStunDamage > 0,
                   spentLastMana,
                   context.roster.enemy.isAlive {
                    events.append(contentsOf: context.resolveDamage(DamageRequest(
                        amount: triggers.spendLastManaStunDamage,
                        target: context.roster.enemy.combatant,
                        keyword: .stun,
                        sourceActorID: actor.id,
                        options: .reaction(),
                    )).events)
                }
                return events
            },
            { autoPlayAfterManaSpend(by: actor, amountSpent: amountSpent, in: &$0) },
            { context in
                var events: [ActionEvent] = []
                let randomDoT = triggers.spendManaRandomDoTFlat
                if randomDoT > 0, context.roster.enemy.isAlive {
                    let enemy = context.roster.enemy.combatant
                    if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
                        events.append(contentsOf: context.applyDecayingDoT(
                            keyword: .burn,
                            potency: randomDoT,
                            to: enemy,
                            sourceActorID: actor.id,
                            application: .ability,
                        ))
                    } else {
                        events.append(contentsOf: context.resolveDamage(DamageRequest(
                            amount: randomDoT,
                            target: enemy,
                            keyword: .freeze,
                            sourceActorID: actor.id,
                            options: .reaction(),
                        )).events)
                    }
                }
                return events
            },
        ], in: &context)
    }

    private static func autoPlayAfterManaSpend(
        by actor: Combatant,
        amountSpent: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let threshold = context.modifiers(for: actor.id).triggers.spendManaThresholdAutoPlayCard
        guard threshold > 0, amountSpent > 0, !context.resolution.isAutomaticPlay else { return [] }
        let totalSpent = (context.roster.runtime(for: actor)?.talents.battle.manaSpentTowardAutoPlay ?? 0) + amountSpent
        context.roster.mutateRuntime(for: actor) { $0.talents.battle.manaSpentTowardAutoPlay = totalSpent % threshold }
        guard totalSpent >= threshold else { return [] }
        return context.withAutomaticPlay { context in
            var events: [ActionEvent] = []
            for _ in 0 ..< totalSpent / threshold {
                guard context.roster.health(for: actor) > 0, !context.isBattleOver else { break }
                let outcome = DrawAndPlayCardsHandler().apply(
                    .drawAndPlayCards(1),
                    ability: Ability(id: "arcane-burst", name: "Arcane Burst", tier: .basic),
                    source: actor,
                    target: actor,
                    in: &context,
                )
                events.append(contentsOf: outcome.events)
            }
            return events
        }
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

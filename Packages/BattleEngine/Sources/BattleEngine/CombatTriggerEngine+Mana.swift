import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
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
                abilityName: affixName(.aetherward)
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
                        in: context
                    )
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
            let refunded = context.restoreMana(amountSpent, to: actor)
            if refunded > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: triggerAbilityName(
                        "spendManaRefundChancePercent",
                        for: actor,
                        fallback: "Mana Flow",
                        in: context
                    ),
                    target: actor,
                    amount: refunded,
                    keyword: .mana
                ))
                events.append(contentsOf: afterGainMana(by: actor, in: &context))
            }
        }

        if triggers.onSpendManaBurnBurningEnemies > 0, context.roster.enemy.isAlive,
           context.roster.activeEffects(for: context.roster.enemy.combatant).contains(where: { $0.effect.keyword == .burn }) {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: triggers.onSpendManaBurnBurningEnemies,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true
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
                    in: &context
                ))
            } else {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: keyword,
                    potency: 1,
                    to: context.roster.enemy.combatant,
                    sourceActorID: actor.id,
                    dealImmediateDamage: false,
                    suppressAffixReactions: true
                ))
            }
        }

        // Once-per-action spend thresholds: Mana Cocoon, Overcharge, Arcane Cleansing, Chaos Rift, Freeze.
        let cocoonKey = TalentActionGuardKey(kind: .spendCocoon, actorID: actor.id)
        if context.talentActionGuardByActorID[cocoonKey] != context.actionCount {
            if triggers.spendManaThresholdBlockThreshold > 0, amountSpent >= triggers.spendManaThresholdBlockThreshold {
                context.talentActionGuardByActorID[cocoonKey] = context.actionCount
                if triggers.spendManaThresholdBlockBlock > 0 {
                    events.append(contentsOf: context.applyBlock(
                        triggers.spendManaThresholdBlockBlock,
                        to: actor,
                        source: actor,
                        abilityName: triggerAbilityName(
                            "spendManaThresholdBlockThreshold",
                            for: actor,
                            fallback: "Mana Cocoon",
                            in: context
                        )
                    ))
                }
                if triggers.spendManaThresholdBlockHealth > 0 {
                    events.append(contentsOf: HealingEngine.resolveHeal(
                        HealRequest(
                            amount: triggers.spendManaThresholdBlockHealth,
                            target: actor,
                            sourceActorID: actor.id,
                            logAs: .instantHeal(
                                actorName: actor.name,
                                abilityName: triggerAbilityName(
                                    "spendManaThresholdBlockThreshold",
                                    for: actor,
                                    fallback: "Mana Cocoon",
                                    in: context
                                ),
                                keyword: .health,
                                displayAmount: triggers.spendManaThresholdBlockHealth
                            )
                        ),
                        in: &context
                    ).events)
                }
            }
        }
        let overchargeKey = TalentActionGuardKey(kind: .spendOvercharge, actorID: actor.id)
        if context.talentActionGuardByActorID[overchargeKey] != context.actionCount {
            if triggers.spendManaEmpowerNextCardThreshold > 0, amountSpent >= triggers.spendManaEmpowerNextCardThreshold {
                context.talentActionGuardByActorID[overchargeKey] = context.actionCount
                if triggers.nextCardEmpowerPercent > 0 {
                    context.roster.mutateRuntime(for: actor) {
                        $0.pendingCardDamagePercent += triggers.nextCardEmpowerPercent
                    }
                }
            }
        }
        let cleanseKey = TalentActionGuardKey(kind: .spendCleanse, actorID: actor.id)
        if context.talentActionGuardByActorID[cleanseKey] != context.actionCount {
            if triggers.spendManaThresholdCleanseCount > 0, amountSpent >= triggers.spendManaThresholdCleanseCount {
                context.talentActionGuardByActorID[cleanseKey] = context.actionCount
                events.append(contentsOf: performRandomCleanses(
                    source: actor,
                    target: actor,
                    count: 1,
                    abilityName: triggerAbilityName(
                        "spendManaThresholdCleanseCount",
                        for: actor,
                        fallback: "Arcane Cleansing",
                        in: context
                    ),
                    in: &context
                ))
            }
        }
        let chaosRiftKey = TalentActionGuardKey(kind: .spendChaosRift, actorID: actor.id)
        if context.talentActionGuardByActorID[chaosRiftKey] != context.actionCount {
            if triggers.spendManaChaosRiftThreshold > 0, amountSpent >= triggers.spendManaChaosRiftThreshold,
               triggers.spendManaChaosRiftDamage > 0, context.roster.enemy.isAlive {
                context.talentActionGuardByActorID[chaosRiftKey] = context.actionCount
                let half = triggers.spendManaChaosRiftDamage / 2
                let keywords = [Keyword.freeze, .burn, .poison, .holy].shuffled(using: &context.rng)
                for keyword in keywords.prefix(2) {
                    events.append(contentsOf: context.resolveDamage(
                        DamageRequest(
                            amount: half,
                            target: context.roster.enemy.combatant,
                            keyword: keyword,
                            sourceActorID: actor.id,
                            options: DamageOptions(
                                applyStatBonus: false,
                                applyItemBonus: false,
                                applyDodge: false,
                                isRetaliation: true
                            )
                        )
                    ).events)
                }
            }
        }
        let freezeKey = TalentActionGuardKey(kind: .spendFreeze, actorID: actor.id)
        if context.talentActionGuardByActorID[freezeKey] != context.actionCount {
            if triggers.spendManaFreezeThreshold > 0, amountSpent >= triggers.spendManaFreezeThreshold,
               context.roster.enemy.isAlive {
                context.talentActionGuardByActorID[freezeKey] = context.actionCount
                let freezeAmount = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
                events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                    freezeAmount,
                    keyword: .freeze,
                    to: context.roster.enemy.combatant,
                    sourceActorID: actor.id,
                    in: &context
                ))
            }
        }

        // Arcane Breath: Mana spent on empowering a card adds bonus damage per Mana spent.
        if triggers.spendManaDamageBonusPerMana > 0,
           amountSpent >= BattleTurnEngine.manaEmpowermentCost {
            context.roster.mutateRuntime(for: actor) {
                $0.pendingCardDamageBonus += amountSpent * triggers.spendManaDamageBonusPerMana
            }
        }

        // Dark Recovery: the first time you reach 0 Mana each battle, immediately restore Mana.
        if triggers.onReachZeroManaRestoreMana > 0,
           context.roster.runtime(for: actor)?.currentMana == 0,
           context.talentActionGuardByActorID[TalentActionGuardKey(kind: .darkRecovery, actorID: actor.id)] == nil {
            context.talentActionGuardByActorID[TalentActionGuardKey(kind: .darkRecovery, actorID: actor.id)] = 1
            let restored = context.restoreMana(triggers.onReachZeroManaRestoreMana, to: actor)
            if restored > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: triggerAbilityName(
                        "onReachZeroManaRestoreMana",
                        for: actor,
                        fallback: "Dark Recovery",
                        in: context
                    ),
                    target: actor,
                    amount: restored,
                    keyword: .mana
                ))
                events.append(contentsOf: afterGainMana(by: actor, in: &context))
            }
        }

        // Arcane Burst: spending enough Mana draws and automatically plays a random card.
        if triggers.spendManaThresholdAutoPlayCard > 0, !context.isResolvingAutoPlayCard {
            let burstKey = TalentActionGuardKey(kind: .arcaneBurst, actorID: actor.id)
            if context.talentActionGuardByActorID[burstKey] != context.actionCount {
                context.roster.mutateRuntime(for: actor) { $0.manaSpentThisCardPlay = 0 }
                context.talentActionGuardByActorID[burstKey] = context.actionCount
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
                        description: ""
                    ),
                    source: actor,
                    target: actor,
                    action: ActionApplyContext(),
                    in: &context
                )
                events.append(contentsOf: outcome.events)
            }
        }

        let randomDoT = triggers.spendManaRandomDoTFlat
        if randomDoT > 0, context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            if Bool.random(using: &context.rng) {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: randomDoT,
                    to: enemy,
                    sourceActorID: actor.id,
                    dealImmediateDamage: true
                ))
            } else {
                events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                    randomDoT,
                    keyword: .freeze,
                    to: enemy,
                    sourceActorID: actor.id,
                    applyFightPacing: false,
                    in: &context
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
                abilityName: affixName(.arcaneWard)
            ))
        }
        if triggers.onGainManaHealFlat > 0 {
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: triggers.onGainManaHealFlat,
                    target: actor,
                    sourceActorID: actor.id,
                    logAs: .instantHeal(
                        actorName: actor.name,
                        abilityName: triggerAbilityName(
                            "onGainManaHealFlat",
                            for: actor,
                            fallback: "Life Tap",
                            in: context
                        ),
                        keyword: .health,
                        displayAmount: triggers.onGainManaHealFlat
                    )
                ),
                in: &context
            ).events)
        }
        return events
    }
}

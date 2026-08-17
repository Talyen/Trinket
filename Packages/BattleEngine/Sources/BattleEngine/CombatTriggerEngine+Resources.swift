import TrinketContent
import TrinketCore

// swiftlint:disable file_length
package extension CombatTriggerEngine {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
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

        if triggers.spendManaGrantsEqualBlock, amountSpent > 0 {
            events.append(contentsOf: context.applyBlock(
                amountSpent,
                to: actor,
                source: actor,
                abilityName: "Eldritch Shield"
            ))
        }

        if triggers.onHeroSpendManaGainBlock > 0, actor.role == .hero, context.roster.companion.isAlive {
            events.append(contentsOf: context.applyBlock(
                triggers.onHeroSpendManaGainBlock,
                to: context.roster.companion.combatant,
                source: actor,
                abilityName: "Mana Absorption"
            ))
        }

        if triggers.onHeroSpendManaCompanionNextAttackBonus > 0, actor.role == .hero, context.roster.companion.isAlive {
            context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                $0.pendingCardDamageBonus += triggers.onHeroSpendManaCompanionNextAttackBonus
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
                    abilityName: "Mana Flow",
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

        if triggers.onHeroSpendManaApplyRandomAffliction, context.roster.enemy.isAlive {
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
        let cocoonKey = "spend:cocoon:\(actor.id)"
        if context.talentActionGuardByActorID[cocoonKey] != context.actionCount {
            if triggers.spendManaThresholdBlockThreshold > 0, amountSpent >= triggers.spendManaThresholdBlockThreshold {
                context.talentActionGuardByActorID[cocoonKey] = context.actionCount
                if triggers.spendManaThresholdBlockBlock > 0 {
                    events.append(contentsOf: context.applyBlock(
                        triggers.spendManaThresholdBlockBlock,
                        to: actor,
                        source: actor,
                        abilityName: "Mana Cocoon"
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
                                abilityName: "Mana Cocoon",
                                keyword: .health,
                                displayAmount: triggers.spendManaThresholdBlockHealth
                            )
                        ),
                        in: &context
                    ).events)
                }
            }
        }
        let overchargeKey = "spend:overcharge:\(actor.id)"
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
        let cleanseKey = "spend:cleanse:\(actor.id)"
        if context.talentActionGuardByActorID[cleanseKey] != context.actionCount {
            if triggers.spendManaThresholdCleanseCount > 0, amountSpent >= triggers.spendManaThresholdCleanseCount {
                context.talentActionGuardByActorID[cleanseKey] = context.actionCount
                var effects = context.roster.activeEffects(for: actor)
                if let removed = EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng) {
                    context.roster.setActiveEffects(effects, for: actor)
                    events.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .cleanseApplied,
                        actorName: actor.name,
                        abilityName: "Arcane Cleansing",
                        target: actor,
                        amount: 0,
                        keyword: removed
                    ))
                }
            }
        }
        let chaosRiftKey = "spend:chaosrift:\(actor.id)"
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
        let freezeKey = "spend:freeze:\(actor.id)"
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

        // Arcane Breath: Mana spent on empowering a card adds bonus damage.
        if triggers.spendManaDamageBonusPerMana > 0 {
            context.roster.mutateRuntime(for: actor) {
                $0.pendingCardDamageBonus += triggers.spendManaDamageBonusPerMana
            }
        }

        // Dark Recovery: the first time you reach 0 Mana each battle, immediately restore Mana.
        if triggers.onReachZeroManaRestoreMana > 0,
           context.roster.runtime(for: actor)?.currentMana == 0,
           context.talentActionGuardByActorID["darkrecovery:\(actor.id)"] == nil {
            context.talentActionGuardByActorID["darkrecovery:\(actor.id)"] = 1
            let restored = context.restoreMana(triggers.onReachZeroManaRestoreMana, to: actor)
            if restored > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: "Dark Recovery",
                    target: actor,
                    amount: restored,
                    keyword: .mana
                ))
                events.append(contentsOf: afterGainMana(by: actor, in: &context))
            }
        }

        // Arcane Burst: spending enough Mana draws and automatically plays a random card.
        if triggers.spendManaThresholdAutoPlayCard > 0, !context.isResolvingAutoPlayCard {
            let burstKey = "arcaneburst:\(actor.id)"
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
                        abilityName: "Life Tap",
                        keyword: .health,
                        displayAmount: triggers.onGainManaHealFlat
                    )
                ),
                in: &context
            ).events)
        }
        return events
    }

    // swiftlint:disable:next function_body_length
    static func afterLeech(
        by actor: Combatant,
        target: Combatant?,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        let triggers = profile.triggers
        var events: [ActionEvent] = []

        if triggers.leechRestoreManaFlat > 0 {
            let restored = context.restoreMana(
                context.paced(triggers.leechRestoreManaFlat, sourceActorID: actor.id),
                to: actor
            )
            if restored > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: affixName(.siphoning),
                    target: actor,
                    amount: restored,
                    keyword: .mana
                ))
                events.append(contentsOf: afterGainMana(by: actor, in: &context))
            }
        }

        if triggers.leechGoldFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.leechGoldFlat,
                to: actor,
                abilityName: affixName(.bloodPrice)
            ))
        }

        // Combatant Talent System — on-Leech reactions against the target.
        guard let target, target.role == .enemy, context.roster.health(for: target) > 0 else { return events }
        // Soul Drain: Leeching drains Mana from the target.
        if triggers.onLeechDrainMana > 0, (context.roster.runtime(for: target)?.maxMana ?? 0) > 0 {
            let drained = context.spendMana(triggers.onLeechDrainMana, for: target)
            if drained > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .resourceGain,
                    actorName: actor.name,
                    abilityName: "Soul Drain",
                    target: target,
                    amount: -drained,
                    keyword: .mana
                ))
            }
        }
        // Toxic Touch / Necrotic Bleed: Leech applies Poison / Bleed.
        if triggers.onLeechApplyPoison > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.onLeechApplyPoison,
                to: target,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true
            ))
        }
        if triggers.onLeechApplyBleed > 0 {
            events.append(contentsOf: DoTApplicator.applyBleed(
                potency: triggers.onLeechApplyBleed,
                to: target,
                sourceActorID: actor.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context
            ))
        }
        // Weaken Soul: Leech reduces the target's Strength for 2 turns.
        if triggers.onLeechReduceEnemyStrength > 0 {
            context.appendEffect(
                .strengthReduction(
                    triggers.onLeechReduceEnemyStrength,
                    triggers.onLeechReduceEnemyStrengthTurns
                ),
                to: target,
                sourceID: actor.id,
                remainingTurns: triggers.onLeechReduceEnemyStrengthTurns
            )
        }

        return events
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func afterEnemyDefeated(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        if context.roster.hero.isAlive {
            let hero = context.roster.hero.combatant
            let amount = context.heroModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(amount, to: hero, abilityName: affixName(.bounty)))
            }
        }

        if context.roster.companion.isAlive {
            let companion = context.roster.companion.combatant
            let amount = context.companionModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(amount, to: companion, abilityName: affixName(.bounty)))
            }
        }

        // Combatant Talent System defeat reactions.
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive else { continue }
            let actor = runtime.combatant
            let triggers = context.modifiers(for: actor.id).triggers

            if triggers.onDefeatEnemyExtraAction {
                let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &context)
                if drawn > 0 {
                    events.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .cardsDrawn,
                        actorName: actor.name,
                        abilityName: "Enrage",
                        target: actor,
                        amount: drawn,
                        keyword: .physical
                    ))
                }
            }
            if triggers.onDefeatEnemyGainBlock > 0 {
                events.append(contentsOf: context.applyBlock(
                    triggers.onDefeatEnemyGainBlock,
                    to: actor,
                    source: actor,
                    abilityName: "Bone Armor"
                ))
            }
            if triggers.onEnemyDefeatRestoreHealthAndBlockHealth > 0 {
                events.append(contentsOf: HealingEngine.resolveHeal(
                    HealRequest(
                        amount: triggers.onEnemyDefeatRestoreHealthAndBlockHealth,
                        target: actor,
                        sourceActorID: actor.id,
                        logAs: .instantHeal(
                            actorName: actor.name,
                            abilityName: "Grave Harvest",
                            keyword: .health,
                            displayAmount: triggers.onEnemyDefeatRestoreHealthAndBlockHealth
                        )
                    ),
                    in: &context
                ).events)
            }
            if triggers.onEnemyDefeatRestoreHealthAndBlockBlock > 0 {
                events.append(contentsOf: context.applyBlock(
                    triggers.onEnemyDefeatRestoreHealthAndBlockBlock,
                    to: actor,
                    source: actor,
                    abilityName: "Grave Harvest"
                ))
            }
            if context.lastEnemyDefeatWasCritical {
                if triggers.critOnDefeatGold > 0 {
                    events.append(contentsOf: context.grantGoldEvent(
                        triggers.critOnDefeatGold,
                        to: actor,
                        abilityName: "Bounty Hunter"
                    ))
                }
                if triggers.critOnDefeatGoldAndDrawDraw > 0 {
                    let drawn = BattleCardCombatEngine.drawCards(
                        count: triggers.critOnDefeatGoldAndDrawDraw,
                        for: owner,
                        context: &context
                    )
                    if drawn > 0 {
                        events.append(context.nextEvent(
                            kind: .effect,
                            effectKind: .cardsDrawn,
                            actorName: actor.name,
                            abilityName: "Bounty Hunter",
                            target: actor,
                            amount: drawn,
                            keyword: .physical
                        ))
                    }
                }
            }
            if triggers.onDefeatBleedingEnemyResetActionTimer,
               context.roster.activeEffects(for: context.roster.enemy.combatant).contains(where: \.effect.isBleed) {
                let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &context)
                if drawn > 0 {
                    events.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .cardsDrawn,
                        actorName: actor.name,
                        abilityName: "Draw",
                        target: actor,
                        amount: drawn,
                        keyword: .physical
                    ))
                }
            }
            // Endless Legion restores Health when Death's Door expires, not on enemy defeat.
            // Alpha Might: defeating an enemy grants the Wolf and the Hero +2 Strength.
            if triggers.onDefeatEnemyPartyStrengthBonus > 0 {
                context.roster.mutateRuntime(for: actor) {
                    $0.talentStatBonus.strength += triggers.onDefeatEnemyPartyStrengthBonus
                }
                if actor.role == .companion, context.roster.hero.isAlive {
                    context.roster.mutateRuntime(for: context.roster.hero.combatant) {
                        $0.talentStatBonus.strength += triggers.onDefeatEnemyPartyStrengthBonus
                    }
                }
            }
        }

        return events
    }

    static func shareHeroLeechWithCompanion(
        restored: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = min(max(context.heroModifiers.triggers.companionLeechSharePercent, 0), 1)
        guard restored > 0,
              percent > 0,
              context.roster.companion.isAlive
        else { return [] }
        let share = max(1, CombatRounding.scaled(restored, multiplier: percent))
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: share,
                target: context.roster.companion.combatant,
                sourceActorID: context.roster.hero.id,
                logAs: .instantHeal(
                    actorName: context.roster.hero.name,
                    abilityName: affixName(.symbiosis),
                    keyword: .health,
                    displayAmount: share
                )
            ),
            in: &context
        ).events
    }

    static func healAfterCleanse(
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.cleanseBonusHeal,
            source: source,
            target: target,
            in: &context
        )
    }

    static func healWearerAfterCleanse(
        source: Combatant,
        in context: inout BattleState
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.cleanseSelfHeal,
            source: source,
            target: source,
            in: &context
        )
    }

    static func drawAfterCleanse(
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let count = context.modifiers(for: source.id).triggers.cleanseBonusDraw
        guard count > 0 else { return [] }
        guard let owner = context.roster.participant(for: source), owner.isPartyMember else {
            return []
        }
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: source.name,
            abilityName: traitName(for: source, in: context),
            target: source,
            amount: drawn,
            keyword: .physical
        )]
    }

    static func healSelfAfterGoldGain(
        source: Combatant,
        in context: inout BattleState
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.gainGoldBonusHealSelf,
            source: source,
            target: source,
            in: &context
        )
    }

    private static func resolveBonusHeal(
        amount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> CombatOutcome {
        guard amount > 0 else { return .empty }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: traitName(for: source, in: context),
                    keyword: .health,
                    displayAmount: amount
                )
            ),
            in: &context
        )
    }
}

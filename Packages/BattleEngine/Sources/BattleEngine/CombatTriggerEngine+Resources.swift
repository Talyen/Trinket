import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterSpendMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        var events: [ActionEvent] = []
        events.append(contentsOf: drawAfterSpendMana(by: actor, in: &context))

        if profile.triggers.spendManaBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                profile.triggers.spendManaBlockFlat,
                to: actor,
                source: actor,
                abilityName: affixName(.aetherward)
            ))
        }

        let randomDoT = profile.triggers.spendManaRandomDoTFlat
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
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: randomDoT,
                        target: enemy,
                        keyword: .freeze,
                        sourceActorID: actor.id,
                        options: DamageOptions(
                            applyStatBonus: false,
                            applyItemBonus: true,
                            applyDodge: false,
                            isRetaliation: true
                        )
                    )
                ).events)
            }
        }

        return events
    }

    static func afterGainMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let amount = context.modifiers(for: actor.id).triggers.gainManaBlockFlat
        guard amount > 0 else { return [] }
        return context.applyBlock(
            amount,
            to: actor,
            source: actor,
            abilityName: affixName(.arcaneWard)
        )
    }

    static func afterLeech(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        var events: [ActionEvent] = []

        if profile.triggers.leechRestoreManaFlat > 0 {
            let restored = context.restoreMana(
                context.paced(profile.triggers.leechRestoreManaFlat, sourceActorID: actor.id),
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

        if profile.triggers.leechGoldFlat > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                profile.triggers.leechGoldFlat,
                to: actor,
                abilityName: affixName(.bloodPrice)
            ))
        }

        return events
    }

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

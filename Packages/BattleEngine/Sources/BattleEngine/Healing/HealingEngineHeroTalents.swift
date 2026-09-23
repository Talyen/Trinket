import TrinketContent
import TrinketCore

extension HealingEngine {
    static func adjustedHeroHealingAmount(
        _ baseAmount: Int,
        request: HealRequest,
        in context: BattleState,
    ) -> Int {
        var amount = baseAmount
        if amount > 0, request.amountBasis != .resolved,
           request.target.role != .enemy, context.roster.hero.isAlive {
            let hero = context.heroModifiers.triggers
            if hero.fortifyingTonic,
               context.roster.health(for: request.target) * 2 < context.roster.maxHealth(for: request.target) {
                amount += 2
            }
            if hero.springSapHealthBonus > 0,
               context.roster.activeEffects(for: request.target).contains(where: { $0.effect.kind == .thorns }) {
                amount += hero.springSapHealthBonus
            }
        }
        var enemyMultiplier = 1.0
        if request.target.role == .enemy, context.roster.hero.isAlive {
            let hero = context.heroModifiers.triggers
            if context.roster.hasAffliction(.bleed, on: request.target) {
                enemyMultiplier *= hero.bleedingEnemyHealingMultiplier
            }
            if context.roster.hasAffliction(.burn, on: request.target) {
                enemyMultiplier *= hero.burningEnemyHealingMultiplier
            }
        }
        return CombatRounding.scaled(amount, multiplier: enemyMultiplier)
    }

    static func applyHeroHealingTalents(
        request: HealRequest,
        restored: Int,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events = applyAlchemistHealingTalents(
            request: request, restored: restored, sourceTriggers: sourceTriggers, in: &context,
        )
        events.append(contentsOf: applyDruidHealingTalents(
            request: request, restored: restored, sourceTriggers: sourceTriggers, in: &context,
        ))
        return events
    }

    private static func applyDruidHealingTalents(
        request: HealRequest,
        restored: Int,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard restored > 0, context.allowsHeroTalentReaction,
              let sourceActorID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID)?.combatant,
              context.roster.health(for: source) > 0,
              request.target.role != .enemy,
              let sourceTriggers
        else { return [] }
        var events: [ActionEvent] = []
        if sourceTriggers.pruningHealthRemoveEnemyThorns > 0 {
            for _ in 0 ..< sourceTriggers.pruningHealthRemoveEnemyThorns {
                context.removeTalentPoint(.thorns, from: context.roster.enemy.combatant)
            }
        }
        if sourceTriggers.cleansingDew, context.roster.hasAffliction(.poison, on: request.target) {
            events.append(contentsOf: CleanseOperation.resolve(
                .all(.poison), source: source, target: request.target,
                abilityName: "Cleansing Dew", in: &context,
            ).events)
        }
        if request.target.role == .companion, sourceTriggers.sharedRootsHealPercent > 0,
           context.roster.hero.isAlive {
            let amount = CombatRounding.scaled(restored, multiplier: sourceTriggers.sharedRootsHealPercent)
            if amount > 0 {
                events.append(contentsOf: CombatTriggerEngine.withHeroReaction(in: &context) { context in
                    context.healEmitting(
                        amount: amount,
                        target: context.roster.hero.combatant,
                        source: source,
                        abilityName: "Shared Roots",
                    )
                })
            }
        }
        return events
    }

    private static func applyAlchemistHealingTalents(
        request: HealRequest,
        restored: Int,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let sourceActorID = request.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID)?.combatant,
              context.roster.health(for: source) > 0,
              request.target.role != .enemy,
              let sourceTriggers
        else { return [] }
        var events: [ActionEvent] = []
        if restored > 0 {
            if sourceTriggers.healthRestoreNextPoisonBonus > 0 {
                context.roster.mutateRuntime(for: source) {
                    $0.talents.pending.nextPoisonDamageBonus = max(
                        $0.talents.pending.nextPoisonDamageBonus,
                        sourceTriggers.healthRestoreNextPoisonBonus,
                    )
                }
            }
            let canRoll: Bool = if let card = context.resolution.cardTalents,
                                   card.actorID == sourceActorID {
                context.resolution.claim(
                    .heroCard("alchemistHealChance"),
                    actorID: sourceActorID,
                    cadence: .card(card.playSerial),
                )
            } else {
                true
            }
            if canRoll, sourceTriggers.healthRestoreDrawChancePercent > 0,
               BattleChance.succeeds(probability: sourceTriggers.healthRestoreDrawChancePercent, using: &context.rng),
               let owner = context.roster.participant(for: source) {
                events.append(contentsOf: CombatTriggerEngine.drawCards(
                    1, for: owner, actor: source, abilityName: "Lifeline", in: &context,
                ))
            }
            if canRoll, sourceTriggers.healthRestoreManaChancePercent > 0,
               BattleChance.succeeds(probability: sourceTriggers.healthRestoreManaChancePercent, using: &context.rng) {
                events.append(contentsOf: context.restoreManaEmitting(
                    1, to: source, abilityName: "Masterwork Mixture",
                ))
            }
            if sourceTriggers.coolingSalve, context.roster.hasAffliction(.burn, on: request.target) {
                events.append(contentsOf: CleanseOperation.resolve(
                    .all(.burn), source: source, target: request.target,
                    abilityName: "Cooling Salve", in: &context,
                ).events)
            }
        }
        if request.isDirectCardHeal, sourceTriggers.clearSolution,
           context.claimHeroCardBonus("Clear Solution", actorID: sourceActorID) {
            events.append(contentsOf: CombatTriggerEngine.performRandomCleanses(
                source: source, target: request.target, count: 1,
                abilityName: "Clear Solution", in: &context,
            ))
        }
        return events
    }

    static func applyFullHealthBonus(
        preHealth: Int,
        maxHealth: Int,
        request: HealRequest,
        targetTriggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        if targetTriggers.nextAttackBonusOnFullHealth > 0,
           preHealth < maxHealth,
           context.roster.health(for: request.target) >= maxHealth {
            context.roster.mutateRuntime(for: request.target) {
                $0.talents.pending.attackBonusOnFullHealth += targetTriggers.nextAttackBonusOnFullHealth
            }
        }
    }

    static func applyShelterSeed(
        preHealth: Int,
        maxHealth: Int,
        restored: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if restored > 0, preHealth * 2 < maxHealth, request.target.role != .enemy,
           let block = sourceTriggers?.shelterSeedBlock, block > 0,
           let sourceID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceID), source.isAlive {
            context.applyBlock(
                block,
                to: request.target,
                source: source.combatant,
                abilityName: "Shelter Seed",
            )
        } else {
            []
        }
    }
}

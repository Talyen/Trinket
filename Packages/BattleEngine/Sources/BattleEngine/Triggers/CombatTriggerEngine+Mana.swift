import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func drawOppositeElement(
        afterEmpowering keyword: Keyword,
        by actor: Combatant,
        in context: inout BattleState,
    ) {
        guard context.modifiers(for: actor.id).triggers.empoweredElementDrawOpposite,
              let owner = context.roster.participant(for: actor),
              owner.isPartyMember
        else { return }
        let opposite: Keyword = keyword == .burn ? .freeze : .burn
        guard BattleCardCombatEngine.drawFirstCard(
            matching: opposite,
            for: owner,
            context: &context,
        ) != nil else { return }
        context.nextEvent(
            kind: .effect(.cardsDrawn),
            source: .init(actor),
            abilityName: triggerAbilityName(
                .empoweredElementDrawOpposite,
                for: actor,
                fallback: "Twin Casting",
                in: context,
            ),
            target: actor,
            amount: 1,
            keyword: .physical,
        )
    }

    internal static func afterSpendMana(_ payment: ManaPayment, in context: inout BattleState) async {
        guard let actor = context.roster.combatant(for: payment.payerID)?.combatant else { return }
        let amountSpent = payment.amountSpent
        let spentLastMana = payment.spentLastMana
        let triggers = context.modifiers(for: actor.id).triggers
        if spentLastMana, triggers.lastManaNextBurnPercent > 0 {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            let preparedActionID = context.resolution.actionID
            context.roster.mutateRuntime(for: actor) {
                $0.talents.pending.nextBurnAttackPercent = PreparedTalentBonus(
                    value: max($0.talents.pending.nextBurnAttackPercent?.value ?? 0, triggers.lastManaNextBurnPercent),
                    cardSerial: preparedCardSerial,
                    actionID: preparedActionID,
                )
            }
        }
        await CombatCheckpoint.payment(payment).resolve([
            { await afterHeroTalentSpendMana(actor: actor, amount: amountSpent, in: &$0) },
            { drawAfterSpendMana(by: actor, in: &$0) },
            { drawOnManaSpendChance(actor: actor, triggers: triggers, amountSpent: amountSpent, in: &$0) },
            { spendManaBlockIfNeeded(actor: actor, triggers: triggers, in: &$0) },
            { heroSpendManaCompanionIfNeeded(actor: actor, in: &$0) },
            { await spendManaRefundIfNeeded(actor: actor, triggers: triggers, amountSpent: amountSpent, in: &$0) },
            { await spendManaBurnIfNeeded(actor: actor, triggers: triggers, in: &$0) },
            { await heroSpendManaAfflictionIfNeeded(actor: actor, triggers: triggers, in: &$0) },
            { spendManaEqualBlockIfNeeded(actor: actor, triggers: triggers, amountSpent: amountSpent, in: &$0) },
            { spendManaOverchargeIfNeeded(actor: actor, triggers: triggers, amountSpent: amountSpent, in: &$0) },
            { spendManaCleanseIfNeeded(actor: actor, triggers: triggers, amountSpent: amountSpent, in: &$0) },
            {
                await spendManaChaosRiftIfNeeded(payment: payment, actor: actor, triggers: triggers, amountSpent: amountSpent, in: &$0)
            },
            { spendManaDamageBonusIfNeeded(actor: actor, triggers: triggers, amountSpent: amountSpent, in: &$0) },
            { await zeroManaRestoreIfNeeded(actor: actor, triggers: triggers, spentLastMana: spentLastMana, in: &$0) },
            { drawOnLastManaIfNeeded(actor: actor, triggers: triggers, spentLastMana: spentLastMana, in: &$0) },
            {
                await spendManaStunIfNeeded(
                    actor: actor,
                    triggers: triggers,
                    amountSpent: amountSpent,
                    spentLastMana: spentLastMana,
                    in: &$0,
                )
            },
            { await autoPlayAfterManaSpend(by: actor, amountSpent: amountSpent, in: &$0) },
            { await spendManaRandomDoTIfNeeded(actor: actor, triggers: triggers, in: &$0) },
            { await afterFinalCompanionManaSpend(actor: actor, amountSpent: amountSpent, in: &$0) },
        ], in: &context)
    }

    private static func drawOnLastManaIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        spentLastMana: Bool,
        in context: inout BattleState,
    ) {
        guard triggers.spendLastManaDrawCard, spentLastMana,
              context.claimTalentAbility(.arcaneSurge, actorID: actor.id),
              let owner = context.roster.participant(for: actor)
        else { return }
        drawCards(1, for: owner, actor: actor, abilityName: "Arcane Surge", in: &context)
    }

    private static func spendManaBlockIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard triggers.spendManaBlockFlat > 0 else { return }
        emitBlock(.spendManaBlockFlat, "Aetherward", amount: triggers.spendManaBlockFlat, to: actor, source: actor, in: &context)
    }

    private static func heroSpendManaCompanionIfNeeded(
        actor: Combatant,
        in context: inout BattleState,
    ) {
        guard actor.role == .hero, let companionTriggers = companionReactingToHeroTriggers(in: context) else {
            return
        }
        if companionTriggers.onHeroSpendManaGainBlock > 0 {
            context.applyBlockGain(
                companionTriggers.onHeroSpendManaGainBlock,
                to: context.roster.companion.combatant,
                source: actor,
                abilityName: triggerAbilityName(
                    .onHeroSpendManaGainBlock,
                    for: context.roster.companion.combatant,
                    fallback: "Mana Absorption",
                    in: context,
                ),
            )
        }
        if companionTriggers.onHeroSpendManaCompanionNextAttackBonus > 0,
           context.roster.health(for: actor) > 0, context.roster.companion.isAlive {
            context.roster.mutateRuntime(for: context.roster.companion.combatant) {
                $0.talents.pending.cardDamageBonus = SaturatedArithmetic.saturatingAdd(
                    $0.talents.pending.cardDamageBonus, companionTriggers.onHeroSpendManaCompanionNextAttackBonus,
                )
            }
        }
    }

    private static func spendManaRefundIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        in context: inout BattleState,
    ) async {
        guard amountSpent > 0, triggers.spendManaRefundChancePercent > 0,
              context.claimTalentAbility(.manaFlow, actorID: actor.id),
              BattleChance.succeeds(probability: triggers.spendManaRefundChancePercent, using: &context.rng) else {
            return
        }
        await emitMana(.spendManaRefundChancePercent, "Mana Flow", amount: amountSpent, to: actor, in: &context)
    }

    private static func drawOnManaSpendChance(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        in context: inout BattleState,
    ) {
        guard amountSpent > 0, triggers.spendManaDrawChancePercent > 0,
              context.claimTalentAbility(.dragonSpark, actorID: actor.id),
              BattleChance.succeeds(probability: triggers.spendManaDrawChancePercent, using: &context.rng),
              let owner = context.roster.participant(for: actor)
        else { return }
        drawCards(1, for: owner, actor: actor, abilityName: "Dragon Spark", in: &context)
    }

    private static func spendManaBurnIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard triggers.onSpendManaBurnBurningEnemies > 0, context.roster.enemy.isAlive,
              context.roster.hasAffliction(.burn, on: context.enemy) else { return }
        await DoTApplicator.applyDoT(
            keyword: .burn,
            potency: triggers.onSpendManaBurnBurningEnemies,
            to: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            in: &context,
        )
    }

    private static func heroSpendManaAfflictionIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard actor.role == .hero, triggers.onHeroSpendManaApplyRandomAffliction,
              context.roster.enemy.isAlive else { return }
        let keywords: [Keyword] = [.bleed, .burn, .poison]
        let keyword = keywords.randomElement(using: &context.rng) ?? .burn
        await DoTApplicator.applyDoT(
            keyword: keyword,
            potency: 1,
            to: context.roster.enemy.combatant,
            sourceActorID: actor.id,
            application: .reaction,
            in: &context,
        )
    }

    private static func spendManaEqualBlockIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        in context: inout BattleState,
    ) {
        guard triggers.spendManaGrantsEqualBlock, amountSpent > 0 else { return }
        context.applyBlockGain(amountSpent, to: actor, source: actor, abilityName: "Mana Cocoon")
    }

    private static func spendManaOverchargeIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        in context: inout BattleState,
    ) {
        let overchargeMet = triggers.spendManaEmpowerNextCardThreshold > 0
            && amountSpent >= triggers.spendManaEmpowerNextCardThreshold
        guard overchargeMet, context.claimActionGuard(.spendOvercharge, actorID: actor.id),
              triggers.nextCardEmpowerPercent > 0 else { return }
        context.roster.mutateRuntime(for: actor) {
            $0.talents.pending.cardDamagePercent += triggers.nextCardEmpowerPercent
        }
    }

    private static func spendManaCleanseIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        in context: inout BattleState,
    ) {
        guard triggers.spendManaRemovesAfflictions, amountSpent > 0 else { return }
        let keywords = [Keyword.burn, .poison].filter { keyword in
            context.roster.activeEffects(for: actor).contains { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }
        }
        if let keyword = keywords.randomElement(using: &context.rng) {
            _ = DoTApplicator.consume(keyword, upTo: amountSpent, on: actor, in: &context)
        }
    }

    private static func spendManaChaosRiftIfNeeded(
        payment: ManaPayment,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        in context: inout BattleState,
    ) async {
        guard triggers.spendManaRandomElementDamage, amountSpent > 0, context.roster.enemy.isAlive else {
            return
        }
        let keywords = [Keyword.freeze, .burn, .poison, .holy].shuffled(using: &context.rng)
        let amounts = [amountSpent / 2 + amountSpent % 2, amountSpent / 2]
        for (keyword, amount) in zip(keywords.prefix(2), amounts) where amount > 0 {
            guard CombatCheckpoint.payment(payment).allowsContinuation(in: context) else { break }
            _ = await context.dealReactionDamage(amount, to: context.roster.enemy.combatant, keyword: keyword, sourceActorID: actor.id)
        }
    }

    private static func spendManaDamageBonusIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        in context: inout BattleState,
    ) {
        guard triggers.spendManaDamageBonusPerMana > 0,
              amountSpent >= BattleTurnEngine.manaEmpowermentCost else { return }
        context.roster.mutateRuntime(for: actor) {
            $0.talents.pending.cardDamageBonus = SaturatedArithmetic.saturatingAdd(
                $0.talents.pending.cardDamageBonus,
                SaturatedArithmetic.saturatingMul(amountSpent, triggers.spendManaDamageBonusPerMana),
            )
        }
    }

    private static func zeroManaRestoreIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        spentLastMana: Bool,
        in context: inout BattleState,
    ) async {
        guard triggers.onReachZeroManaRestoreMana > 0,
              spentLastMana,
              context.claimBattleGuard(.darkRecovery, actorID: actor.id) else { return }
        await emitMana(.onReachZeroManaRestoreMana, "Dark Recovery", amount: triggers.onReachZeroManaRestoreMana, to: actor, in: &context)
    }

    private static func spendManaStunIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        amountSpent: Int,
        spentLastMana: Bool,
        in context: inout BattleState,
    ) async {
        if triggers.closedCircuit, amountSpent > 0 {
            await spendManaStunDamage(amount: amountSpent, actor: actor, in: &context)
        }
        if triggers.spendLastManaStunDamage > 0, spentLastMana {
            await spendManaStunDamage(amount: triggers.spendLastManaStunDamage, actor: actor, in: &context)
        }
    }

    private static func spendManaStunDamage(
        amount: Int,
        actor: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.roster.enemy.isAlive else { return }
        _ = await context.dealReactionDamage(amount, to: context.roster.enemy.combatant, keyword: .stun, sourceActorID: actor.id)
    }

    private static func spendManaRandomDoTIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        let randomDoT = triggers.spendManaRandomDoTFlat
        guard randomDoT > 0, context.roster.enemy.isAlive else { return }
        let enemy = context.roster.enemy.combatant
        if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
            await context.applyDecayingDoT(keyword: .burn, potency: randomDoT, to: enemy, sourceActorID: actor.id, application: .ability)
            return
        }
        _ = await context.dealReactionDamage(randomDoT, to: enemy, keyword: .freeze, sourceActorID: actor.id)
    }

    private static func autoPlayAfterManaSpend(
        by actor: Combatant,
        amountSpent: Int,
        in context: inout BattleState,
    ) async {
        let threshold = context.modifiers(for: actor.id).triggers.spendManaThresholdAutoPlayCard
        guard threshold > 0, amountSpent > 0, !context.resolution.isAutomaticPlay else { return }
        // Keep the exact remainder without constructing an overflowing lifetime total.
        let previous = context.roster.runtime(for: actor)?.talents.battle.manaSpentTowardAutoPlay ?? 0
        let remainder = amountSpent % threshold
        let crossesThreshold = remainder >= threshold - previous
        let remaining = crossesThreshold ? remainder - (threshold - previous) : previous + remainder
        let automaticPlays = amountSpent / threshold + (crossesThreshold ? 1 : 0)
        context.roster.mutateRuntime(for: actor) { $0.talents.battle.manaSpentTowardAutoPlay = remaining }
        guard automaticPlays > 0 else { return }
        await context.withAutomaticPlay { context in
            for _ in 0 ..< automaticPlays {
                guard context.roster.health(for: actor) > 0, !context.isBattleOver else { break }
                _ = await DrawAndPlayCardsHandler().apply(
                    .drawAndPlayCards(1),
                    ability: Ability(id: "arcane-burst", name: "Arcane Burst", tier: .basic),
                    source: actor,
                    target: actor,
                    in: &context,
                )
            }
        }
    }

    static func cardsPlayedManaIfNeeded(
        count: Int,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard triggers.cardsPlayedManaThreshold > 0, triggers.cardsPlayedManaFlat > 0,
              count == triggers.cardsPlayedManaThreshold else { return }
        await emitMana(.cardsPlayedManaThreshold, "Resonant Chimes", amount: triggers.cardsPlayedManaFlat, to: actor, in: &context)
    }

    static func afterGainMana(by actor: Combatant, in context: inout BattleState) async {
        let triggers = context.modifiers(for: actor.id).triggers

        HealingEngine.drawOwlFontOfMagic(actor: actor, chance: triggers.healthOrManaRestoreDrawChancePercent, in: &context)
        drawOnFinalCompanionManaRestoration(actor: actor, in: &context)
        let amount = triggers.gainManaBlockFlat
        if amount > 0 {
            emitBlock(.gainManaBlockFlat, "Arcane Ward", amount: amount, to: actor, source: actor, in: &context)
        }
        if triggers.onGainManaHealFlat > 0 {
            await emitHeal(.onGainManaHealFlat, "Life Tap", amount: triggers.onGainManaHealFlat, to: actor, source: actor, in: &context)
        }
    }

    /// Direct gains and Mana Shield reactions run gain consequences before
    /// consuming overflow; other restoration paths deliberately keep their order.
    static func manaRestorationReactions(
        for actor: Combatant,
        restored: Int,
        in context: inout BattleState,
    ) async {
        if restored > 0 {
            await afterGainMana(by: actor, in: &context)
        }
        await consumeManaOverflowTalents(for: actor, restoredMana: restored > 0, in: &context)
    }

    static func consumeManaOverflowTalents(
        for actor: Combatant,
        restoredMana: Bool,
        in context: inout BattleState,
    ) async {
        let overflow = context.roster.runtime(for: actor)?.talents.pending.manaOverflowThorns ?? 0
        let block = context.roster.runtime(for: actor)?.talents.pending.manaOverflowBlock ?? 0
        let arcane = restoredMana ? context.modifiers(for: actor.id).triggers.arcaneThornsOnManaRestore : 0
        let amount = SaturatedArithmetic.saturatingAdd(overflow, arcane)
        guard amount > 0 || block > 0 else { return }
        context.roster.mutateRuntime(for: actor) {
            $0.talents.pending.manaOverflowThorns = 0
            $0.talents.pending.manaOverflowBlock = 0
        }

        if amount > 0 {
            await heroTalentThorns(
                to: actor, source: actor, amount: amount,
                name: overflow > 0 ? "Living Conduit" : "Arcane Thorns", in: &context,
            )
        }
        if block > 0 {
            context.applyBlockGain(block, to: actor, source: actor, abilityName: "Mana Absorption", amountBasis: .resolved)
        }
    }
}

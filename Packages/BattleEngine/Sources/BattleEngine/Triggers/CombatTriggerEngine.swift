import TrinketContent
import TrinketCore

package enum CombatTriggerEngine {
    static func triggerAbilityName(
        _ key: CombatTriggerField,
        for combatant: Combatant,
        fallback: String,
        in context: BattleState,
    ) -> String {
        context.modifiers(for: combatant.id).triggerAbilityName(key, fallback: fallback)
    }

    /// Living party runtimes with their participants, for fan-out reactions.
    /// Prefer this over hand-rolled hero/companion loops with alive guards.
    static func livingPartyMembers(in context: BattleState) -> [(
        owner: BattleParticipant,
        member: CombatantRuntime,
    )] {
        var result: [(owner: BattleParticipant, member: CombatantRuntime)] = []
        result.reserveCapacity(2)
        if context.roster.hero.isAlive {
            result.append((.hero, context.roster.hero))
        }
        if context.roster.companion.isAlive {
            result.append((.companion, context.roster.companion))
        }
        return result
    }

    static func livingAllies(
        in context: BattleState,
    ) -> [(combatant: Combatant, profile: CombatModifierProfile)] {
        var result: [(combatant: Combatant, profile: CombatModifierProfile)] = []
        result.reserveCapacity(2)
        if context.roster.hero.isAlive {
            result.append((context.roster.hero.combatant, context.heroModifiers))
        }
        if context.roster.companion.isAlive {
            result.append((context.roster.companion.combatant, context.companionModifiers))
        }
        return result
    }

    static func forEachLivingAllyModifier(in context: BattleState, _ body: (CombatModifierProfile) throws -> Void) rethrows {
        if context.roster.hero.isAlive {
            try body(context.heroModifiers)
        }
        if context.roster.companion.isAlive {
            try body(context.companionModifiers)
        }
    }

    static func hasLivingPartyTrigger(_ keyPath: KeyPath<CombatTraitTriggers, Bool>, in context: BattleState) -> Bool {
        (context.roster.hero.isAlive && context.heroModifiers.triggers[keyPath: keyPath])
            || (context.roster.companion.isAlive && context.companionModifiers.triggers[keyPath: keyPath])
    }

    static func frozenTargetCannotBlockOrHeal(_ target: Combatant, in context: BattleState) -> Bool {
        guard target.role == .enemy else { return false }
        guard context.roster.hasControlStatus(for: target, keyword: .freeze) else { return false }
        return hasLivingPartyTrigger(\.frozenEnemyCannotBlockOrHeal, in: context)
    }

    static func incomingHealMultiplier(for target: Combatant, in context: BattleState) -> Double {
        var multiplier = burnAuraHealMultiplier(for: target, in: context)
        let affliction = context.roster.activeEffects(for: target).lazy.compactMap { active -> Double? in
            guard case let .healingReductionPercent(percent, _) = active.effect else { return nil }
            return percent
        }.max() ?? 0
        multiplier *= max(0, 1 - min(1, affliction))
        return multiplier
    }

    private static func burnAuraHealMultiplier(for target: Combatant, in context: BattleState) -> Double {
        guard target.role == .enemy else { return 1 }
        let isBurning = context.roster.hasAffliction(.burn, on: target)
        guard isBurning else { return 1 }
        var reduction = 0.0
        forEachLivingAllyModifier(in: context) { reduction += $0.triggers.burnReducesEnemyHealingAndLeechPercent }
        return max(0, 1 - min(1, reduction))
    }

    static func partyDebuffsExpireFaster(in context: BattleState) -> Bool {
        hasLivingPartyTrigger(\.partyDebuffDurationHalved, in: context)
    }

    static func companionReactingToHeroTriggers(in context: BattleState) -> CombatTraitTriggers? {
        guard context.roster.companion.isAlive else { return nil }
        return context.companionModifiers.triggers
    }

    /// Runs `perform` inside the hero-reaction scope shared by reward emitters.
    static func withHeroReaction(
        in context: inout BattleState,
        perform: (inout BattleState) async -> Void,
    ) async {
        context.resolution.enter(.heroReaction)
        defer { context.resolution.leave(.heroReaction) }
        await perform(&context)
    }

    static func resolveBonusHeal(
        amount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> CombatOutcome {
        guard amount > 0 else { return .empty }
        return await HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    source: .init(source),
                    abilityName: "Trait",
                    keyword: .health,
                ),
            ),
            in: &context,
        )
    }

    /// Reward emitters fold the trigger-name lookup into the reward call so
    /// trigger sites stay one statement. `source` names the trigger that fired;
    /// for mana the naming actor can differ from the recipient via `nameFrom`.
    static func emitDraw(
        _ key: CombatTriggerField,
        _ fallback: String,
        count: Int,
        for owner: BattleParticipant,
        actor: Combatant,
        in context: inout BattleState,
    ) {
        drawCards(
            count, for: owner, actor: actor,
            abilityName: triggerAbilityName(key, for: actor, fallback: fallback, in: context),
            in: &context,
        )
    }

    static func emitBlock(
        _ key: CombatTriggerField,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) {
        context.applyBlockGain(
            amount,
            to: target,
            source: source,
            abilityName: triggerAbilityName(key, for: source, fallback: fallback, in: context),
        )
    }

    static func emitHeal(
        _ key: CombatTriggerField,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) async {
        await context.healEmitting(
            amount: amount,
            target: target,
            source: source,
            abilityName: triggerAbilityName(key, for: source, fallback: fallback, in: context),
        )
    }

    static func emitMana(
        _ key: CombatTriggerField,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        nameFrom: Combatant? = nil,
        in context: inout BattleState,
    ) async {
        let source = nameFrom ?? target
        await context.restoreManaEmitting(
            amount,
            to: target,
            abilityName: triggerAbilityName(key, for: source, fallback: fallback, in: context),
            source: source,
        )
    }

    static func emitGold(
        _ key: CombatTriggerField,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        in context: inout BattleState,
    ) async {
        await context.grantGold(
            amount,
            to: target,
            abilityName: triggerAbilityName(key, for: target, fallback: fallback, in: context),
        )
    }
}

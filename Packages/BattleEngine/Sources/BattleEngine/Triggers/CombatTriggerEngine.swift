import TrinketContent
import TrinketCore

package enum CombatTriggerEngine {
    static func triggerAbilityName(
        _ key: String,
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
        [BattleParticipant.hero, .companion].compactMap { owner in
            let member = context.roster[owner]
            return member.isAlive ? (owner, member) : nil
        }
    }

    static func livingAllies(
        in context: BattleState,
    ) -> [(combatant: Combatant, profile: CombatModifierProfile)] {
        var allies: [(combatant: Combatant, profile: CombatModifierProfile)] = []
        if context.roster.hero.isAlive {
            allies.append((context.roster.hero.combatant, context.heroModifiers))
        }
        if context.roster.companion.isAlive {
            allies.append((context.roster.companion.combatant, context.companionModifiers))
        }
        return allies
    }

    static func livingAllyModifiers(in context: BattleState) -> [CombatModifierProfile] {
        livingAllies(in: context).map(\.profile)
    }

    static func livingPartyTriggers(in context: BattleState) -> CombatTraitTriggers {
        livingAllyModifiers(in: context).reduce(into: CombatTraitTriggers()) { merged, profile in
            merged.merge(profile.triggers)
        }
    }

    static func hasLivingPartyTrigger(_ keyPath: KeyPath<CombatTraitTriggers, Bool>, in context: BattleState) -> Bool {
        livingAllies(in: context).contains { $0.profile.triggers[keyPath: keyPath] }
    }

    static func frozenTargetCannotBlockOrHeal(_ target: Combatant, in context: BattleState) -> Bool {
        guard target.role == .enemy else { return false }
        guard context.roster.hasControlStatus(for: target, keyword: .freeze) else { return false }
        return hasLivingPartyTrigger(\.frozenEnemyCannotBlockOrHeal, in: context)
    }

    static func incomingHealMultiplier(for target: Combatant, in context: BattleState) -> Double {
        var multiplier = burnAuraHealMultiplier(for: target, in: context)
        let affliction = context.roster.activeEffects(for: target).compactMap { active -> Double? in
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
        let reduction = livingAllies(in: context)
            .reduce(0.0) { $0 + $1.profile.triggers.burnReducesEnemyHealingAndLeechPercent }
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
        perform: (inout BattleState) -> [ActionEvent],
    ) -> [ActionEvent] {
        context.resolution.enter(.heroReaction)
        defer { context.resolution.leave(.heroReaction) }
        return perform(&context)
    }

    static func resolveBonusHeal(
        amount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> CombatOutcome {
        guard amount > 0 else { return .empty }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
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
    static func emitBlock(
        _ key: String,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        context.applyBlock(
            amount,
            to: target,
            source: source,
            abilityName: triggerAbilityName(key, for: source, fallback: fallback, in: context),
        )
    }

    static func emitHeal(
        _ key: String,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        context.healEmitting(
            amount: amount,
            target: target,
            source: source,
            abilityName: triggerAbilityName(key, for: source, fallback: fallback, in: context),
        )
    }

    static func emitMana(
        _ key: String,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        nameFrom: Combatant? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let source = nameFrom ?? target
        return context.restoreManaEmitting(
            amount,
            to: target,
            abilityName: triggerAbilityName(key, for: source, fallback: fallback, in: context),
        )
    }

    static func emitGold(
        _ key: String,
        _ fallback: String,
        amount: Int,
        to target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        context.grantGoldEvent(
            amount,
            to: target,
            abilityName: triggerAbilityName(key, for: target, fallback: fallback, in: context),
        )
    }

    static func withDoTRecursionScope(
        site: String,
        context: inout BattleState,
        perform: (inout BattleState) -> [ActionEvent],
    ) -> [ActionEvent] {
        guard context.resolution.depth(.dot) < ReactionScope.maxDepth else {
            ReactionScope.capHit(site: site, depth: context.resolution.depth(.dot))
            return []
        }
        context.resolution.enter(.dot)
        defer { context.resolution.leave(.dot) }
        return perform(&context)
    }
}

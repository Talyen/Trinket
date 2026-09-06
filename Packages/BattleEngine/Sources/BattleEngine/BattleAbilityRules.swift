import TrinketContent
import TrinketCore

enum BattleAbilityRules {
    static func canPayHealthCost(_ ability: Ability, actor: Combatant, in context: BattleState) -> Bool {
        let componentSets = ability.outcomeBranches?.map(\.damageComponents) ?? [ability.damageComponents]
        let abilityTarget = BattleTargetResolver.abilityTarget(for: actor, in: context)
        let cost = componentSets.map { components in
            components.reduce(0) { total, component in
                let target = BattleTargetResolver.effectTarget(
                    component.target, actor: actor, abilityTarget: abilityTarget, in: context,
                )
                guard target.id == actor.id else { return total }
                var amount = component.amount
                if let condition = component.condition {
                    if BattleConditionEvaluator.isMet(condition, actor: actor, in: context) {
                        amount += component.bonusAmount
                    } else if component.bonusAmount == 0 {
                        return total
                    }
                }
                return total + max(0, amount)
            }
        }.max() ?? 0
        return context.roster.health(for: actor) > cost
    }

    static func resolveOutcome(_ ability: Ability, actor: Combatant, in context: inout BattleState) -> Ability {
        guard let branches = ability.outcomeBranches else { return ability }
        let eligible = branches.compactMap { branch -> AbilityOutcomeBranch? in
            guard let resource = branch.restorationResource else { return branch }
            guard let target = restorationTarget(resource, actor: actor, in: context) else { return nil }
            return AbilityOutcomeBranch(
                damageComponents: branch.damageComponents,
                targetedEffects: branch.targetedEffects.map {
                    TargetedEffect($0.effect, target: target, condition: $0.condition)
                },
                randomizeDamageKeywords: branch.randomizeDamageKeywords,
            )
        }
        guard let selected = eligible.randomElement(using: &context.rng) else { return ability }
        return ability.resolving(branch: selected, using: &context.rng)
    }

    private static func restorationTarget(
        _ resource: AbilityOutcomeBranch.RestorationResource,
        actor: Combatant,
        in context: BattleState,
    ) -> EffectTarget? {
        let owners: [BattleParticipant] = actor.role == .enemy ? [.enemy] : [.hero, .companion]
        let candidates = owners.filter { owner in
            let runtime = context.roster[owner]
            guard runtime.isAlive else { return false }
            switch resource {
            case .health:
                return runtime.currentHealth < runtime.maxHealth
                    && !CombatTriggerEngine.frozenTargetCannotBlockOrHeal(runtime.combatant, in: context)
            case .mana:
                return runtime.currentMana < runtime.maxMana
            }
        }
        let lowest = candidates.min { left, right in
            switch resource {
            case .health: context.roster[left].currentHealth < context.roster[right].currentHealth
            case .mana: context.roster[left].currentMana < context.roster[right].currentMana
            }
        }
        switch lowest {
        case .hero: return .hero
        case .companion: return .companion
        case .enemy: return .actor
        case nil: return nil
        }
    }
}

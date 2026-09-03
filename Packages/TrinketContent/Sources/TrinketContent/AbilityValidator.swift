import Foundation
import TrinketCore

enum AbilityValidator {
    struct Issue: Equatable, CustomStringConvertible {
        let abilityID: String
        let message: String

        var description: String {
            "\(abilityID): \(message)"
        }
    }

    static let descriptionOverrideIDs: Set<String> = [
        "astral-arrow",
        "blessed-aegis",
        "bounty-shot",
        "cold-snap",
        "combustion",
        "dark-pact",
        "earthquake",
        "fireball",
        "glacial-ward",
        "golden-plate",
        "ice-shot",
        "kindling",
        "panacea-potion",
        "pounce",
        "predators-focus",
        "sap-arrow",
        "serrated-edge",
        "shadowstep",
        "slash",
        "smite",
        "stab",
        "sunburst",
        "thorn-mail",
    ]

    static func validate(_ ability: Ability) -> [Issue] {
        var issues = validateEffectTargets(for: ability)
        issues.append(contentsOf: validateTierDamage(for: ability))
        issues.append(contentsOf: validateDescription(for: ability))
        issues.append(contentsOf: validateConditionalDamage(for: ability))
        return issues
    }

    static func validateCatalog() -> [Issue] {
        AbilityCatalog.all.flatMap(validate)
    }

    private static func validateEffectTargets(for ability: Ability) -> [Issue] {
        let allyTargets: Set<EffectTarget> = [.actor, .hero, .companion, .lowestHealthAlly]
        let enemyTargets: Set<EffectTarget> = [.abilityTarget, .enemy]
        var issues: [Issue] = []

        let targetedEffects = ability.targetedEffects
            + (ability.outcomeBranches?.flatMap(\.targetedEffects) ?? [])
        for targetedEffect in targetedEffects {
            switch targetedEffect.effect {
            case .cleanse, .cleanseRandom, .cleanseHealPerDebuff:
                if !allyTargets.contains(targetedEffect.target) {
                    issues.append(Issue(
                        abilityID: ability.id,
                        message: "cleanse effects must target allies (.actor, .hero, or .companion)",
                    ))
                }
            case .purge, .purgeRandom:
                if !enemyTargets.contains(targetedEffect.target) {
                    issues.append(Issue(
                        abilityID: ability.id,
                        message: "purge effects must target enemies (.abilityTarget or .enemy)",
                    ))
                }
            default:
                continue
            }
        }

        return issues
    }

    private static func validateTierDamage(for ability: Ability) -> [Issue] {
        var componentSets = [ability.damageComponents]
        if let branches = ability.outcomeBranches {
            componentSets.append(contentsOf: branches.map(\.damageComponents))
        }
        return componentSets.compactMap { components in
            let enemyDamageTotal = components
                .filter { $0.target == .abilityTarget }
                .reduce(0) { $0 + $1.amount }
            guard enemyDamageTotal > 0 else { return nil }
            return tierDamageIssue(tier: ability.tier, total: enemyDamageTotal, abilityID: ability.id)
        }
    }

    private static func validateDescription(for ability: Ability) -> [Issue] {
        let generated = AbilityDescriptionFormatter.format(ability)
        if ability.descriptionOverride != nil {
            if !descriptionOverrideIDs.contains(ability.id) {
                return [Issue(abilityID: ability.id, message: "unexpected description override; generated copy is '\(generated)'")]
            }
            return []
        }
        if generated != ability.summary {
            return [Issue(abilityID: ability.id, message: "summary '\(ability.summary)' does not match generated '\(generated)'")]
        }
        return []
    }

    private static func tierDamageIssue(tier: AbilityTier, total: Int, abilityID: String) -> Issue? {
        let allowed: Set<Int> = switch tier {
        case .basic:
            [1, 2]
        case .skill:
            [2, 3, 4]
        case .ultimate:
            [2, 3, 4, 5, 6, 7, 8]
        }

        if allowed.contains(total) || allowsMultiComponentTotal(abilityID: abilityID, total: total) {
            return nil
        }

        return Issue(
            abilityID: abilityID,
            message: "enemy damage total \(total) is unusual for \(tier.rawValue) tier",
        )
    }

    private static func allowsMultiComponentTotal(abilityID: String, total: Int) -> Bool {
        switch abilityID {
        case "blood-offering":
            total == 4
        case "smite":
            total == 4
        case "ice-shot":
            total == 4
        case "slash":
            total == 3
        default:
            false
        }
    }

    private static func validateConditionalDamage(for ability: Ability) -> [Issue] {
        var components = ability.damageComponents
        if let branches = ability.outcomeBranches {
            components.append(contentsOf: branches.flatMap(\.damageComponents))
        }
        return components.compactMap { component in
            guard let condition = component.condition, component.bonusAmount == 0 else { return nil }
            guard rendersCondition(condition, for: component) else {
                return Issue(
                    abilityID: ability.id,
                    message: "damage condition is not rendered in card text",
                )
            }
            return nil
        }
    }

    private static func rendersCondition(_ condition: DamageCondition, for component: DamageComponent) -> Bool {
        let generated = AbilityDescriptionFormatter.format(Ability(
            id: "preview",
            name: "preview",
            tier: .basic,
            damageComponents: [component],
        ))
        return generated.contains(conditionPreview(condition))
    }

    private static func conditionPreview(_ condition: DamageCondition) -> String {
        switch condition {
        case .enemyBleeding: "Bleeding"
        case .enemyBurning: "Burning"
        case .enemyNotBurning: "not Burning"
        case .enemyPoisoned: "Poisoned"
        case .enemyFrozen: "Frozen"
        case .enemyStunned: "Stunned"
        case .enemyStunnedOrFrozen: "Stunned or Frozen"
        case .enemyMarked: "Marked"
        case .enemyLowerHealthThanActor: "less Health"
        case .allyBelowHalfHealth: "half Health"
        case .enemyHasBuff: "buff"
        case .firstTurn: "first turn"
        }
    }
}

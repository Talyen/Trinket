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
        "avatar-of-justice",
        "blessed-aegis",
        "bounty-shot",
        "cold-snap",
        "combustion",
        "dark-pact",
        "earthquake",
        "faustian-bargain",
        "fire-arrow",
        "glacial-ward",
        "golden-plate",
        "hemorrhage",
        "meteor",
        "molten-bulwark",
        "panacea-potion",
        "phoenix-feather",
        "pounce",
        "predators-focus",
        "sap-arrow",
        "serrated-edge",
        "shadowstep",
        "smite",
        "sunburst",
        "thorn-mail",
    ]

    static let doTPairingExemptIDs: Set<String> = [
        "mana-berries",
        "pixie-dust",
        "faustian-bargain",
    ]

    static func validate(_ ability: Ability) -> [Issue] {
        var issues = validateEffectTargets(for: ability)
        issues.append(contentsOf: validatePairedDoTComponents(for: ability))
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

        for targetedEffect in ability.targetedEffects {
            switch targetedEffect.effect {
            case .cleanse, .cleanseRandom, .cleanseHealPerDebuff:
                if !allyTargets.contains(targetedEffect.target) {
                    issues.append(Issue(
                        abilityID: ability.id,
                        message: "cleanse effects must target allies (.actor, .hero, or .companion)"
                    ))
                }
            case .purge, .purgeRandom:
                if !enemyTargets.contains(targetedEffect.target) {
                    issues.append(Issue(
                        abilityID: ability.id,
                        message: "purge effects must target enemies (.abilityTarget or .enemy)"
                    ))
                }
            default:
                continue
            }
        }

        return issues
    }

    private static func validatePairedDoTComponents(for ability: Ability) -> [Issue] {
        var issues: [Issue] = []

        for component in ability.damageComponents where component.target == .abilityTarget {
            guard Effect.pairedDoT(keyword: component.keyword, potency: component.amount) != nil else {
                continue
            }
            let hasPair = ability.effects.contains {
                $0.keyword == component.keyword && $0.potency == component.amount
            }
            if !hasPair {
                issues.append(Issue(
                    abilityID: ability.id,
                    message: "missing paired .\(String(describing: component.keyword).lowercased())(\(component.amount))"
                ))
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
            message: "enemy damage total \(total) is unusual for \(tier.rawValue) tier"
        )
    }

    private static func allowsMultiComponentTotal(abilityID: String, total: Int) -> Bool {
        switch abilityID {
        case "blood-offering":
            total == 4
        case "smite":
            total == 4
        case "ice-shot":
            total == 2
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
            guard component.condition != nil, component.bonusAmount == 0 else { return nil }
            return Issue(
                abilityID: ability.id,
                message: "damage condition requires bonusAmount > 0 (amount always applies)"
            )
        }
    }
}

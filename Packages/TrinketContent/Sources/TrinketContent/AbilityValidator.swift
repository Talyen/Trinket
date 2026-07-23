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
        "dark-pact",
        "shadowstep"
    ]

    static func validate(_ ability: Ability) -> [Issue] {
        var issues = validateEffectTargets(for: ability)
        issues.append(contentsOf: validatePairedDoTComponents(for: ability))
        issues.append(contentsOf: validateTierDamage(for: ability))
        issues.append(contentsOf: validateDescription(for: ability))
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
            case .cleanse, .cleanseRandom:
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
        let enemyDamageTotal = ability.damageComponents
            .filter { $0.target == .abilityTarget }
            .reduce(0) { $0 + $1.amount }

        guard enemyDamageTotal > 0,
              let issue = tierDamageIssue(tier: ability.tier, total: enemyDamageTotal, abilityID: ability.id)
        else { return [] }

        return [issue]
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
            [2, 3]
        case .ultimate:
            [2, 3, 5, 6]
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
        case "blood-offering", "smite":
            total == 4
        case "ice-shot":
            total == 2
        default:
            false
        }
    }
}

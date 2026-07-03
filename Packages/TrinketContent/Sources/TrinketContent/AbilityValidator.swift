import Foundation
import TrinketCore

public enum AbilityValidator {
    public struct Issue: Equatable, CustomStringConvertible {
        public let abilityID: String
        public let message: String

        public var description: String {
            "\(abilityID): \(message)"
        }
    }

    public static let descriptionOverrideIDs: Set<String> = [
        "blackjack",
        "grasping-vines",
        "judgment",
        "glacial-ward",
        "molten-bulwark",
        "thorn-mail"
    ]

    public static func validate(_ ability: Ability) -> [Issue] {
        var issues = validateEffectTargets(for: ability)
        issues.append(contentsOf: validatePairedDoTComponents(for: ability))
        issues.append(contentsOf: validateTierDamage(for: ability))
        issues.append(contentsOf: validateDescription(for: ability))
        return issues
    }

    public static func validateCatalog() -> [Issue] {
        AbilityCatalog.all.flatMap(validate)
    }

    private static func validateEffectTargets(for ability: Ability) -> [Issue] {
        let allyTargets: Set<EffectTarget> = [.actor, .hero, .pet]
        let enemyTargets: Set<EffectTarget> = [.abilityTarget, .enemy]
        var issues: [Issue] = []

        for targetedEffect in ability.targetedEffects {
            switch targetedEffect.effect {
            case .cleanse, .cleanseRandom:
                if !allyTargets.contains(targetedEffect.target) {
                    issues.append(Issue(
                        abilityID: ability.id,
                        message: "cleanse effects must target allies (.actor, .hero, or .pet)"
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
            switch component.keyword {
            case .burn:
                if !ability.effects.contains(where: { if case let .burn(p) = $0 { return p == component.amount }; return false }) {
                    issues.append(Issue(abilityID: ability.id, message: "missing paired .burn(\(component.amount))"))
                }
            case .poison:
                if !ability.effects.contains(where: { if case let .poison(p) = $0 { return p == component.amount }; return false }) {
                    issues.append(Issue(abilityID: ability.id, message: "missing paired .poison(\(component.amount))"))
                }
            case .bleed:
                if !ability.effects.contains(where: { if case let .bleed(p) = $0 { return p == component.amount }; return false }) {
                    issues.append(Issue(abilityID: ability.id, message: "missing paired .bleed(\(component.amount))"))
                }
            default:
                continue
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
        let allowed: Set<Int>
        switch tier {
        case .basic:
            allowed = [1]
        case .skill:
            allowed = [3]
        case .ultimate:
            allowed = [2, 3, 6]
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
        abilityID == "bloodthorn" && total == 6
    }
}

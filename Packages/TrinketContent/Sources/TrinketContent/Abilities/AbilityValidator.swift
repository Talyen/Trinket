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
        "bash",
        "blessed-aegis",
        "blood-offering",
        "cold-snap",
        "cinderbloom",
        "combustion",
        "earthquake",
        "fireball",
        "golden-plate",
        "hemorrhage",
        "ice-shot",
        "kindling",
        "luck-potion",
        "maul",
        "molten-bulwark",
        "pack-tactics",
        "panacea-potion",
        "poison-dagger",
        "pounce",
        "predators-focus",
        "ray-of-frost",
        "serrated-edge",
        "shadowstep",
        "slash",
        "smite",
        "stab",
        "spiked-shield",
        "sunburst",
        "sunder",
    ]

    static func validate(_ ability: Ability) -> [Issue] {
        let operationSets = authoredOperationSets(for: ability)
        let operations = operationSets.flatMap(\.self)
        var issues = validateEffectTargets(in: operations, abilityID: ability.id)
        issues.append(contentsOf: validateTierDamage(in: operationSets, for: ability))
        issues.append(contentsOf: validateDescription(for: ability))
        issues.append(contentsOf: validateConditionalDamage(in: operations, abilityID: ability.id))
        return issues
    }

    static func validateCatalog() -> [Issue] {
        AbilityCatalog.all.flatMap(validate)
    }

    /// Keep alternatives separate for tier totals, but inspect every authored
    /// operation for target and condition validity.
    private static func authoredOperationSets(for ability: Ability) -> [[AbilityOperation]] {
        var sets = [ability.operations]
        sets.append(contentsOf: ability.outcomeBranches?.map(\.operations) ?? [])
        if let conditional = ability.conditionalOutcome {
            sets.append(conditional.operations)
        }
        return sets
    }

    private static func validateEffectTargets(in operations: [AbilityOperation], abilityID: String) -> [Issue] {
        let allyTargets: Set<EffectTarget> = [.actor, .hero, .companion, .lowestHealthAlly, .eachAlly]
        let enemyTargets: Set<EffectTarget> = [.abilityTarget, .enemy]
        var issues: [Issue] = []

        for targetedEffect in operations.compactMap(\.targetedEffect) {
            switch targetedEffect.effect {
            case .cleanse, .cleanseRandom, .cleanseHealPerDebuff, .panacea:
                if !allyTargets.contains(targetedEffect.target) {
                    issues.append(Issue(
                        abilityID: abilityID,
                        message: "cleanse effects must target allies",
                    ))
                }
            case .purge, .purgeRandom:
                if !enemyTargets.contains(targetedEffect.target) {
                    issues.append(Issue(
                        abilityID: abilityID,
                        message: "purge effects must target enemies (.abilityTarget or .enemy)",
                    ))
                }
            default:
                continue
            }
        }

        return issues
    }

    private static func validateTierDamage(in operationSets: [[AbilityOperation]], for ability: Ability) -> [Issue] {
        operationSets.compactMap { operations in
            let enemyDamageTotal = operations.compactMap(\.damageComponent)
                .filter { $0.target == .abilityTarget || $0.target == .enemy }
                .reduce(0) { $0 + $1.amount }
            guard enemyDamageTotal > 0 else { return nil }
            return tierDamageIssue(tier: ability.tier, total: enemyDamageTotal, abilityID: ability.id)
        }
    }

    private static func validateDescription(for ability: Ability) -> [Issue] {
        let generated = AbilityDescriptionFormatter.format(ability)
        if let override = ability.descriptionOverride {
            if !descriptionOverrideIDs.contains(ability.id) {
                return [Issue(abilityID: ability.id, message: "unexpected description override; generated copy is '\(generated)'")]
            }
            if override == generated {
                return [Issue(abilityID: ability.id, message: "description override is redundant; matches generated copy exactly")]
            }
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

        if allowed.contains(total) || allowsAuthoredDamageTotal(abilityID: abilityID, total: total) {
            return nil
        }

        return Issue(
            abilityID: abilityID,
            message: "enemy damage total \(total) is unusual for \(tier.rawValue) tier",
        )
    }

    private static func allowsAuthoredDamageTotal(abilityID: String, total: Int) -> Bool {
        switch abilityID {
        case "bash":
            total == 3
        case "blood-offering", "cold-snap", "dark-pact", "predators-focus":
            total == 1
        case "fireball":
            (1 ... 5).contains(total)
        case "ice-shot", "shield-bash":
            total == 5
        case "maul":
            total == 3
        case "slash":
            total == 3
        default:
            false
        }
    }

    private static func validateConditionalDamage(in operations: [AbilityOperation], abilityID: String) -> [Issue] {
        operations.compactMap(\.damageComponent).compactMap { component in
            guard let condition = component.condition, component.bonusAmount == 0 else { return nil }
            guard rendersCondition(condition, for: component) else {
                return Issue(
                    abilityID: abilityID,
                    message: "damage condition is not rendered in card text",
                )
            }
            return nil
        }
    }

    private static func rendersCondition(_ condition: DamageCondition, for component: DamageComponent) -> Bool {
        // Structural check: the formatted card text must contain the shared
        // sentence fragment for the condition. Both sides read DamageCondition
        // so copy changes stay in sync instead of drifting across two tables.
        let generated = AbilityDescriptionFormatter.format(Ability(
            id: "preview",
            name: "preview",
            tier: .basic,
            damageComponents: [component],
        ))
        return generated.contains(condition.sentenceFragment)
    }
}

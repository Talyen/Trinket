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
        "slash",
        "smite",
        "stab",
        "spiked-shield",
        "sunburst",
        "sunder",
    ]

    static func validate(_ ability: Ability) -> [Issue] {
        var targetIssues: [Issue] = []
        var damageIssues: [Issue] = []
        for operations in authoredOperationSets(for: ability) {
            var enemyDamage = 0
            for operation in operations {
                if let effect = operation.targetedEffect, let message = invalidTargetMessage(for: effect) {
                    targetIssues.append(Issue(abilityID: ability.id, message: message))
                }
                if let damage = operation.damageComponent, damage.target == .abilityTarget || damage.target == .enemy {
                    enemyDamage = SaturatedArithmetic.saturatingAdd(enemyDamage, damage.amount)
                }
            }
            if enemyDamage > 0, let issue = tierDamageIssue(tier: ability.tier, total: enemyDamage, abilityID: ability.id) {
                damageIssues.append(issue)
            }
        }
        return targetIssues + damageIssues + validateDescription(for: ability)
    }

    static func validateCatalog() -> [Issue] {
        AbilityCatalog.all.flatMap(validate)
    }

    /// Keep alternatives separate for tier totals, but inspect every authored
    /// operation for target validity.
    private static func authoredOperationSets(for ability: Ability) -> [[AbilityOperation]] {
        var sets = [ability.operations]
        sets.append(contentsOf: ability.outcomeBranches?.map(\.operations) ?? [])
        if let conditional = ability.conditionalOutcome {
            sets.append(conditional.operations)
        }
        return sets
    }

    private static func invalidTargetMessage(for targeted: TargetedEffect) -> String? {
        switch targeted.effect {
        case .cleanse, .cleanseRandom, .cleanseHealPerDebuff, .panacea:
            [.actor, .hero, .companion, .lowestHealthAlly, .eachAlly].contains(targeted.target)
                ? nil : "cleanse effects must target allies"
        case .purge, .purgeRandom:
            [.abilityTarget, .enemy].contains(targeted.target)
                ? nil : "purge effects must target enemies (.abilityTarget or .enemy)"
        default:
            nil
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
        let allowed: ClosedRange<Int> = switch tier {
        case .basic:
            1 ... 2
        case .skill:
            2 ... 4
        case .ultimate:
            2 ... 8
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
        case "bash", "fire-arrow", "maul", "slash":
            total == 3
        case "blood-offering", "cold-snap", "dark-pact", "predators-focus":
            total == 1
        case "fireball":
            (2 ... 6).contains(total)
        case "ice-shot", "shield-bash":
            total == 5
        default:
            false
        }
    }
}

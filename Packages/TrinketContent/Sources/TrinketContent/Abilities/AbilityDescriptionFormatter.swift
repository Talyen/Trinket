import Foundation
import TrinketCore

enum AbilityDescriptionFormatter {
    /// Shared rider wording; the branched and fixed paths join riders
    /// differently, but the words must not drift apart.
    private static let manaEmpowermentRider = "convert all your Mana into bonus Burn damage"

    static func format(_ ability: Ability) -> String {
        if let branches = ability.outcomeBranches, !branches.isEmpty {
            let branchTexts = branches.map(formatBranch)
            return ([joinOr(branchTexts)] + riderLines(for: ability)).joined(separator: "\n")
        }
        return formatFixed(ability)
    }

    private static func formatBranch(_ branch: AbilityOutcomeBranch) -> String {
        if branch.randomizeDamageKeywords {
            let amount = branch.damageComponents.first?.amount ?? 0
            return amount > 0 ? "Deal \(amount) Random damage" : ""
        }
        let ability = Ability(
            id: "branch",
            name: "branch",
            tier: .basic,
            operations: branch.operations,
        )
        return formatFixed(ability)
    }

    private static func riderLines(for ability: Ability) -> [String] {
        var riders: [String] = []
        if let critical = criticalClause(for: ability) {
            riders.append(critical)
        }
        if ability.repeatsManaEmpowerment {
            riders.append(manaEmpowermentRider)
        }
        if ability.hasLeech {
            riders.append("leech")
        }
        return riders.map(capitalize)
    }

    private static func criticalClause(for ability: Ability) -> String? {
        if ability.guaranteedCriticalIfEnemyBuffed {
            return "always Criticals if the enemy has a buff"
        }
        if ability.criticalChanceBonus > 0 {
            return "gain +\(Int(ability.criticalChanceBonus * 100))% Critical chance"
        }
        return nil
    }

    private static func formatFixed(_ ability: Ability) -> String {
        var lines: [String] = []

        for operation in ability.operations {
            switch operation {
            case let .damage(component):
                if component.target == .actor {
                    lines.append("Lose \(component.amount) Health")
                } else {
                    lines.append(contentsOf: formatEnemyDamage([component]))
                }
            case let .effect(targeted):
                lines.append(formatTargetedEffect(targeted))
            }
        }

        if let critical = criticalClause(for: ability) {
            lines.append(critical)
        }

        if ability.repeatsManaEmpowerment {
            lines.append(manaEmpowermentRider)
        }

        if ability.hasLeech {
            lines.append("Leech")
        }
        return lines.map(capitalize).joined(separator: "\n")
    }

    private static func formatEnemyDamage(
        _ components: [DamageComponent],
    ) -> [String] {
        var clauses: [String] = []
        for component in components {
            let text = if let scaling = component.scaling {
                switch scaling {
                case let .actorBlockFraction(divisor, _):
                    "deal \(component.keyword.rawValue) damage equal to \(fractionPhrase(divisor: divisor)) your Block"
                }
            } else {
                "deal \(component.amount) \(component.keyword.rawValue) damage"
            }
            if let condition = component.condition {
                if component.bonusAmount > 0 {
                    clauses.append(text)
                    clauses
                        .append("deal \(component.bonusAmount) extra \(component.keyword.rawValue) damage if \(conditionPhrase(condition))")
                } else {
                    clauses.append(text + " if \(conditionPhrase(condition))")
                }
            } else {
                clauses.append(text)
            }
        }
        return clauses
    }

    private static func formatTargetedEffect(_ targetedEffect: TargetedEffect) -> String {
        var phrase = EffectPresentation.applyPhrase(for: targetedEffect.effect)
        if let condition = targetedEffect.condition {
            phrase += " if \(conditionPhrase(condition))"
        }
        return phrase
    }

    private static func conditionPhrase(_ condition: DamageCondition) -> String {
        condition.sentenceFragment
    }

    private static func joinOr(_ clauses: [String]) -> String {
        guard let first = clauses.first else { return "" }
        guard clauses.count > 1 else {
            return first
        }
        if clauses.count == 2 {
            return "\(first) or \(lowercaseFirst(clauses[1]))"
        }
        guard let last = clauses.last else { return "" }
        let head = clauses.dropLast().joined(separator: ", ")
        return "\(head), or \(lowercaseFirst(last))"
    }

    private static func fractionPhrase(divisor: Int) -> String {
        divisor == 2 ? "half" : "1/\(divisor)"
    }

    private static func capitalize(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).lowercased() + text.dropFirst()
    }
}

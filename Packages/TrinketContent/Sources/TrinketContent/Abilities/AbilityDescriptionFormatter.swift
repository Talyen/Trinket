import Foundation
import TrinketCore

enum AbilityDescriptionFormatter {
    static func format(_ ability: Ability) -> String {
        if let branches = ability.outcomeBranches, !branches.isEmpty {
            let branchTexts = branches.map(formatBranch)
            return joinOr(branchTexts) + riderSuffix(for: ability)
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
            damageComponents: branch.damageComponents,
            targetedEffects: branch.targetedEffects,
        )
        let text = formatFixed(ability)
        return text.hasSuffix(".") ? String(text.dropLast()) : text
    }

    private static func riderSuffix(for ability: Ability) -> String {
        var riders: [String] = []
        if let critical = criticalClause(for: ability) {
            riders.append(critical)
        }
        if ability.repeatsManaEmpowerment {
            riders.append("convert all your Mana into bonus Burn damage")
        }
        if ability.hasLeech {
            riders.append("leech")
        }
        guard !riders.isEmpty else { return "" }
        let sentences = riders.map { capitalize($0) + "." }
        return " " + sentences.joined(separator: " ")
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
        var clauses: [String] = []

        for component in ability.damageComponents where component.target == .actor {
            clauses.append("Lose \(component.amount) Health")
        }

        let enemyDamage = ability.damageComponents.filter { $0.target == .abilityTarget }
        if !enemyDamage.isEmpty {
            clauses.append(contentsOf: formatEnemyDamage(enemyDamage))
        }

        for targetedEffect in ability.targetedEffects {
            clauses.append(formatTargetedEffect(targetedEffect))
        }

        if let critical = criticalClause(for: ability) {
            clauses.append(critical)
        }

        if ability.repeatsManaEmpowerment {
            clauses.append("convert all your Mana into bonus Burn damage")
        }

        let body = joinClauses(clauses)
        if ability.hasLeech {
            return body.isEmpty ? "Leech." : "\(body) Leech."
        }
        return body
    }

    private static func formatEnemyDamage(
        _ components: [DamageComponent],
    ) -> [String] {
        var clauses: [String] = []
        for component in components {
            var text = "deal \(component.amount) \(component.keyword.rawValue) damage"
            if let condition = component.condition {
                if component.bonusAmount > 0 {
                    text += ". If \(conditionPhrase(condition)), deal \(component.bonusAmount) extra \(component.keyword.rawValue) damage"
                } else {
                    text += " if \(conditionPhrase(condition))"
                }
            }
            clauses.append(text)
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
        switch condition {
        case .enemyBleeding: "the enemy is Bleeding"
        case .enemyBurning: "the enemy is Burning"
        case .enemyNotBurning: "the enemy is not Burning"
        case .enemyPoisoned: "the enemy is Poisoned"
        case .enemyFrozen: "the enemy is Frozen"
        case .enemyStunned: "the enemy is Stunned"
        case .enemyStunnedOrFrozen: "the enemy is Stunned or Frozen"
        case .enemyMarked: "the enemy is Marked"
        case .enemyLowerHealthThanActor: "the enemy has less Health than you"
        case .allyBelowHalfHealth: "your Hero or Companion is below half Health"
        case .enemyHasBuff: "the enemy has a buff"
        case .firstTurn: "played on the first turn"
        }
    }

    private static func joinOr(_ clauses: [String]) -> String {
        guard let first = clauses.first else { return "" }
        guard clauses.count > 1 else {
            return first.hasSuffix(".") ? first : first + "."
        }
        if clauses.count == 2 {
            return "\(first) or \(lowercaseFirst(clauses[1]))."
        }
        guard let last = clauses.last else { return "" }
        let head = clauses.dropLast().joined(separator: ", ")
        return "\(head), or \(lowercaseFirst(last))."
    }

    private static func joinClauses(_ clauses: [String]) -> String {
        guard let first = clauses.first else { return "" }
        guard clauses.count > 1 else {
            return capitalize(first) + "."
        }

        if first.hasPrefix("Lose ") || first.hasPrefix("costs ") {
            let tail = clauses.dropFirst().map(lowercaseFirst)
            let joinedTail = joinWithAnd(tail)
            return capitalize(first) + ". " + capitalize(joinedTail) + "."
        }

        let formatted = [capitalize(first)] + clauses.dropFirst().map(lowercaseFirst)
        return joinWithAnd(formatted) + "."
    }

    private static func joinWithAnd(_ clauses: [String]) -> String {
        guard let first = clauses.first else { return "" }
        guard clauses.count > 1 else { return first }
        if clauses.count == 2 {
            return "\(clauses[0]) and \(clauses[1])"
        }
        return clauses.dropLast().joined(separator: ", ") + ", and " + clauses[clauses.count - 1]
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

import Foundation

enum AbilityDescriptionFormatter {
    static func format(_ ability: Ability) -> String {
        var clauses: [String] = []

        for component in ability.damageComponents where component.target == .actor {
            clauses.append("Lose \(component.amount) Health")
        }

        let enemyDamage = ability.damageComponents.filter { $0.target == .abilityTarget }
        if !enemyDamage.isEmpty {
            clauses.append(formatEnemyDamage(enemyDamage, effects: ability.targetedEffects))
        }

        for targetedEffect in ability.targetedEffects {
            if isPairedDoT(targetedEffect.effect, in: enemyDamage) {
                continue
            }
            clauses.append(EffectPresentation.applyPhrase(for: targetedEffect.effect))
        }

        return joinClauses(clauses)
    }

    private static func formatEnemyDamage(
        _ components: [DamageComponent],
        effects: [TargetedEffect]
    ) -> String {
        let damageText: String
        if components.count == 1, let component = components.first {
            damageText = "Deal \(component.amount) \(component.keyword.rawValue) damage"
        } else {
            let parts = components.map { "\($0.amount) \($0.keyword.rawValue)" }
            damageText = "Deal \(listPhrase(parts)) damage"
        }

        guard components.count == 1,
              let component = components.first,
              let alias = component.keyword.statusAlias,
              effects.contains(where: { matchesDoT($0.effect, keyword: component.keyword, potency: component.amount) })
        else {
            return damageText
        }

        return "\(damageText) and applies \(alias)"
    }

    private static func isPairedDoT(_ effect: Effect, in damage: [DamageComponent]) -> Bool {
        guard let potency = effect.potency else { return false }
        return damage.contains { $0.keyword == effect.keyword && $0.amount == potency }
    }

    private static func matchesDoT(_ effect: Effect, keyword: Keyword, potency: Int) -> Bool {
        switch effect {
        case let .burn(amount): return keyword == .burn && amount == potency
        case let .poison(amount): return keyword == .poison && amount == potency
        case let .bleed(amount): return keyword == .bleed && amount == potency
        default: return false
        }
    }

    private static func listPhrase(_ items: [String]) -> String {
        guard items.count > 1 else { return items[0] }
        return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
    }

    private static func joinClauses(_ clauses: [String]) -> String {
        guard let first = clauses.first else { return "" }
        guard clauses.count > 1 else {
            return capitalize(first) + "."
        }

        if first.hasPrefix("Lose ") {
            let tail = clauses.dropFirst().map(lowercaseFirst)
            return capitalize(first) + ", " + joinWithAnd(tail) + "."
        }

        return joinWithAnd(clauses.map(capitalize)) + "."
    }

    private static func joinWithAnd(_ clauses: [String]) -> String {
        guard clauses.count > 1 else { return clauses[0] }
        return clauses.dropLast().joined(separator: ", ") + " and " + clauses[clauses.count - 1]
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

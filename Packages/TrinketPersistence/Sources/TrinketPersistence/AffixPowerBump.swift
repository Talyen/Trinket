import Foundation
import TrinketContent
import TrinketCore

enum AffixPowerBump {
    enum Direction {
        case up
        case down

        var intDelta: Int {
            self == .up ? 1 : -1
        }

        var percentDelta: Double {
            self == .up ? 0.01 : -0.01
        }
    }

    static func hasBumpableField(in powers: [ItemAffixPower], direction: Direction) -> Bool {
        powers.contains { power in
            power.modifiers.contains { $0.bumped(intDelta: direction.intDelta, percentDelta: direction.percentDelta) != nil }
                || triggerTargets.contains { $0.canBump(in: power.triggers, direction: direction) }
        }
    }

    static func apply(
        direction: Direction,
        to powers: inout [ItemAffixPower],
        affixIDs: [String],
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> String? {
        var candidates: [(powerIndex: Int, target: Target)] = []
        for (powerIndex, power) in powers.enumerated() {
            for (index, modifier) in power.modifiers.enumerated()
                where modifier.bumped(intDelta: direction.intDelta, percentDelta: direction.percentDelta) != nil {
                candidates.append((powerIndex, .modifier(index)))
            }
            for trigger in triggerTargets where trigger.canBump(in: power.triggers, direction: direction) {
                candidates.append((powerIndex, .trigger(trigger)))
            }
        }
        guard let pick = candidates.randomElement(using: &randomNumberGenerator) else {
            return nil
        }
        powers[pick.powerIndex] = apply(target: pick.target, to: powers[pick.powerIndex], direction: direction)
        return GameContent.itemAffixDefinition(matching: affixIDs[pick.powerIndex])?.title
            ?? affixIDs[pick.powerIndex]
    }

    private enum TriggerTarget: Sendable {
        case int(WritableKeyPath<CombatTraitTriggers, Int> & Sendable)
        case percent(WritableKeyPath<CombatTraitTriggers, Double> & Sendable)

        func canBump(in triggers: CombatTraitTriggers, direction: Direction) -> Bool {
            switch self {
            case let .int(keyPath):
                let value = triggers[keyPath: keyPath]
                return value > 0 && (direction == .up || value > 1)
            case let .percent(keyPath):
                let value = triggers[keyPath: keyPath]
                return value > 0 && (direction == .up || value > 0.01 + 1e-9)
            }
        }

        func apply(
            to triggers: CombatTraitTriggers,
            description: String,
            direction: Direction
        ) -> (triggers: CombatTraitTriggers, description: String) {
            var updatedTriggers = triggers
            var updatedDescription = description
            switch self {
            case let .int(keyPath):
                let old = updatedTriggers[keyPath: keyPath]
                let new = old + direction.intDelta
                updatedTriggers[keyPath: keyPath] = new
                updatedDescription = AffixPowerBump.rewriteStandaloneNumber(updatedDescription, from: old, to: new)
            case let .percent(keyPath):
                let old = updatedTriggers[keyPath: keyPath]
                let new = old + direction.percentDelta
                updatedTriggers[keyPath: keyPath] = new
                updatedDescription = AffixPowerBump.rewritePercent(updatedDescription, from: old, to: new)
            }
            return (updatedTriggers, updatedDescription)
        }
    }

    private enum Target: Sendable {
        case modifier(Int)
        case trigger(TriggerTarget)
    }

    private static let triggerTargets: [TriggerTarget] = [
        .int(\.onBleedApplyPoison),
        .int(\.onBurnApplyPoison),
        .int(\.onBleedDealBurnDamage),
        .percent(\.poisonDecayIncreaseChance),
        .int(\.damageWhileTargetFrozenBonus),
        .int(\.damageBelowHealthPercentBonus),
        .int(\.damageAfterDodgeBonus),
        .int(\.blockBrokenBlockFlat),
        .percent(\.companionLeechSharePercent),
        .int(\.onceBelowHealthPercentHeal),
        .int(\.blockOnDeathsDoor),
        .int(\.spendManaBlockFlat),
        .int(\.freezeDamageWhileBurningBonus),
    ]

    private static func apply(target: Target, to power: ItemAffixPower, direction: Direction) -> ItemAffixPower {
        var modifiers = power.modifiers
        var triggers = power.triggers
        var description = power.description

        switch target {
        case let .modifier(index):
            guard let bumped = modifiers[index].bumped(
                intDelta: direction.intDelta,
                percentDelta: direction.percentDelta
            ) else {
                return power
            }
            let old = modifiers[index].numericValue
            let new = bumped.numericValue
            let isPercent = modifiers[index].isPercent
            modifiers[index] = bumped
            description = isPercent
                ? rewritePercent(description, from: old, to: new)
                : rewriteStandaloneNumber(description, from: Int(old), to: Int(new))

        case let .trigger(triggerTarget):
            let result = triggerTarget.apply(to: triggers, description: description, direction: direction)
            triggers = result.triggers
            description = result.description
        }

        return ItemAffixPower(description: description, modifiers: modifiers, triggers: triggers)
    }

    static func rewriteStandaloneNumber(_ description: String, from old: Int, to new: Int) -> String {
        guard old != new else { return description }
        let token = String(old)
        var searchStart = description.startIndex
        while let range = description.range(of: token, range: searchStart ..< description.endIndex) {
            let hasDigitBefore = range.lowerBound > description.startIndex
                && description[description.index(before: range.lowerBound)].isNumber
            let hasDigitAfter = range.upperBound < description.endIndex
                && description[range.upperBound].isNumber
            let hasPercentAfter = range.upperBound < description.endIndex
                && description[range.upperBound] == "%"
            if !hasDigitBefore, !hasDigitAfter, !hasPercentAfter {
                return description.replacingCharacters(in: range, with: String(new))
            }
            searchStart = range.upperBound
        }
        return description
    }

    static func rewritePercent(_ description: String, from old: Double, to new: Double) -> String {
        let oldPct = Int((old * 100).rounded())
        let newPct = Int((new * 100).rounded())
        let token = "\(oldPct)%"
        var searchStart = description.startIndex
        while let range = description.range(of: token, range: searchStart ..< description.endIndex) {
            let hasDigitBefore = range.lowerBound > description.startIndex
                && description[description.index(before: range.lowerBound)].isNumber
            if !hasDigitBefore {
                return description.replacingCharacters(in: range, with: "\(newPct)%")
            }
            searchStart = range.upperBound
        }
        return rewriteStandaloneNumber(description, from: oldPct, to: newPct)
    }
}

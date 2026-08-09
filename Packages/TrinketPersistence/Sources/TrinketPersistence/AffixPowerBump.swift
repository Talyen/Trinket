import Foundation
import TrinketContent
import TrinketCore

enum AffixPowerBump {
    enum Direction {
        case up
        case down
    }

    static func hasBumpableField(in powers: [ItemAffixPower], direction: Direction) -> Bool {
        powers.contains { power in
            !bumpTargets(in: power, direction: direction).isEmpty
        }
    }

    static func apply(
        direction: Direction,
        to powers: inout [ItemAffixPower],
        affixIDs: [String],
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> String? {
        var candidates: [(powerIndex: Int, targetIndex: Int)] = []
        for (powerIndex, power) in powers.enumerated() {
            let targets = bumpTargets(in: power, direction: direction)
            for targetIndex in targets.indices {
                candidates.append((powerIndex, targetIndex))
            }
        }
        guard let pick = candidates.randomElement(using: &randomNumberGenerator) else {
            return nil
        }
        let targets = bumpTargets(in: powers[pick.powerIndex], direction: direction)
        let target = targets[pick.targetIndex]
        powers[pick.powerIndex] = apply(target: target, to: powers[pick.powerIndex], direction: direction)
        return GameContent.itemAffixDefinition(matching: affixIDs[pick.powerIndex])?.title
            ?? affixIDs[pick.powerIndex]
    }

    private enum Target {
        case modifier(Int)
        case intTrigger(WritableKeyPath<CombatTraitTriggers, Int>)
        case percentTrigger(WritableKeyPath<CombatTraitTriggers, Double>)
    }

    private enum NumericChange {
        case int(from: Int, to: Int)
        case percent(from: Double, to: Double)
    }

    private static func bumpTargets(in power: ItemAffixPower, direction: Direction) -> [Target] {
        var targets: [Target] = []
        for (index, modifier) in power.modifiers.enumerated() where bumped(modifier, direction: direction) != nil {
            targets.append(.modifier(index))
        }
        let triggers = power.triggers
        let triggerTargets: [Target] = [
            .intTrigger(\.onBleedApplyPoison),
            .intTrigger(\.onBurnApplyPoison),
            .intTrigger(\.onBleedDealBurnDamage),
            .percentTrigger(\.poisonDecayIncreaseChance),
            .intTrigger(\.damageWhileTargetFrozenBonus),
            .intTrigger(\.damageBelowHealthPercentBonus),
            .intTrigger(\.damageAfterDodgeBonus),
            .intTrigger(\.blockBrokenBlockFlat),
            .percentTrigger(\.companionLeechSharePercent),
            .intTrigger(\.onceBelowHealthPercentHeal),
            .intTrigger(\.blockOnDeathsDoor),
            .intTrigger(\.spendManaBlockFlat),
            .intTrigger(\.freezeDamageWhileBurningBonus),
        ]
        targets.append(contentsOf: triggerTargets.filter {
            canBump($0, in: triggers, direction: direction)
        })
        return targets
    }

    private static func canBump(
        _ target: Target,
        in triggers: CombatTraitTriggers,
        direction: Direction
    ) -> Bool {
        switch target {
        case .modifier:
            return false
        case let .intTrigger(keyPath):
            let value = triggers[keyPath: keyPath]
            return value > 0 && canBump(value, direction: direction)
        case let .percentTrigger(keyPath):
            let value = triggers[keyPath: keyPath]
            return value > 0 && canBump(value, direction: direction)
        }
    }

    private static func apply(target: Target, to power: ItemAffixPower, direction: Direction) -> ItemAffixPower {
        var modifiers = power.modifiers
        var triggers = power.triggers
        var description = power.description

        switch target {
        case let .modifier(index):
            guard let (modifier, change) = bumped(modifiers[index], direction: direction) else {
                return power
            }
            modifiers[index] = modifier
            description = rewrittenDescription(description, for: change)
        case let .intTrigger(keyPath):
            let old = triggers[keyPath: keyPath]
            let new = old + direction.intDelta
            triggers[keyPath: keyPath] = new
            description = rewriteStandaloneNumber(description, from: old, to: new)
        case let .percentTrigger(keyPath):
            let old = triggers[keyPath: keyPath]
            let new = old + direction.percentDelta
            triggers[keyPath: keyPath] = new
            description = rewritePercent(description, from: old, to: new)
        }

        return ItemAffixPower(description: description, modifiers: modifiers, triggers: triggers)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func bumped(
        _ modifier: AffixModifier,
        direction: Direction
    ) -> (AffixModifier, NumericChange)? {
        switch modifier {
        case let .strength(value): bumpedInt(value, direction: direction, make: AffixModifier.strength)
        case let .agility(value): bumpedInt(value, direction: direction, make: AffixModifier.agility)
        case let .toughness(value): bumpedInt(value, direction: direction, make: AffixModifier.toughness)
        case let .intellect(value): bumpedInt(value, direction: direction, make: AffixModifier.intellect)
        case let .wisdom(value): bumpedInt(value, direction: direction, make: AffixModifier.wisdom)
        case let .maximumHealth(value): bumpedInt(value, direction: direction, make: AffixModifier.maximumHealth)
        case let .maximumMana(value): bumpedInt(value, direction: direction, make: AffixModifier.maximumMana)
        case let .damageDealt(keyword, value):
            bumpedInt(value, direction: direction) { .damageDealt(keyword, $0) }
        case let .poisonDamageDealtPercent(value):
            bumpedPercent(value, direction: direction, make: AffixModifier.poisonDamageDealtPercent)
        case let .healthRestored(value): bumpedInt(value, direction: direction, make: AffixModifier.healthRestored)
        case let .leechGainedPercent(value):
            bumpedPercent(value, direction: direction, make: AffixModifier.leechGainedPercent)
        case let .leechHealing(value): bumpedInt(value, direction: direction, make: AffixModifier.leechHealing)
        case let .goldGained(value): bumpedInt(value, direction: direction, make: AffixModifier.goldGained)
        case let .goldGainedPercent(value):
            bumpedPercent(value, direction: direction, make: AffixModifier.goldGainedPercent)
        case let .blockGained(value): bumpedInt(value, direction: direction, make: AffixModifier.blockGained)
        case let .leechDuration(value): bumpedInt(value, direction: direction, make: AffixModifier.leechDuration)
        case let .bleedDuration(value): bumpedInt(value, direction: direction, make: AffixModifier.bleedDuration)
        case let .damageTakenPercent(keyword, value):
            bumpedPercent(value, direction: direction) { .damageTakenPercent(keyword, $0) }
        case let .damageTakenFlat(keyword, value):
            bumpedInt(value, direction: direction) { .damageTakenFlat(keyword, $0) }
        case let .damageTakenVulnerability(keyword, value):
            bumpedPercent(value, direction: direction) { .damageTakenVulnerability(keyword, $0) }
        case let .companionDamageDealt(value):
            bumpedInt(value, direction: direction, make: AffixModifier.companionDamageDealt)
        case let .manaCostReductionPercent(value):
            bumpedPercent(value, direction: direction, make: AffixModifier.manaCostReductionPercent)
        }
    }

    private static func bumpedInt(
        _ value: Int,
        direction: Direction,
        make: (Int) -> AffixModifier
    ) -> (AffixModifier, NumericChange)? {
        guard canBump(value, direction: direction) else { return nil }
        let new = value + direction.intDelta
        return (make(new), .int(from: value, to: new))
    }

    private static func bumpedPercent(
        _ value: Double,
        direction: Direction,
        make: (Double) -> AffixModifier
    ) -> (AffixModifier, NumericChange)? {
        guard canBump(value, direction: direction) else { return nil }
        let new = value + direction.percentDelta
        return (make(new), .percent(from: value, to: new))
    }

    private static func canBump(_ value: Int, direction: Direction) -> Bool {
        switch direction {
        case .up: true
        case .down: value > 1
        }
    }

    private static func canBump(_ value: Double, direction: Direction) -> Bool {
        switch direction {
        case .up: true
        case .down: value > 0.01 + 1e-9
        }
    }

    private static func rewrittenDescription(
        _ description: String,
        for change: NumericChange
    ) -> String {
        switch change {
        case let .int(old, new):
            rewriteStandaloneNumber(description, from: old, to: new)
        case let .percent(old, new):
            rewritePercent(description, from: old, to: new)
        }
    }

    private static func rewriteStandaloneNumber(_ description: String, from old: Int, to new: Int) -> String {
        guard old != new else { return description }
        let token = String(old)
        var searchStart = description.startIndex
        while let range = description.range(of: token, range: searchStart ..< description.endIndex) {
            let hasDigitBefore = range.lowerBound > description.startIndex
                && description[description.index(before: range.lowerBound)].isNumber
            let hasDigitAfter = range.upperBound < description.endIndex
                && description[range.upperBound].isNumber
            if !hasDigitBefore, !hasDigitAfter {
                return description.replacingCharacters(in: range, with: String(new))
            }
            searchStart = range.upperBound
        }
        return description
    }

    private static func rewritePercent(_ description: String, from old: Double, to new: Double) -> String {
        let oldPct = Int((old * 100).rounded())
        let newPct = Int((new * 100).rounded())
        let token = "\(oldPct)%"
        if let range = description.range(of: token) {
            return description.replacingCharacters(in: range, with: "\(newPct)%")
        }
        return rewriteStandaloneNumber(description, from: oldPct, to: newPct)
    }
}

private extension AffixPowerBump.Direction {
    var intDelta: Int {
        self == .up ? 1 : -1
    }

    var percentDelta: Double {
        self == .up ? 0.01 : -0.01
    }
}

extension ItemAffixPower {
    func copyForMutation() -> ItemAffixPower {
        ItemAffixPower(
            description: description,
            modifiers: modifiers,
            triggers: triggers
        )
    }
}

import Foundation

public extension ItemAffixPower {
    func scaled(by multiplier: Int) -> Self {
        guard multiplier != 1 else { return self }
        var description = description
        let scaledModifiers = modifiers.map { modifier in
            let scaled = modifier.isPercent
                ? modifier.mapPercent { $0 * Double(multiplier) }
                : modifier.mapInt { $0 * multiplier }
            description = Self.replacingMagnitude(
                in: description,
                from: modifier.numericValue,
                to: scaled.numericValue,
                isPercent: modifier.isPercent
            )
            return scaled
        }
        let scaledTriggers = triggers.scalingAffixMagnitudes(by: multiplier) { old, new, isPercent in
            description = Self.replacingMagnitude(
                in: description,
                from: old,
                to: new,
                isPercent: isPercent
            )
        }
        return Self(description: description, modifiers: scaledModifiers, triggers: scaledTriggers)
    }

    var hasRollableMagnitudes: Bool {
        modifiers.contains { $0.numericValue != 0 } || triggers.hasRollableAffixMagnitudes
    }

    func rolled(using randomNumberGenerator: inout some RandomNumberGenerator) -> Self {
        guard hasRollableMagnitudes else { return self }
        var description = description
        let rolledModifiers = modifiers.map { modifier -> AffixModifier in
            guard modifier.numericValue != 0 else { return modifier }
            if modifier.isPercent {
                let newValue = ItemAffixMagnitudeRoll.percentValues(around: modifier.numericValue)
                    .randomElement(using: &randomNumberGenerator)
                    ?? modifier.numericValue
                description = Self.replacingMagnitude(
                    in: description,
                    from: modifier.numericValue,
                    to: newValue,
                    isPercent: true
                )
                return modifier.mapPercent { _ in newValue }
            }
            let old = Int(modifier.numericValue.rounded())
            let newValue = Int.random(
                in: ItemAffixMagnitudeRoll.integerRange(around: old),
                using: &randomNumberGenerator
            )
            description = Self.replacingMagnitude(
                in: description,
                from: Double(old),
                to: Double(newValue),
                isPercent: false
            )
            return modifier.mapInt { _ in newValue }
        }
        let rolledTriggers = triggers.rollingAffixMagnitudes(using: &randomNumberGenerator) { old, new, isPercent in
            description = Self.replacingMagnitude(
                in: description,
                from: old,
                to: new,
                isPercent: isPercent
            )
        }
        return Self(description: description, modifiers: rolledModifiers, triggers: rolledTriggers)
    }

    func isAtOrAboveRollMax(of catalog: Self) -> Bool {
        guard catalog.hasRollableMagnitudes else { return false }
        for (index, catalogModifier) in catalog.modifiers.enumerated() where catalogModifier.numericValue != 0 {
            guard modifiers.indices.contains(index) else { return false }
            if catalogModifier.isPercent {
                let maximum = ItemAffixMagnitudeRoll.percentValues(around: catalogModifier.numericValue).max()
                    ?? catalogModifier.numericValue
                if modifiers[index].numericValue + 1e-9 < maximum {
                    return false
                }
            } else {
                let maximum = ItemAffixMagnitudeRoll.integerRange(
                    around: Int(catalogModifier.numericValue.rounded())
                ).upperBound
                if Int(modifiers[index].numericValue.rounded()) < maximum {
                    return false
                }
            }
        }
        return triggers.affixMagnitudesAreAtOrAboveRollMax(of: catalog.triggers)
    }

    private static func replacingMagnitude(
        in description: String,
        from old: Double,
        to new: Double,
        isPercent: Bool
    ) -> String {
        let oldText = isPercent ? "\(Int((old * 100).rounded()))%" : "\(Int(old.rounded()))"
        let newText = isPercent ? "\(Int((new * 100).rounded()))%" : "\(Int(new.rounded()))"
        var searchStart = description.startIndex
        while let range = description.range(of: oldText, range: searchStart ..< description.endIndex) {
            let hasDigitBefore = range.lowerBound > description.startIndex
                && description[description.index(before: range.lowerBound)].isNumber
            let hasDigitAfter = range.upperBound < description.endIndex
                && description[range.upperBound].isNumber
            let trailingText = description[range.upperBound...]
            let isHealthThreshold = isPercent && trailingText.hasPrefix(" Health")
            if !hasDigitBefore, !hasDigitAfter, !isHealthThreshold {
                return description.replacingCharacters(in: range, with: newText)
            }
            searchStart = range.upperBound
        }
        return description
    }
}

public enum ItemAffixMagnitudeRoll: Sendable {
    public static func integerRange(around value: Int) -> ClosedRange<Int> {
        let delta = max(1, value / 4)
        return max(1, value - delta) ... (value + delta)
    }

    public static func percentValues(around value: Double) -> [Double] {
        let points = Int((value * 100).rounded())
        let delta = max(1, points / 4)
        let lower = max(1, points - delta)
        let upper = points + delta
        let step = delta < 5 ? 1 : 5
        var choices: [Int] = []
        var current = points
        while current >= lower {
            choices.append(current)
            current -= step
        }
        current = points + step
        while current <= upper {
            choices.append(current)
            current += step
        }
        return Array(Set(choices)).sorted().map { Double($0) / 100 }
    }
}

private extension CombatTraitTriggers {
    mutating func scale(
        _ keyPath: WritableKeyPath<Self, Int>,
        by multiplier: Int,
        record: (Double, Double, Bool) -> Void
    ) {
        let old = self[keyPath: keyPath]
        guard old != 0 else { return }
        let new = old * multiplier
        self[keyPath: keyPath] = new
        record(Double(old), Double(new), false)
    }

    mutating func scale(
        _ keyPath: WritableKeyPath<Self, Double>,
        by multiplier: Int,
        record: (Double, Double, Bool) -> Void
    ) {
        let old = self[keyPath: keyPath]
        guard old != 0 else { return }
        let new = old * Double(multiplier)
        self[keyPath: keyPath] = new
        record(old, new, true)
    }

    var hasRollableAffixMagnitudes: Bool {
        Self.affixMagnitudeFields.contains { field in
            switch field {
            case let .int(keyPath):
                self[keyPath: keyPath] != 0
            case let .percent(keyPath):
                self[keyPath: keyPath] != 0
            }
        }
    }

    func scalingAffixMagnitudes(
        by multiplier: Int,
        record: (Double, Double, Bool) -> Void
    ) -> Self {
        var scaled = self
        for field in Self.affixMagnitudeFields {
            switch field {
            case let .int(keyPath):
                scaled.scale(keyPath, by: multiplier, record: record)
            case let .percent(keyPath):
                scaled.scale(keyPath, by: multiplier, record: record)
            }
        }
        return scaled
    }

    func rollingAffixMagnitudes(
        using randomNumberGenerator: inout some RandomNumberGenerator,
        record: (Double, Double, Bool) -> Void
    ) -> Self {
        var rolled = self
        for field in Self.affixMagnitudeFields {
            switch field {
            case let .int(keyPath):
                let old = rolled[keyPath: keyPath]
                guard old != 0 else { continue }
                let new = Int.random(
                    in: ItemAffixMagnitudeRoll.integerRange(around: old),
                    using: &randomNumberGenerator
                )
                rolled[keyPath: keyPath] = new
                record(Double(old), Double(new), false)
            case let .percent(keyPath):
                let old = rolled[keyPath: keyPath]
                guard old != 0 else { continue }
                let new = ItemAffixMagnitudeRoll.percentValues(around: old)
                    .randomElement(using: &randomNumberGenerator)
                    ?? old
                rolled[keyPath: keyPath] = new
                record(old, new, true)
            }
        }
        return rolled
    }

    func affixMagnitudesAreAtOrAboveRollMax(of catalog: Self) -> Bool {
        for field in Self.affixMagnitudeFields {
            switch field {
            case let .int(keyPath):
                let catalogValue = catalog[keyPath: keyPath]
                guard catalogValue != 0 else { continue }
                let maximum = ItemAffixMagnitudeRoll.integerRange(around: catalogValue).upperBound
                if self[keyPath: keyPath] < maximum {
                    return false
                }
            case let .percent(keyPath):
                let catalogValue = catalog[keyPath: keyPath]
                guard catalogValue != 0 else { continue }
                let maximum = ItemAffixMagnitudeRoll.percentValues(around: catalogValue).max() ?? catalogValue
                if self[keyPath: keyPath] + 1e-9 < maximum {
                    return false
                }
            }
        }
        return true
    }

    private enum AffixMagnitudeField: Sendable {
        case int(WritableKeyPath<CombatTraitTriggers, Int> & Sendable)
        case percent(WritableKeyPath<CombatTraitTriggers, Double> & Sendable)
    }

    private static let affixMagnitudeFields: [AffixMagnitudeField] = [
        .int(\.cleanseSelfHeal),
        .int(\.gainGoldBonusHealSelf),
        .percent(\.thornsPercent),
        .int(\.onBleedApplyPoison),
        .int(\.onBurnApplyPoison),
        .int(\.onBleedDealBurnDamage),
        .percent(\.poisonDecayIncreaseChance),
        .int(\.freezeDamageWhileBurningBonus),
        .int(\.damageWhileTargetFrozenBonus),
        .int(\.damageBelowHealthPercentBonus),
        .int(\.damageAfterDodgeBonus),
        .int(\.blockBrokenBlockFlat),
        .percent(\.companionLeechSharePercent),
        .int(\.onceBelowHealthPercentHeal),
        .int(\.blockOnDeathsDoor),
        .int(\.spendManaBlockFlat),
        .int(\.holyDamageBlockFlat),
        .int(\.holyDamageCleanseCount),
        .int(\.holyDamageHealFlat),
        .int(\.dodgeGoldFlat),
        .percent(\.ignoreEnemyMitigationPercent),
        .int(\.stunDealPhysicalFlat),
        .int(\.damageWhileTargetStunnedBonus),
        .int(\.dodgeBlockFlat),
        .int(\.holyDamagePurgeCount),
        .int(\.enemyStunnedPurgeCount),
        .int(\.criticalPurgeCount),
        .int(\.criticalActionGoldFlat),
        .int(\.leechRestoreManaFlat),
        .int(\.gainManaBlockFlat),
        .int(\.defeatEnemyGoldFlat),
        .int(\.leechGoldFlat),
        .int(\.dodgeHealFlat),
        .percent(\.dodgeChanceBelowHealthPercentBonus),
        .int(\.dodgeDealStunFlat),
        .percent(\.dodgeChanceBonus),
        .int(\.holyDamagePoisonFlat),
        .int(\.drawEveryOtherTurn),
        .int(\.drawOnHealthLoss),
        .percent(\.physicalStunBuildupPercent),
        .percent(\.blockGainThornsPercent),
        .int(\.drawOnSpendMana),
        .percent(\.physicalDamageBlockPercent),
        .int(\.bleedDamageGoldFlat),
        .int(\.goldPerTurn),
        .percent(\.healthRestoredPoisonPercent),
        .percent(\.sunderingBlockMultiplier),
        .int(\.cardsPlayedManaFlat),
        .int(\.victoryGoldFlat),
        .int(\.healthPerTurn),
        .int(\.companionCardsPerTurn),
        .int(\.freezeExtraActionSkips),
        .percent(\.criticalChanceBonus),
    ]
}

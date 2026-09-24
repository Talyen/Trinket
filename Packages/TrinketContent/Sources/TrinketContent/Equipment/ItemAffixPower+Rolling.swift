import Foundation

public extension ItemAffixPower {
    /// Applies a numeric rule to modifiers, then trigger fields in catalog order.
    /// That order also determines which matching number in the description changes.
    private func transformingMagnitudes(
        percent: (Double) -> Double,
        int: (Int) -> Int,
    ) -> Self {
        var description = description
        let record: (Double, Double, Bool) -> Void = { old, new, isPercent in
            description = Self.replacingMagnitude(
                in: description,
                from: old,
                to: new,
                isPercent: isPercent,
            )
        }
        let modifiers = mapModifierMagnitudes(percent: percent, int: int, record: record)
        let triggers = triggers.mappingAffixMagnitudes(percent: percent, int: int, record: record)
        return Self(description: description, modifiers: modifiers, triggers: triggers)
    }

    private func mapModifierMagnitudes(
        percent: (Double) -> Double,
        int: (Int) -> Int,
        record: (Double, Double, Bool) -> Void,
    ) -> [AffixModifier] {
        modifiers.map { modifier in
            if modifier.isPercent {
                let old = modifier.numericValue
                guard old != 0 else { return modifier }
                let new = percent(old)
                if new != old {
                    record(old, new, true)
                }
                return modifier.mapPercent { _ in new }
            }
            let old = Int(modifier.numericValue.rounded())
            guard old != 0 else { return modifier }
            let new = int(old)
            if new != old {
                record(Double(old), Double(new), false)
            }
            return modifier.mapInt { _ in new }
        }
    }

    func scaled(by multiplier: Int) -> Self {
        guard multiplier != 1 else { return self }
        return transformingMagnitudes(
            percent: { $0 * Double(multiplier) },
            int: { $0 * multiplier },
        )
    }

    var hasRollableMagnitudes: Bool {
        modifiers.contains { $0.numericValue != 0 } || triggers.hasRollableAffixMagnitudes
    }

    func rolled(using randomNumberGenerator: inout some RandomNumberGenerator) -> Self {
        guard hasRollableMagnitudes else { return self }
        return transformingMagnitudes(
            percent: {
                ItemAffixMagnitudeRoll.percentValues(around: $0)
                    .randomElement(using: &randomNumberGenerator) ?? $0
            },
            int: {
                Int.random(
                    in: ItemAffixMagnitudeRoll.integerRange(around: $0),
                    using: &randomNumberGenerator,
                )
            },
        )
    }

    func rolledMax() -> Self {
        guard hasRollableMagnitudes else { return self }
        return transformingMagnitudes(
            percent: { ItemAffixMagnitudeRoll.percentValues(around: $0).max() ?? $0 },
            int: { ItemAffixMagnitudeRoll.integerRange(around: $0).upperBound },
        )
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
                    around: Int(catalogModifier.numericValue.rounded()),
                ).upperBound
                if Int(modifiers[index].numericValue.rounded()) < maximum {
                    return false
                }
            }
        }
        return triggers.affixMagnitudesAreAtOrAboveRollMax(of: catalog.triggers)
    }

    func hasBumpableField(direction: ItemAffixPowerBumpDirection) -> Bool {
        modifiers.contains { $0.bumped(intDelta: direction.intDelta, percentDelta: direction.percentDelta) != nil }
            || triggers.hasBumpableAffixMagnitude(direction: direction)
    }

    enum BumpTarget: Sendable {
        case modifier(Int)
        case trigger(Int)
    }

    func bumpCandidates(direction: ItemAffixPowerBumpDirection) -> [BumpTarget] {
        var candidates: [BumpTarget] = []
        for (index, modifier) in modifiers.enumerated()
            where modifier.bumped(intDelta: direction.intDelta, percentDelta: direction.percentDelta) != nil {
            candidates.append(.modifier(index))
        }
        for (index, field) in CombatTraitTriggers.affixMagnitudeFields.enumerated()
            where field.canBump(in: triggers, direction: direction) {
            candidates.append(.trigger(index))
        }
        return candidates
    }

    func bumped(target: BumpTarget, direction: ItemAffixPowerBumpDirection) -> ItemAffixPower {
        var modifiers = modifiers
        var triggers = triggers
        var description = description

        switch target {
        case let .modifier(index):
            guard modifiers.indices.contains(index),
                  let bumpedModifier = modifiers[index].bumped(
                      intDelta: direction.intDelta,
                      percentDelta: direction.percentDelta,
                  ) else {
                return self
            }
            let old = modifiers[index].numericValue
            let new = bumpedModifier.numericValue
            modifiers[index] = bumpedModifier
            description = Self.replacingMagnitude(
                in: description,
                from: old,
                to: new,
                isPercent: modifiers[index].isPercent,
            )

        case let .trigger(index):
            guard CombatTraitTriggers.affixMagnitudeFields.indices.contains(index) else { return self }
            let field = CombatTraitTriggers.affixMagnitudeFields[index]
            field.bump(in: &triggers, direction: direction) { old, new, isPercent in
                description = Self.replacingMagnitude(
                    in: description,
                    from: old,
                    to: new,
                    isPercent: isPercent,
                )
            }
        }

        return ItemAffixPower(description: description, modifiers: modifiers, triggers: triggers)
    }

    static func hasBumpableField(in powers: [ItemAffixPower], direction: ItemAffixPowerBumpDirection) -> Bool {
        powers.contains { $0.hasBumpableField(direction: direction) }
    }

    static func applyBump(
        direction: ItemAffixPowerBumpDirection,
        to powers: inout [ItemAffixPower],
        affixIDs: [String],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> (title: String, affixIndex: Int)? {
        var candidates: [(powerIndex: Int, target: BumpTarget)] = []
        for (powerIndex, power) in powers.enumerated() {
            for target in power.bumpCandidates(direction: direction) {
                candidates.append((powerIndex, target))
            }
        }
        guard let pick = candidates.randomElement(using: &randomNumberGenerator) else {
            return nil
        }
        powers[pick.powerIndex] = powers[pick.powerIndex].bumped(target: pick.target, direction: direction)
        let title = GameContent.itemAffixDefinition(matching: affixIDs[pick.powerIndex])?.title
            ?? affixIDs[pick.powerIndex]
        return (title, pick.powerIndex)
    }

    private static func replacingMagnitude(
        in description: String,
        from old: Double,
        to new: Double,
        isPercent: Bool,
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

public enum ItemAffixPowerBumpDirection: Equatable, Sendable {
    case up
    case down

    public var intDelta: Int {
        self == .up ? 1 : -1
    }

    public var percentDelta: Double {
        self == .up ? 0.01 : -0.01
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
        let start = points - ((points - lower) / step) * step
        return stride(from: start, through: upper, by: step).map { Double($0) / 100 }
    }
}

private extension CombatTraitTriggers {
    var hasRollableAffixMagnitudes: Bool {
        Self.affixMagnitudeFields.contains { $0.isNonzero(in: self) }
    }

    func mappingAffixMagnitudes(
        percent: (Double) -> Double,
        int: (Int) -> Int,
        record: (Double, Double, Bool) -> Void,
    ) -> Self {
        var mapped = self
        for field in Self.affixMagnitudeFields {
            field.map(in: &mapped, percent: percent, int: int, record: record)
        }
        return mapped
    }

    func hasBumpableAffixMagnitude(direction: ItemAffixPowerBumpDirection) -> Bool {
        Self.affixMagnitudeFields.contains { field in
            field.canBump(in: self, direction: direction)
        }
    }

    func affixMagnitudesAreAtOrAboveRollMax(of catalog: Self) -> Bool {
        Self.affixMagnitudeFields.allSatisfy { $0.isAtOrAboveRollMax(in: self, of: catalog) }
    }
}

extension CombatTraitTriggers {
    enum AffixMagnitudeField: Sendable {
        case int(WritableKeyPath<CombatTraitTriggers, Int> & Sendable, name: String)
        case percent(WritableKeyPath<CombatTraitTriggers, Double> & Sendable, name: String)

        var fieldName: String {
            switch self {
            case let .int(_, name), let .percent(_, name):
                name
            }
        }

        func isNonzero(in triggers: CombatTraitTriggers) -> Bool {
            switch self {
            case let .int(keyPath, _):
                triggers[keyPath: keyPath] != 0
            case let .percent(keyPath, _):
                triggers[keyPath: keyPath] != 0
            }
        }

        func map(
            in triggers: inout CombatTraitTriggers,
            percent: (Double) -> Double,
            int: (Int) -> Int,
            record: (Double, Double, Bool) -> Void,
        ) {
            switch self {
            case let .int(keyPath, _):
                let old = triggers[keyPath: keyPath]
                guard old != 0 else { return }
                let new = int(old)
                triggers[keyPath: keyPath] = new
                if new != old {
                    record(Double(old), Double(new), false)
                }
            case let .percent(keyPath, _):
                let old = triggers[keyPath: keyPath]
                guard old != 0 else { return }
                let new = percent(old)
                triggers[keyPath: keyPath] = new
                if new != old {
                    record(old, new, true)
                }
            }
        }

        func isAtOrAboveRollMax(in triggers: CombatTraitTriggers, of catalog: CombatTraitTriggers) -> Bool {
            switch self {
            case let .int(keyPath, _):
                let value = catalog[keyPath: keyPath]
                return value == 0 || triggers[keyPath: keyPath] >= ItemAffixMagnitudeRoll.integerRange(around: value).upperBound
            case let .percent(keyPath, _):
                let value = catalog[keyPath: keyPath]
                let maximum = ItemAffixMagnitudeRoll.percentValues(around: value).max() ?? value
                return value == 0 || triggers[keyPath: keyPath] + 1e-9 >= maximum
            }
        }

        func canBump(in triggers: CombatTraitTriggers, direction: ItemAffixPowerBumpDirection) -> Bool {
            switch self {
            case let .int(keyPath, _):
                let value = triggers[keyPath: keyPath]
                return value > 0 && (direction == .up || value > 1)
            case let .percent(keyPath, _):
                let value = triggers[keyPath: keyPath]
                return value > 0 && (direction == .up || value > 0.01 + 1e-9)
            }
        }

        func bump(
            in triggers: inout CombatTraitTriggers,
            direction: ItemAffixPowerBumpDirection,
            record: (Double, Double, Bool) -> Void,
        ) {
            switch self {
            case let .int(keyPath, _):
                let old = triggers[keyPath: keyPath]
                let new = old + direction.intDelta
                triggers[keyPath: keyPath] = new
                record(Double(old), Double(new), false)
            case let .percent(keyPath, _):
                let old = triggers[keyPath: keyPath]
                let new = old + direction.percentDelta
                triggers[keyPath: keyPath] = new
                record(old, new, true)
            }
        }
    }
}

public extension CombatTraitTriggers {
    /// Names of rollable trigger magnitudes. Pair with the excused-fields set
    /// generated from the trigger schema for the full contract: every populated
    /// affix trigger field must be rollable or explicitly excused.
    static let affixMagnitudeFieldNames: Set<String> = Set(affixMagnitudeFields.map(\.fieldName))
}

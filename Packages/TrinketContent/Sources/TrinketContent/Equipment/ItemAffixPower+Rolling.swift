import Foundation
import TrinketCore

public extension ItemAffixPower {
    /// Modifiers precede trigger fields in catalog order, preserving seeded rolls
    /// and corruption selection. Description bindings use that same order.
    private var magnitudes: some Collection<(target: BumpTarget, value: AffixMagnitude)> {
        let modifierCount = modifiers.count
        let fields = CombatTraitTriggers.affixMagnitudeFields
        return (0 ..< modifierCount + fields.count).lazy.map { index -> (target: BumpTarget, value: AffixMagnitude) in
            if index < modifierCount {
                return (.modifier(index), Self.magnitude(of: self.modifiers[index]))
            }
            let fieldIndex = index - modifierCount
            return (.trigger(fieldIndex), fields[fieldIndex].magnitude(in: self.triggers))
        }
    }

    private static func magnitude(of modifier: AffixModifier) -> AffixMagnitude {
        if modifier.isPercent {
            return .percent(modifier.numericValue)
        }
        // Keep saved integer powers exact, including values above Double's precision.
        var amount = 0
        _ = modifier.mapInt {
            amount = $0
            return $0
        }
        return .int(amount)
    }

    private func magnitude(for target: BumpTarget) -> AffixMagnitude? {
        switch target {
        case let .modifier(index):
            modifiers.indices.contains(index) ? Self.magnitude(of: modifiers[index]) : nil
        case let .trigger(index):
            CombatTraitTriggers.affixMagnitudeFields[index].magnitude(in: triggers)
        }
    }

    private func transformingMagnitudes(
        rangeMultiplier: Int = 1,
        _ transform: (BumpTarget, AffixMagnitude) -> AffixMagnitude,
    ) -> Self {
        var modifiers = modifiers
        var triggers = triggers
        var text = AffixMagnitudeText(description)
        for (target, old) in magnitudes {
            let new = transform(target, old)
            if new != old {
                switch target {
                case let .modifier(index):
                    switch new {
                    case let .int(value): modifiers[index] = modifiers[index].mapInt { _ in value }
                    case let .percent(value): modifiers[index] = modifiers[index].mapPercent { _ in value }
                    }
                case let .trigger(index):
                    CombatTraitTriggers.affixMagnitudeFields[index].set(new, in: &triggers)
                }
            }
            // Unchanged fields still claim their text so later equal values
            // cannot overwrite them. Zero fields have no display magnitude.
            if !old.isZero || new != old {
                text.bind(old, to: new)
            }
        }
        return Self(
            description: text.rendered, modifiers: modifiers, triggers: triggers,
            triggerRollRanges: triggerRollRanges.mapValues {
                ($0.lowerBound * Double(rangeMultiplier)) ... ($0.upperBound * Double(rangeMultiplier))
            },
        )
    }

    func scaled(by multiplier: Int) -> Self {
        guard multiplier != 1 else { return self }
        return transformingMagnitudes(rangeMultiplier: multiplier) { _, value in
            value.map(percent: { $0 * Double(multiplier) }, int: { SaturatedArithmetic.saturatingMul($0, multiplier) })
        }
    }

    var hasRollableMagnitudes: Bool {
        magnitudes.contains { !$0.value.isZero }
    }

    func rolled(using randomNumberGenerator: inout some RandomNumberGenerator) -> Self {
        guard hasRollableMagnitudes else { return self }
        return transformingMagnitudes { target, value in
            guard !value.isZero else { return value }
            if let range = explicitRange(for: target) {
                return value.map(
                    percent: { _ in Double(Int.random(
                        in: Int((range.lowerBound * 100).rounded()) ... Int((range.upperBound * 100).rounded()),
                        using: &randomNumberGenerator,
                    )) / 100 },
                    int: { _ in Int.random(in: Int(range.lowerBound) ... Int(range.upperBound), using: &randomNumberGenerator) },
                )
            }
            return value.map(
                percent: { ItemAffixMagnitudeRoll.percentValues(around: $0).randomElement(using: &randomNumberGenerator) ?? $0 },
                int: { Int.random(in: ItemAffixMagnitudeRoll.integerRange(around: $0), using: &randomNumberGenerator) },
            )
        }
    }

    func rolledMin() -> Self {
        transformingMagnitudes { target, value in
            if let range = explicitRange(for: target) {
                return value.map(percent: { _ in range.lowerBound }, int: { _ in Int(range.lowerBound) })
            }
            return switch value {
            case let .int(amount): amount == 0 ? value : .int(ItemAffixMagnitudeRoll.integerRange(around: amount).lowerBound)
            case let .percent(amount): amount == 0 ? value : .percent(ItemAffixMagnitudeRoll.percentValues(around: amount).min() ?? amount)
            }
        }
    }

    func rolledMax() -> Self {
        guard hasRollableMagnitudes else { return self }
        return transformingMagnitudes { target, value in rollMaximum(value, for: target) }
    }

    /// Simulation-only magnitudes; callers compare matching affixes without trading off fields.
    internal func relativeMagnitudes(to reference: Self) -> [Double] {
        reference.magnitudes.compactMap { target, baseline in
            guard baseline.isPositive else { return nil }
            guard let actual = magnitude(for: target) else { return 0 }
            let ratio = actual.numericValue / baseline.numericValue
            return ratio.isFinite ? min(1000000, max(0, ratio)) : 0
        }
    }

    func isAtOrAboveRollMax(of catalog: Self) -> Bool {
        var hasRollableMagnitude = false
        for (target, value) in catalog.magnitudes where !value.isZero {
            hasRollableMagnitude = true
            guard let current = magnitude(for: target), current.isAtOrAbove(catalog.rollMaximum(value, for: target)) else { return false }
        }
        return hasRollableMagnitude
    }

    private func explicitRange(for target: BumpTarget) -> ClosedRange<Double>? {
        guard case let .trigger(index) = target else { return nil }
        guard let range = triggerRollRanges[CombatTraitTriggers.affixMagnitudeFields[index].field],
              range.lowerBound.isFinite, range.upperBound.isFinite,
              range.lowerBound > 0, range.upperBound < Double(Int.max) / 100 else { return nil }
        return range
    }

    private func rollMaximum(_ value: AffixMagnitude, for target: BumpTarget) -> AffixMagnitude {
        if let range = explicitRange(for: target) {
            return value.map(percent: { _ in range.upperBound }, int: { _ in Int(range.upperBound) })
        }
        return value.isZero ? value : value.rollMax
    }

    func hasBumpableField(direction: ItemAffixPowerBumpDirection) -> Bool {
        !bumpableMagnitudes(direction: direction).isEmpty
    }

    enum BumpTarget: Equatable, Sendable {
        case modifier(Int)
        case trigger(Int)
    }

    func bumpCandidates(direction: ItemAffixPowerBumpDirection) -> [BumpTarget] {
        bumpableMagnitudes(direction: direction).map(\.target)
    }

    private func bumpableMagnitudes(
        direction: ItemAffixPowerBumpDirection,
    ) -> some Collection<(target: BumpTarget, value: AffixMagnitude)> {
        magnitudes.lazy.filter { target, value in
            // Zero modifiers can be increased; inactive triggers cannot.
            if case .trigger = target, !value.isPositive {
                return false
            }
            return value.bumped(direction: direction) != nil
        }
    }

    func bumped(target: BumpTarget, direction: ItemAffixPowerBumpDirection) -> Self {
        transformingMagnitudes { candidate, value in
            candidate == target ? value.bumped(direction: direction) ?? value : value
        }
    }

    static func hasBumpableField(in powers: [ItemAffixPower], direction: ItemAffixPowerBumpDirection) -> Bool {
        powers.contains { $0.hasBumpableField(direction: direction) }
    }
}

public enum ItemAffixPowerBumpDirection: Equatable, Sendable {
    case up
    case down
}

public enum ItemAffixMagnitudeRoll: Sendable {
    public static func integerRange(around value: Int) -> ClosedRange<Int> {
        let delta = max(1, value / 4)
        let lower = max(1, SaturatedArithmetic.saturatingSub(value, delta))
        return lower ... max(lower, SaturatedArithmetic.saturatingAdd(value, delta))
    }

    public static func percentValues(around value: Double) -> [Double] {
        percentPoints(around: value)?.map { Double($0) / 100 } ?? [value]
    }

    fileprivate static func percentMaximum(around value: Double) -> Double {
        guard let bounds = percentPointBounds(around: value) else { return value }
        let last = bounds.start + (bounds.upper - bounds.start) / bounds.step * bounds.step
        return Double(last) / 100
    }

    private static func percentPoints(around value: Double) -> StrideThrough<Int>? {
        guard let bounds = percentPointBounds(around: value) else { return nil }
        return stride(from: bounds.start, through: bounds.upper, by: bounds.step)
    }

    private static func percentPointBounds(around value: Double) -> (start: Int, upper: Int, step: Int)? {
        let roundedPoints = (value * 100).rounded()
        // Preserve oversized powers instead of trapping or allocating an unbounded roll pool.
        guard roundedPoints.isFinite, roundedPoints >= 0, roundedPoints < Double(Int.max) else { return nil }
        let points = Int(roundedPoints)
        let delta = max(1, points / 4)
        let lower = max(1, points - delta)
        let (upper, overflow) = points.addingReportingOverflow(delta)
        guard !overflow else { return nil }
        let step = delta < 5 ? 1 : 5
        guard (upper - lower) / step <= 4095 else { return nil }
        let start = points - ((points - lower) / step) * step
        return (start, upper, step)
    }
}

private enum AffixMagnitude: Equatable {
    case int(Int)
    case percent(Double)

    var isZero: Bool {
        self == .int(0) || self == .percent(0)
    }

    var isPositive: Bool {
        switch self {
        case let .int(value): value > 0
        case let .percent(value): value > 0
        }
    }

    var numericValue: Double {
        switch self {
        case let .int(value): Double(value)
        case let .percent(value): value
        }
    }

    var text: String {
        switch self {
        case let .int(value): "\(value)"
        case let .percent(value): "\(CombatRounding.wholePercent(value))%"
        }
    }

    func map(percent: (Double) -> Double, int: (Int) -> Int) -> Self {
        switch self {
        case let .int(value): .int(int(value))
        case let .percent(value): .percent(percent(value))
        }
    }

    var rollMax: Self {
        map(
            percent: { ItemAffixMagnitudeRoll.percentMaximum(around: $0) },
            int: { ItemAffixMagnitudeRoll.integerRange(around: $0).upperBound },
        )
    }

    func isAtOrAbove(_ other: Self) -> Bool {
        switch (self, other) {
        case let (.int(value), .int(maximum)): value >= maximum
        case let (.percent(value), .percent(maximum)): value + 1e-9 >= maximum
        default: false
        }
    }

    func bumped(direction: ItemAffixPowerBumpDirection) -> Self? {
        switch self {
        case let .int(value):
            guard direction == .up || value > 1 else { return nil }
            let bumped = SaturatedArithmetic.saturatingAdd(value, direction == .up ? 1 : -1)
            return bumped != value ? .int(bumped) : nil
        case let .percent(value):
            guard value.isFinite, direction == .up || value > 0.01 + 1e-9 else { return nil }
            let bumped = value + (direction == .up ? 0.01 : -0.01)
            return bumped.isFinite && bumped != value ? .percent(bumped) : nil
        }
    }
}

/// Claims ranges in the original description, then applies edits back to front.
/// Rolled values never become search input for another field.
private struct AffixMagnitudeText {
    let original: String
    var bindings: [(range: Range<String.Index>, replacement: String?)] = []

    init(_ original: String) {
        self.original = original
    }

    mutating func bind(_ old: AffixMagnitude, to new: AffixMagnitude) {
        let pattern: String
        switch old {
        case let .int(value):
            let quantity = value == 1 ? "(?:a|1)" : old.text
            let suffix = value == 1 ? "" : "s"
            pattern = "(?<!\\d)(?:\\b\(quantity) (?:buff|debuff)\(suffix)\\b|\(old.text)(?![\\d%]))"
        case .percent:
            pattern = "(?<!\\d)\(old.text)(?!\\d| Health)"
        }
        var start = original.startIndex
        while let range = original.range(of: pattern, options: .regularExpression, range: start ..< original.endIndex) {
            start = range.upperBound
            guard !bindings.contains(where: { $0.range.overlaps(range) }) else { continue }
            let matched = original[range]
            let replacement: String?
            if new == old {
                replacement = nil
            } else if case .int = old, matched.contains("buff") {
                let noun = matched.contains("debuff") ? "debuff" : "buff"
                replacement = new == .int(1) ? "a \(noun)" : "\(new.text) \(noun)s"
            } else {
                replacement = new.text
            }
            bindings.append((range, replacement))
            return
        }
    }

    var rendered: String {
        var result = original
        for (range, replacement) in bindings.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            guard let replacement else { continue }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}

extension CombatTraitTriggers {
    enum AffixMagnitudeField: Sendable {
        case int(WritableKeyPath<CombatTraitTriggers, Int> & Sendable, field: CombatTriggerField)
        case percent(WritableKeyPath<CombatTraitTriggers, Double> & Sendable, field: CombatTriggerField)

        var field: CombatTriggerField {
            switch self {
            case let .int(_, field), let .percent(_, field): field
            }
        }

        fileprivate func magnitude(in triggers: CombatTraitTriggers) -> AffixMagnitude {
            switch self {
            case let .int(keyPath, _): .int(triggers[keyPath: keyPath])
            case let .percent(keyPath, _): .percent(triggers[keyPath: keyPath])
            }
        }

        fileprivate func set(_ magnitude: AffixMagnitude, in triggers: inout CombatTraitTriggers) {
            switch (self, magnitude) {
            case let (.int(keyPath, _), .int(value)): triggers[keyPath: keyPath] = value
            case let (.percent(keyPath, _), .percent(value)): triggers[keyPath: keyPath] = value
            default: preconditionFailure("Affix transformations must preserve magnitude kind")
            }
        }
    }
}

public extension CombatTraitTriggers {
    /// Every populated affix trigger field must be rollable or explicitly excused.
    static let affixMagnitudeFieldIDs: Set<CombatTriggerField> = Set(affixMagnitudeFields.lazy.map(\.field))
}

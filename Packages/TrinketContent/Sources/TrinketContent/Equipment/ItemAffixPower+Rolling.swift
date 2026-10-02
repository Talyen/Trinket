import Foundation

public extension ItemAffixPower {
    /// Modifiers precede trigger fields in catalog order, preserving seeded rolls
    /// and corruption selection. Description bindings use that same order.
    private var magnitudes: [(target: BumpTarget, value: AffixMagnitude)] {
        modifiers.enumerated().map { index, modifier in
            (
                .modifier(index),
                modifier.isPercent
                    ? .percent(modifier.numericValue) : .int(Int(modifier.numericValue.rounded())),
            )
        } + CombatTraitTriggers.affixMagnitudeFields.enumerated().map { index, field in
            (.trigger(index), field.magnitude(in: triggers))
        }
    }

    private func transformingMagnitudes(
        _ transform: (BumpTarget, AffixMagnitude) -> AffixMagnitude,
    ) -> Self {
        var modifiers = modifiers
        var triggers = triggers
        var text = AffixMagnitudeText(description)
        for (target, old) in magnitudes {
            let new = transform(target, old)
            switch target {
            case let .modifier(index):
                switch new {
                case let .int(value): modifiers[index] = modifiers[index].mapInt { _ in value }
                case let .percent(value): modifiers[index] = modifiers[index].mapPercent { _ in value }
                }
            case let .trigger(index):
                CombatTraitTriggers.affixMagnitudeFields[index].set(new, in: &triggers)
            }
            // Unchanged fields still claim their text so later equal values
            // cannot overwrite them. Zero fields have no display magnitude.
            if !old.isZero || new != old {
                text.bind(old, to: new)
            }
        }
        return Self(description: text.rendered, modifiers: modifiers, triggers: triggers)
    }

    func scaled(by multiplier: Int) -> Self {
        guard multiplier != 1 else { return self }
        return transformingMagnitudes { _, value in
            value.map(percent: { $0 * Double(multiplier) }, int: { $0 * multiplier })
        }
    }

    var hasRollableMagnitudes: Bool {
        magnitudes.contains { !$0.value.isZero }
    }

    func rolled(using randomNumberGenerator: inout some RandomNumberGenerator) -> Self {
        guard hasRollableMagnitudes else { return self }
        return transformingMagnitudes { _, value in
            guard !value.isZero else { return value }
            return value.map(
                percent: { ItemAffixMagnitudeRoll.percentValues(around: $0).randomElement(using: &randomNumberGenerator) ?? $0 },
                int: { Int.random(in: ItemAffixMagnitudeRoll.integerRange(around: $0), using: &randomNumberGenerator) },
            )
        }
    }

    func rolledMax() -> Self {
        guard hasRollableMagnitudes else { return self }
        return transformingMagnitudes { _, value in value.isZero ? value : value.rollMax }
    }

    func isAtOrAboveRollMax(of catalog: Self) -> Bool {
        guard catalog.hasRollableMagnitudes else { return false }
        let actual = magnitudes
        return catalog.magnitudes.allSatisfy { target, value in
            guard !value.isZero else { return true }
            guard let current = actual.first(where: { $0.target.matches(target) })?.value else { return false }
            return current.isAtOrAbove(value.rollMax)
        }
    }

    func hasBumpableField(direction: ItemAffixPowerBumpDirection) -> Bool {
        !bumpCandidates(direction: direction).isEmpty
    }

    enum BumpTarget: Sendable {
        case modifier(Int)
        case trigger(Int)

        fileprivate func matches(_ other: Self) -> Bool {
            switch (self, other) {
            case let (.modifier(lhs), .modifier(rhs)), let (.trigger(lhs), .trigger(rhs)): lhs == rhs
            default: false
            }
        }
    }

    func bumpCandidates(direction: ItemAffixPowerBumpDirection) -> [BumpTarget] {
        magnitudes.compactMap { target, value in
            // Zero modifiers can be increased; inactive triggers cannot.
            if case .trigger = target, !value.isPositive {
                return nil
            }
            return value.bumped(direction: direction) == nil ? nil : target
        }
    }

    func bumped(target: BumpTarget, direction: ItemAffixPowerBumpDirection) -> Self {
        transformingMagnitudes { candidate, value in
            candidate.matches(target) ? value.bumped(direction: direction) ?? value : value
        }
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
        let candidates = powers.enumerated().flatMap { index, power in
            power.bumpCandidates(direction: direction).map { (powerIndex: index, target: $0) }
        }
        guard let pick = candidates.randomElement(using: &randomNumberGenerator) else { return nil }
        powers[pick.powerIndex] = powers[pick.powerIndex].bumped(target: pick.target, direction: direction)
        let title = GameContent.itemAffixDefinition(matching: affixIDs[pick.powerIndex])?.title
            ?? affixIDs[pick.powerIndex]
        return (title, pick.powerIndex)
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

    var text: String {
        switch self {
        case let .int(value): "\(value)"
        case let .percent(value): "\(Int((value * 100).rounded()))%"
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
            percent: { ItemAffixMagnitudeRoll.percentValues(around: $0).max() ?? $0 },
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
            direction == .up || value > 1 ? .int(value + direction.intDelta) : nil
        case let .percent(value):
            direction == .up || value > 0.01 + 1e-9 ? .percent(value + direction.percentDelta) : nil
        }
    }
}

/// Claims ranges in the original description, then applies edits back to front.
/// Rolled values never become search input for another field.
private struct AffixMagnitudeText {
    let original: String
    var bindings: [(range: Range<String.Index>, replacement: String)] = []

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
            let replacement: String
            if new == old {
                replacement = String(matched)
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
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}

extension CombatTraitTriggers {
    enum AffixMagnitudeField: Sendable {
        case int(WritableKeyPath<CombatTraitTriggers, Int> & Sendable, name: String)
        case percent(WritableKeyPath<CombatTraitTriggers, Double> & Sendable, name: String)

        var fieldName: String {
            switch self {
            case let .int(_, name), let .percent(_, name): name
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
    static let affixMagnitudeFieldNames: Set<String> = Set(affixMagnitudeFields.map(\.fieldName))
}

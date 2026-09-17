import Foundation

public extension ItemAffixPower {
    /// Single traversal behind scaled/rolled/rolledMax: maps every nonzero
    /// modifier magnitude and reports each change for description patching.
    /// Unchanged values skip patching (patching X to X is identity).
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
        var description = description
        let record: (Double, Double, Bool) -> Void = { old, new, isPercent in
            description = Self.replacingMagnitude(
                in: description,
                from: old,
                to: new,
                isPercent: isPercent,
            )
        }
        let scaledModifiers = mapModifierMagnitudes(
            percent: { $0 * Double(multiplier) },
            int: { $0 * multiplier },
            record: record,
        )
        let scaledTriggers = triggers.scalingAffixMagnitudes(by: multiplier, record: record)
        return Self(description: description, modifiers: scaledModifiers, triggers: scaledTriggers)
    }

    var hasRollableMagnitudes: Bool {
        modifiers.contains { $0.numericValue != 0 } || triggers.hasRollableAffixMagnitudes
    }

    func rolled(using randomNumberGenerator: inout some RandomNumberGenerator) -> Self {
        guard hasRollableMagnitudes else { return self }
        var description = description
        let record: (Double, Double, Bool) -> Void = { old, new, isPercent in
            description = Self.replacingMagnitude(
                in: description,
                from: old,
                to: new,
                isPercent: isPercent,
            )
        }
        let rolledModifiers = mapModifierMagnitudes(
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
            record: record,
        )
        let rolledTriggers = triggers.rollingAffixMagnitudes(using: &randomNumberGenerator, record: record)
        return Self(description: description, modifiers: rolledModifiers, triggers: rolledTriggers)
    }

    func rolledMax() -> Self {
        guard hasRollableMagnitudes else { return self }
        var description = description
        let record: (Double, Double, Bool) -> Void = { old, new, isPercent in
            description = Self.replacingMagnitude(
                in: description,
                from: old,
                to: new,
                isPercent: isPercent,
            )
        }
        let maxedModifiers = mapModifierMagnitudes(
            percent: { ItemAffixMagnitudeRoll.percentValues(around: $0).max() ?? $0 },
            int: { ItemAffixMagnitudeRoll.integerRange(around: $0).upperBound },
            record: record,
        )
        let maxedTriggers = triggers.maxRolledAffixMagnitudes(record: record)
        return Self(description: description, modifiers: maxedModifiers, triggers: maxedTriggers)
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
        return choices.sorted().map { Double($0) / 100 }
    }
}

private extension CombatTraitTriggers {
    mutating func scale(
        _ keyPath: WritableKeyPath<Self, Int>,
        by multiplier: Int,
        record: (Double, Double, Bool) -> Void,
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
        record: (Double, Double, Bool) -> Void,
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
            case let .int(keyPath, _):
                self[keyPath: keyPath] != 0
            case let .percent(keyPath, _):
                self[keyPath: keyPath] != 0
            }
        }
    }

    func scalingAffixMagnitudes(
        by multiplier: Int,
        record: (Double, Double, Bool) -> Void,
    ) -> Self {
        var scaled = self
        for field in Self.affixMagnitudeFields {
            switch field {
            case let .int(keyPath, _):
                scaled.scale(keyPath, by: multiplier, record: record)
            case let .percent(keyPath, _):
                scaled.scale(keyPath, by: multiplier, record: record)
            }
        }
        return scaled
    }

    func rollingAffixMagnitudes(
        using randomNumberGenerator: inout some RandomNumberGenerator,
        record: (Double, Double, Bool) -> Void,
    ) -> Self {
        var rolled = self
        for field in Self.affixMagnitudeFields {
            switch field {
            case let .int(keyPath, _):
                let old = rolled[keyPath: keyPath]
                guard old != 0 else { continue }
                let new = Int.random(
                    in: ItemAffixMagnitudeRoll.integerRange(around: old),
                    using: &randomNumberGenerator,
                )
                rolled[keyPath: keyPath] = new
                record(Double(old), Double(new), false)
            case let .percent(keyPath, _):
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

    func maxRolledAffixMagnitudes(
        record: (Double, Double, Bool) -> Void,
    ) -> Self {
        var maxed = self
        for field in Self.affixMagnitudeFields {
            switch field {
            case let .int(keyPath, _):
                let old = maxed[keyPath: keyPath]
                guard old != 0 else { continue }
                let new = ItemAffixMagnitudeRoll.integerRange(around: old).upperBound
                guard new != old else { continue }
                maxed[keyPath: keyPath] = new
                record(Double(old), Double(new), false)
            case let .percent(keyPath, _):
                let old = maxed[keyPath: keyPath]
                guard old != 0 else { continue }
                let new = ItemAffixMagnitudeRoll.percentValues(around: old).max() ?? old
                guard abs(new - old) > 1e-9 else { continue }
                maxed[keyPath: keyPath] = new
                record(old, new, true)
            }
        }
        return maxed
    }

    func hasBumpableAffixMagnitude(direction: ItemAffixPowerBumpDirection) -> Bool {
        Self.affixMagnitudeFields.contains { field in
            field.canBump(in: self, direction: direction)
        }
    }

    func affixMagnitudesAreAtOrAboveRollMax(of catalog: Self) -> Bool {
        for field in Self.affixMagnitudeFields {
            switch field {
            case let .int(keyPath, _):
                let catalogValue = catalog[keyPath: keyPath]
                guard catalogValue != 0 else { continue }
                let maximum = ItemAffixMagnitudeRoll.integerRange(around: catalogValue).upperBound
                if self[keyPath: keyPath] < maximum {
                    return false
                }
            case let .percent(keyPath, _):
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

    enum AffixMagnitudeField: Sendable {
        case int(WritableKeyPath<CombatTraitTriggers, Int> & Sendable, name: String)
        case percent(WritableKeyPath<CombatTraitTriggers, Double> & Sendable, name: String)

        var fieldName: String {
            switch self {
            case let .int(_, name), let .percent(_, name):
                name
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

    static let affixMagnitudeFields: [AffixMagnitudeField] = [
        .int(\.cleanseSelfHeal, name: "cleanseSelfHeal"),
        .int(\.gainGoldBonusHealSelf, name: "gainGoldBonusHealSelf"),
        .percent(\.thornsPercent, name: "thornsPercent"),
        .int(\.onBleedApplyPoison, name: "onBleedApplyPoison"),
        .int(\.onBurnApplyPoison, name: "onBurnApplyPoison"),
        .int(\.onBleedDealBurnDamage, name: "onBleedDealBurnDamage"),
        .percent(\.poisonDecayIncreaseChance, name: "poisonDecayIncreaseChance"),
        .int(\.freezeDamageWhileBurningBonus, name: "freezeDamageWhileBurningBonus"),
        .int(\.damageWhileTargetFrozenBonus, name: "damageWhileTargetFrozenBonus"),
        .int(\.damageBelowHealthPercentBonus, name: "damageBelowHealthPercentBonus"),
        .int(\.damageAfterDodgeBonus, name: "damageAfterDodgeBonus"),
        .int(\.blockBrokenBlockFlat, name: "blockBrokenBlockFlat"),
        .percent(\.companionLeechSharePercent, name: "companionLeechSharePercent"),
        .int(\.onceBelowHealthPercentHeal, name: "onceBelowHealthPercentHeal"),
        .int(\.blockOnDeathsDoor, name: "blockOnDeathsDoor"),
        .int(\.spendManaBlockFlat, name: "spendManaBlockFlat"),
        .int(\.holyDamageBlockFlat, name: "holyDamageBlockFlat"),
        .int(\.holyDamageCleanseCount, name: "holyDamageCleanseCount"),
        .int(\.holyDamageHealFlat, name: "holyDamageHealFlat"),
        .int(\.dodgeGoldFlat, name: "dodgeGoldFlat"),
        .percent(\.ignoreEnemyMitigationPercent, name: "ignoreEnemyMitigationPercent"),
        .percent(\.physicalIgnoreMitigationPercent, name: "physicalIgnoreMitigationPercent"),
        .int(\.stunDealPhysicalFlat, name: "stunDealPhysicalFlat"),
        .int(\.damageWhileTargetStunnedBonus, name: "damageWhileTargetStunnedBonus"),
        .int(\.dodgeBlockFlat, name: "dodgeBlockFlat"),
        .int(\.holyDamagePurgeCount, name: "holyDamagePurgeCount"),
        .int(\.enemyStunnedPurgeCount, name: "enemyStunnedPurgeCount"),
        .int(\.criticalPurgeCount, name: "criticalPurgeCount"),
        .int(\.criticalActionGoldFlat, name: "criticalActionGoldFlat"),
        .int(\.leechRestoreManaFlat, name: "leechRestoreManaFlat"),
        .int(\.gainManaBlockFlat, name: "gainManaBlockFlat"),
        .int(\.defeatEnemyGoldFlat, name: "defeatEnemyGoldFlat"),
        .int(\.leechGoldFlat, name: "leechGoldFlat"),
        .int(\.dodgeHealFlat, name: "dodgeHealFlat"),
        .percent(\.dodgeChanceBelowHealthPercentBonus, name: "dodgeChanceBelowHealthPercentBonus"),
        .int(\.dodgeDealStunFlat, name: "dodgeDealStunFlat"),
        .percent(\.dodgeChanceBonus, name: "dodgeChanceBonus"),
        .int(\.holyDamagePoisonFlat, name: "holyDamagePoisonFlat"),
        .int(\.drawEveryOtherTurn, name: "drawEveryOtherTurn"),
        .int(\.drawOnHealthLoss, name: "drawOnHealthLoss"),
        .percent(\.physicalStunBuildupPercent, name: "physicalStunBuildupPercent"),
        .percent(\.blockGainThornsPercent, name: "blockGainThornsPercent"),
        .int(\.drawOnSpendMana, name: "drawOnSpendMana"),
        .percent(\.physicalDamageBlockPercent, name: "physicalDamageBlockPercent"),
        .int(\.bleedDamageGoldFlat, name: "bleedDamageGoldFlat"),
        .int(\.goldPerTurn, name: "goldPerTurn"),
        .percent(\.healthRestoredPoisonPercent, name: "healthRestoredPoisonPercent"),
        .int(\.cardsPlayedManaFlat, name: "cardsPlayedManaFlat"),
        .int(\.victoryGoldFlat, name: "victoryGoldFlat"),
        .int(\.healthPerTurn, name: "healthPerTurn"),
        .int(\.companionCardsPerTurn, name: "companionCardsPerTurn"),
        .int(\.freezeExtraActionSkips, name: "freezeExtraActionSkips"),
        .percent(\.criticalChanceBonus, name: "criticalChanceBonus"),
        // BumpTarget.trigger indexes this array ephemerally during a single roll.
        .percent(\.onBleedDealPoisonChancePercent, name: "onBleedDealPoisonChancePercent"),
        .percent(\.onBurnDealPoisonChancePercent, name: "onBurnDealPoisonChancePercent"),
        .percent(\.onBleedDealBurnChancePercent, name: "onBleedDealBurnChancePercent"),
        .percent(\.stunExtendChancePercent, name: "stunExtendChancePercent"),
        .percent(\.freezeExtendChancePercent, name: "freezeExtendChancePercent"),
        .percent(\.freezeDamageLeechChancePercent, name: "freezeDamageLeechChancePercent"),
    ]
}

public extension CombatTraitTriggers {
    /// Names of rollable trigger magnitudes. Pair with the excused-fields set
    /// in ItemAffixRollCoverageTests for the full contract: every populated
    /// affix trigger field must be rollable or explicitly excused.
    static var affixMagnitudeFieldNames: Set<String> {
        Set(affixMagnitudeFields.map(\.fieldName))
    }
}

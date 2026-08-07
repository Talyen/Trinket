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

    private enum Target: Equatable {
        case modifier(Int)
        case trigger(TriggerField)
    }

    private enum TriggerField: Equatable {
        case onBleedApplyPoison
        case onBurnApplyPoison
        case onBleedDealBurnDamage
        case poisonDecayIncreaseChance
        case damageWhileTargetFrozenBonus
        case damageBelowHealthPercentBonus
        case damageAfterDodgeBonus
        case blockBrokenBlockFlat
        case companionLeechSharePercent
        case onceBelowHealthPercentHeal
        case blockOnDeathsDoor
        case spendManaBlockFlat
        case freezeDamageWhileBurningBonus
    }

    private static func bumpTargets(in power: ItemAffixPower, direction: Direction) -> [Target] {
        var targets: [Target] = []
        for (index, modifier) in power.modifiers.enumerated() where canBump(modifier, direction: direction) {
            targets.append(.modifier(index))
        }
        let triggers = power.triggers
        let triggerFields: [(TriggerField, Bool)] = [
            (.onBleedApplyPoison, canBumpInt(triggers.onBleedApplyPoison, direction: direction)),
            (.onBurnApplyPoison, canBumpInt(triggers.onBurnApplyPoison, direction: direction)),
            (.onBleedDealBurnDamage, canBumpInt(triggers.onBleedDealBurnDamage, direction: direction)),
            (.poisonDecayIncreaseChance, canBumpPercent(triggers.poisonDecayIncreaseChance, direction: direction)),
            (.damageWhileTargetFrozenBonus, canBumpInt(triggers.damageWhileTargetFrozenBonus, direction: direction)),
            (.damageBelowHealthPercentBonus, canBumpInt(triggers.damageBelowHealthPercentBonus, direction: direction)),
            (.damageAfterDodgeBonus, canBumpInt(triggers.damageAfterDodgeBonus, direction: direction)),
            (.blockBrokenBlockFlat, canBumpInt(triggers.blockBrokenBlockFlat, direction: direction)),
            (.companionLeechSharePercent, canBumpPercent(triggers.companionLeechSharePercent, direction: direction)),
            (.onceBelowHealthPercentHeal, canBumpInt(triggers.onceBelowHealthPercentHeal, direction: direction)),
            (.blockOnDeathsDoor, canBumpInt(triggers.blockOnDeathsDoor, direction: direction)),
            (.spendManaBlockFlat, canBumpInt(triggers.spendManaBlockFlat, direction: direction)),
            (.freezeDamageWhileBurningBonus, canBumpInt(triggers.freezeDamageWhileBurningBonus, direction: direction)),
        ]
        for (field, ok) in triggerFields where ok {
            targets.append(.trigger(field))
        }
        return targets
    }

    private static func apply(target: Target, to power: ItemAffixPower, direction: Direction) -> ItemAffixPower {
        var modifiers = power.modifiers
        var triggers = power.triggers
        var description = power.description

        switch target {
        case let .modifier(index):
            let old = modifiers[index]
            let new = bump(old, direction: direction)
            modifiers[index] = new
            description = rewrittenDescription(description, from: old, to: new)
        case let .trigger(field):
            description = bumpTrigger(field, triggers: &triggers, direction: direction, description: description)
        }

        return ItemAffixPower(description: description, modifiers: modifiers, triggers: triggers)
    }

    private static func canBump(_ modifier: AffixModifier, direction: Direction) -> Bool {
        switch numericKind(of: modifier) {
        case let .int(value):
            canBumpInt(value, direction: direction)
        case let .percent(value):
            canBumpPercent(value, direction: direction)
        }
    }

    private enum NumericKind {
        case int(Int)
        case percent(Double)
    }

    private static func numericKind(of modifier: AffixModifier) -> NumericKind {
        switch modifier {
        case let .strength(v), let .agility(v), let .toughness(v), let .intellect(v), let .wisdom(v),
             let .maximumHealth(v), let .maximumMana(v), let .healthRestored(v), let .leechHealing(v),
             let .goldGained(v), let .blockGained(v), let .leechDuration(v), let .bleedDuration(v),
             let .companionDamageDealt(v):
            .int(v)
        case let .damageDealt(_, v), let .damageTakenFlat(_, v):
            .int(v)
        case let .poisonDamageDealtPercent(v), let .leechGainedPercent(v), let .goldGainedPercent(v),
             let .manaCostReductionPercent(v):
            .percent(v)
        case let .damageTakenPercent(_, v), let .damageTakenVulnerability(_, v):
            .percent(v)
        }
    }

    private static func bump(_ modifier: AffixModifier, direction: Direction) -> AffixModifier {
        let delta = direction == .up ? 1 : -1
        let percentDelta = direction == .up ? 0.01 : -0.01
        return mapNumeric(modifier, intDelta: delta, percentDelta: percentDelta)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func mapNumeric(
        _ modifier: AffixModifier,
        intDelta: Int,
        percentDelta: Double
    ) -> AffixModifier {
        switch modifier {
        case let .strength(v): .strength(v + intDelta)
        case let .agility(v): .agility(v + intDelta)
        case let .toughness(v): .toughness(v + intDelta)
        case let .intellect(v): .intellect(v + intDelta)
        case let .wisdom(v): .wisdom(v + intDelta)
        case let .maximumHealth(v): .maximumHealth(v + intDelta)
        case let .maximumMana(v): .maximumMana(v + intDelta)
        case let .damageDealt(k, v): .damageDealt(k, v + intDelta)
        case let .poisonDamageDealtPercent(v): .poisonDamageDealtPercent(v + percentDelta)
        case let .healthRestored(v): .healthRestored(v + intDelta)
        case let .leechGainedPercent(v): .leechGainedPercent(v + percentDelta)
        case let .leechHealing(v): .leechHealing(v + intDelta)
        case let .goldGained(v): .goldGained(v + intDelta)
        case let .goldGainedPercent(v): .goldGainedPercent(v + percentDelta)
        case let .blockGained(v): .blockGained(v + intDelta)
        case let .leechDuration(v): .leechDuration(v + intDelta)
        case let .bleedDuration(v): .bleedDuration(v + intDelta)
        case let .damageTakenPercent(k, v): .damageTakenPercent(k, v + percentDelta)
        case let .damageTakenFlat(k, v): .damageTakenFlat(k, v + intDelta)
        case let .damageTakenVulnerability(k, v): .damageTakenVulnerability(k, v + percentDelta)
        case let .companionDamageDealt(v): .companionDamageDealt(v + intDelta)
        case let .manaCostReductionPercent(v): .manaCostReductionPercent(v + percentDelta)
        }
    }

    // swiftlint:disable:next function_body_length
    private static func bumpTrigger(
        _ field: TriggerField,
        triggers: inout CombatTraitTriggers,
        direction: Direction,
        description: String
    ) -> String {
        let delta = direction == .up ? 1 : -1
        let percentDelta = direction == .up ? 0.01 : -0.01
        switch field {
        case .onBleedApplyPoison:
            return bumpIntField(
                &triggers.onBleedApplyPoison,
                delta: delta,
                description: description
            )
        case .onBurnApplyPoison:
            return bumpIntField(
                &triggers.onBurnApplyPoison,
                delta: delta,
                description: description
            )
        case .onBleedDealBurnDamage:
            return bumpIntField(
                &triggers.onBleedDealBurnDamage,
                delta: delta,
                description: description
            )
        case .poisonDecayIncreaseChance:
            return bumpPercentField(
                &triggers.poisonDecayIncreaseChance,
                delta: percentDelta,
                description: description
            )
        case .damageWhileTargetFrozenBonus:
            return bumpIntField(
                &triggers.damageWhileTargetFrozenBonus,
                delta: delta,
                description: description
            )
        case .damageBelowHealthPercentBonus:
            return bumpIntField(
                &triggers.damageBelowHealthPercentBonus,
                delta: delta,
                description: description
            )
        case .damageAfterDodgeBonus:
            return bumpIntField(
                &triggers.damageAfterDodgeBonus,
                delta: delta,
                description: description
            )
        case .blockBrokenBlockFlat:
            return bumpIntField(
                &triggers.blockBrokenBlockFlat,
                delta: delta,
                description: description
            )
        case .companionLeechSharePercent:
            return bumpPercentField(
                &triggers.companionLeechSharePercent,
                delta: percentDelta,
                description: description
            )
        case .onceBelowHealthPercentHeal:
            return bumpIntField(
                &triggers.onceBelowHealthPercentHeal,
                delta: delta,
                description: description
            )
        case .blockOnDeathsDoor:
            return bumpIntField(
                &triggers.blockOnDeathsDoor,
                delta: delta,
                description: description
            )
        case .spendManaBlockFlat:
            return bumpIntField(
                &triggers.spendManaBlockFlat,
                delta: delta,
                description: description
            )
        case .freezeDamageWhileBurningBonus:
            return bumpIntField(
                &triggers.freezeDamageWhileBurningBonus,
                delta: delta,
                description: description
            )
        }
    }

    private static func bumpIntField(
        _ value: inout Int,
        delta: Int,
        description: String
    ) -> String {
        let old = value
        value = old + delta
        return rewriteInt(description, from: old, to: old + delta)
    }

    private static func bumpPercentField(
        _ value: inout Double,
        delta: Double,
        description: String
    ) -> String {
        let old = value
        value = old + delta
        return rewritePercent(description, from: old, to: old + delta)
    }

    private static func canBumpInt(_ value: Int, direction: Direction) -> Bool {
        switch direction {
        case .up: true
        case .down: value > 1
        }
    }

    private static func canBumpPercent(_ value: Double, direction: Direction) -> Bool {
        switch direction {
        case .up: true
        case .down: value > 0.01 + 1e-9
        }
    }

    private static func rewrittenDescription(
        _ description: String,
        from old: AffixModifier,
        to new: AffixModifier
    ) -> String {
        switch (numericKind(of: old), numericKind(of: new)) {
        case let (.int(o), .int(n)):
            rewriteInt(description, from: o, to: n)
        case let (.percent(o), .percent(n)):
            rewritePercent(description, from: o, to: n)
        default:
            description
        }
    }

    private static func rewriteInt(_ description: String, from old: Int, to new: Int) -> String {
        guard old != new else { return description }
        return description.replacingOccurrences(of: "\(old)", with: "\(new)")
    }

    private static func rewritePercent(_ description: String, from old: Double, to new: Double) -> String {
        let oldPct = Int((old * 100).rounded())
        let newPct = Int((new * 100).rounded())
        if description.contains("\(oldPct)%") {
            return description.replacingOccurrences(of: "\(oldPct)%", with: "\(newPct)%")
        }
        return rewriteInt(description, from: oldPct, to: newPct)
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

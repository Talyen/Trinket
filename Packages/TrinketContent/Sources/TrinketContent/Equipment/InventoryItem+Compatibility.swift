import Foundation
import TrinketCore

extension InventoryItem {
    static func normalizedPower(_ original: ItemAffixPower, affixID: String) -> ItemAffixPower {
        var power = original
        switch affixID {
        case "companions_collar":
            power = Self.normalizedLoyalCompanion(power)
        case "beastbond":
            power = Self.normalizedBeastbond(power)
        case "shredding":
            power = Self.normalizedShredding(power)
        case "tattered_pages":
            power = Self.normalizedForbiddenKnowledge(power)
        case "the_patient_edge":
            power = Self.normalizedPatientEdge(power)
        default:
            break
        }
        return power
    }

    private static func normalizedLoyalCompanion(_ power: ItemAffixPower) -> ItemAffixPower {
        if power.triggers.healCompanionDrawsCompanionCard {
            if power.description == "Once per turn, healing your Companion draws a Companion card." {
                return power
            }
            return ItemAffixPower(
                description: "Once per turn, healing your Companion draws a Companion card.",
                modifiers: power.modifiers,
                triggers: power.triggers,
            )
        }
        // Migrate older per-turn and every-other-turn draw fields to the heal-draw rule.
        if power.triggers.companionCardsEveryOtherTurn > 0 || power.triggers.companionCardsPerTurn > 0 {
            var triggers = power.triggers
            triggers.healCompanionDrawsCompanionCard = true
            triggers.companionCardsEveryOtherTurn = 0
            triggers.companionCardsPerTurn = 0
            return ItemAffixPower(
                description: "Once per turn, healing your Companion draws a Companion card.",
                modifiers: power.modifiers,
                triggers: triggers,
            )
        }
        return power
    }

    private static func normalizedBeastbond(_ power: ItemAffixPower) -> ItemAffixPower {
        var modifiers = power.modifiers
        var oldValue: Int?
        if let index = modifiers.firstIndex(where: {
            if case .companionDamageDealt = $0 {
                return true
            }
            return false
        }) {
            if case let .companionDamageDealt(value) = modifiers[index] {
                oldValue = value
            }
            modifiers.removeAll {
                if case .companionDamageDealt = $0 {
                    return true
                }
                return false
            }
        }
        var newValue: Int?
        for modifier in modifiers {
            if case let .companionPhysicalDamageDealt(value) = modifier {
                newValue = value
                break
            }
        }
        let actual = newValue ?? oldValue
        guard let actual else { return power }
        if newValue == nil {
            modifiers.append(.companionPhysicalDamageDealt(actual))
        }
        let description = "Increase your Companion's Physical damage by \(actual)."
        if modifiers == power.modifiers, power.description == description {
            return power
        }
        return ItemAffixPower(description: description, modifiers: modifiers, triggers: power.triggers)
    }

    private static func normalizedShredding(_ power: ItemAffixPower) -> ItemAffixPower {
        var triggers = power.triggers
        let old = triggers.ignoreEnemyMitigationPercent
        let new = triggers.physicalIgnoreMitigationPercent
        let actual = max(old, new)
        guard actual > 0 else { return power }
        let percentText = "\(Int((actual * 100).rounded()))%"
        let description = "Your Physical damage ignores \(percentText) of enemy damage reduction."
        if new >= old, power.description == description {
            return power
        }
        triggers.physicalIgnoreMitigationPercent = actual
        triggers.ignoreEnemyMitigationPercent = 0
        return ItemAffixPower(description: description, modifiers: power.modifiers, triggers: triggers)
    }

    private static func normalizedForbiddenKnowledge(_ power: ItemAffixPower) -> ItemAffixPower {
        if power.triggers.forbiddenKnowledge {
            if power.description == "Every other turn, lose 1 Health and draw 2 cards." {
                return power
            }
            return ItemAffixPower(
                description: "Every other turn, lose 1 Health and draw 2 cards.",
                modifiers: power.modifiers,
                triggers: power.triggers,
            )
        }
        if power.triggers.drawEveryOtherTurn > 0 {
            var triggers = power.triggers
            triggers.forbiddenKnowledge = true
            triggers.drawEveryOtherTurn = 0
            return ItemAffixPower(
                description: "Every other turn, lose 1 Health and draw 2 cards.",
                modifiers: power.modifiers,
                triggers: triggers,
            )
        }
        return power
    }

    private static func normalizedPatientEdge(_ power: ItemAffixPower) -> ItemAffixPower {
        if power.triggers.blockPreparesCritical {
            if power.description == "Blocking an attack makes your next attack Critically Hit." {
                return power
            }
            return ItemAffixPower(
                description: "Blocking an attack makes your next attack Critically Hit.",
                modifiers: power.modifiers,
                triggers: power.triggers,
            )
        }
        if power.triggers.partnerFirstAttackDamage > 0 || power.triggers.heldCardNextAttackDamage > 0 {
            var triggers = power.triggers
            triggers.blockPreparesCritical = true
            triggers.partnerFirstAttackDamage = 0
            triggers.heldCardNextAttackDamage = 0
            return ItemAffixPower(
                description: "Blocking an attack makes your next attack Critically Hit.",
                modifiers: power.modifiers,
                triggers: triggers,
            )
        }
        return power
    }
}

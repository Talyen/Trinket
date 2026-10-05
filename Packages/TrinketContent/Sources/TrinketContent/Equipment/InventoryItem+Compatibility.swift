import TrinketCore

extension InventoryItem {
    static func normalizedPower(_ original: ItemAffixPower, affixID: String) -> ItemAffixPower {
        // Migrate only the obsolete rule; rolled magnitudes and unrelated powers survive.
        var description = original.description
        var triggers = original.triggers
        switch affixID {
        case "leeching", "vampiric":
            return Self.normalizedLeechPower(original)
        case "symbiosis":
            let share = triggers.companionLeechSharePercent
            let percent = Int(((share.isNaN ? 0 : min(1, max(0, share))) * 100).rounded())
            description = "Your ally receives \(percent)% of the Health you restore with Leech."
        case "smugglers_map":
            triggers.victoryGoldFlat = 0
            triggers.goldTheftDrawChancePercent = 0.20
            description = "Stealing Gold has a 20% chance\nto draw a card."
        case "companions_collar":
            if !triggers.healCompanionDrawsCompanionCard {
                guard triggers.companionCardsEveryOtherTurn > 0 || triggers.companionCardsPerTurn > 0 else { return original }
                triggers.healCompanionDrawsCompanionCard = true
                triggers.companionCardsEveryOtherTurn = 0
                triggers.companionCardsPerTurn = 0
            }
            description = "Once per turn, healing your Companion draws a Companion card."
        case "beastbond":
            return Self.normalizedBeastbond(original)
        case "shredding":
            let actual = max(triggers.ignoreEnemyMitigationPercent, triggers.physicalIgnoreMitigationPercent)
            guard actual > 0 else { return original }
            description = "Your Physical damage ignores \(Int((actual * 100).rounded()))% of enemy damage reduction."
            if triggers.physicalIgnoreMitigationPercent >= triggers.ignoreEnemyMitigationPercent, original.description == description {
                return original
            }
            triggers.physicalIgnoreMitigationPercent = actual
            triggers.ignoreEnemyMitigationPercent = 0
        case "groves_favor":
            guard triggers.healthPerTurn > 0 else { return original }
            description = "Restore 2 Health every other turn."
        case "tattered_pages":
            if !triggers.forbiddenKnowledge {
                guard triggers.drawEveryOtherTurn > 0 else { return original }
                triggers.forbiddenKnowledge = true
                triggers.drawEveryOtherTurn = 0
            }
            description = "Every other turn, lose 1 Health and draw a card"
        case "the_returning_gale":
            description = "Once per turn, Dodging returns the last card you played to your hand."
        case "the_golden_crucible":
            description = "Gold gained in combat adds equal damage to your next Holy hit from a manually played card."
        case "the_patient_edge":
            if !triggers.blockPreparesCritical {
                guard triggers.partnerFirstAttackDamage > 0 || triggers.heldCardNextAttackDamage > 0 else { return original }
                triggers.blockPreparesCritical = true
                triggers.partnerFirstAttackDamage = 0
                triggers.heldCardNextAttackDamage = 0
            }
            description = "Blocking an attack makes your next attack Critically Hit."
        case "red_harvest", "huntsmasters_call", "threefold_grace", "golden_verdict":
            return Self.normalizedReworkedUnique(original, affixID: affixID)
        default:
            return original
        }
        return ItemAffixPower(description: description, modifiers: original.modifiers, triggers: triggers)
    }

    private static func normalizedLeechPower(_ power: ItemAffixPower) -> ItemAffixPower {
        guard let modifier = power.modifiers.first(where: {
            if case .leechGainedPercent = $0 {
                return true
            }
            return false
        }), case let .leechGainedPercent(amount) = modifier else { return power }
        return ItemAffixPower(
            description: "Leech restores an additional \(Int((amount * 100).rounded()))% of damage dealt.",
            modifiers: power.modifiers, triggers: power.triggers,
        )
    }

    private static func normalizedReworkedUnique(_ power: ItemAffixPower, affixID: String) -> ItemAffixPower {
        guard let current = GameContent.unique(matching: affixID)?.affixPowers?.first else { return power }
        var triggers = power.triggers
        let missingCurrentTrigger: Bool = switch affixID {
        case "red_harvest": !triggers.redHarvestPhysicalCriticalDetonatesBleed
        case "huntsmasters_call": !triggers.huntsmasterPhysicalCriticalDrawsCompanion
        case "threefold_grace": triggers.threefoldElementalDamageManaChancePercent <= 0
        default: false
        }
        if missingCurrentTrigger {
            triggers.merge(current.triggers)
        }
        return ItemAffixPower(description: current.description, modifiers: power.modifiers, triggers: triggers)
    }

    private static func normalizedBeastbond(_ power: ItemAffixPower) -> ItemAffixPower {
        var modifiers: [AffixModifier] = []
        var oldValue: Int?
        var newValue: Int?
        for modifier in power.modifiers {
            switch modifier {
            case let .companionDamageDealt(value):
                oldValue = oldValue ?? value
            case let .companionPhysicalDamageDealt(value):
                newValue = newValue ?? value
                modifiers.append(modifier)
            default:
                modifiers.append(modifier)
            }
        }
        let actual = newValue ?? oldValue
        guard let actual else { return power }
        if newValue == nil {
            modifiers.append(.companionPhysicalDamageDealt(actual))
        }
        let description = "Increase your Companion's Physical damage by \(actual)."
        return ItemAffixPower(description: description, modifiers: modifiers, triggers: power.triggers)
    }
}

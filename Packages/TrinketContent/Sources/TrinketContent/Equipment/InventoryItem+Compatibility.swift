import TrinketCore

extension InventoryItem {
    /// Typed adapter required by the localization inventory for compatibility
    /// descriptions; the rounding itself lives in `CombatRounding.wholePercent`.
    private static func wholePercent(_ fraction: Double) -> Int {
        CombatRounding.wholePercent(fraction)
    }

    static func normalizedPower(_ original: ItemAffixPower, affixID: String) -> ItemAffixPower {
        let power = normalizedGoldPower(original, affixID: affixID)
            ?? normalizedCombatProcPower(original, affixID: affixID) ?? normalizedRulePower(original, affixID: affixID)
        var description = power.description
            .replacingOccurrences(of: ". ", with: "\n")
            .replacingOccurrences(of: "; ", with: "\n")
        if description.hasSuffix(".") || description.hasSuffix(";") {
            description.removeLast()
        }
        guard description != power.description else { return power }
        return ItemAffixPower(description: description, modifiers: power.modifiers, triggers: power.triggers)
    }

    private static func normalizedRulePower(_ original: ItemAffixPower, affixID: String) -> ItemAffixPower {
        // Migrate only the obsolete rule; rolled magnitudes and unrelated powers survive.
        var description = original.description
        var triggers = original.triggers
        switch affixID {
        case "leeching", "vampiric":
            return Self.normalizedLeechPower(original)
        case "symbiosis":
            let share = triggers.companionLeechSharePercent
            let percent = Int(((share.isNaN ? 0 : min(1, max(0, share))) * 100).rounded())
            description = "Your ally receives \(percent)% of the Health you restore with Leech"
        case "smugglers_map":
            triggers.victoryGoldFlat = 0
            triggers.goldTheftDrawChancePercent = 0.20
            description = "Stealing Gold has a 20% chance\nto draw a card"
        case "companions_collar":
            if !triggers.healCompanionDrawsCompanionCard {
                guard triggers.companionCardsEveryOtherTurn > 0 || triggers.companionCardsPerTurn > 0 else { return original }
                triggers.healCompanionDrawsCompanionCard = true
                triggers.companionCardsEveryOtherTurn = 0
                triggers.companionCardsPerTurn = 0
            }
            description = "Once per turn, healing your Companion draws a Companion card"
        case "beastbond":
            return Self.normalizedBeastbond(original)
        case "shredding":
            let actual = max(triggers.ignoreEnemyMitigationPercent, triggers.physicalIgnoreMitigationPercent)
            guard actual > 0 else { return original }
            description = "Your Physical damage ignores \(Self.wholePercent(actual))% of enemy damage reduction"
            if triggers.physicalIgnoreMitigationPercent >= triggers.ignoreEnemyMitigationPercent, original.description == description {
                return original
            }
            triggers.physicalIgnoreMitigationPercent = actual
            triggers.ignoreEnemyMitigationPercent = 0
        case "groves_favor":
            guard triggers.healthPerTurn > 0 else { return original }
            description = "Restore 2 Health every other turn"
        case "tattered_pages":
            if !triggers.forbiddenKnowledge {
                guard triggers.drawEveryOtherTurn > 0 else { return original }
                triggers.forbiddenKnowledge = true
                triggers.drawEveryOtherTurn = 0
            }
            description = "Every other turn, lose 1 Health and draw a card"
        case "the_returning_gale":
            description = "Once per turn, Dodging returns the last card you played to your hand"
        case "the_golden_crucible":
            description = "Gold gained in combat adds equal damage to your next Holy hit from a manually played card"
        case "the_patient_edge":
            if !triggers.blockPreparesCritical {
                guard triggers.partnerFirstAttackDamage > 0 || triggers.heldCardNextAttackDamage > 0 else { return original }
                triggers.blockPreparesCritical = true
                triggers.partnerFirstAttackDamage = 0
                triggers.heldCardNextAttackDamage = 0
            }
            description = "Blocking an attack makes your next manually played attack Critically Hit"
        case "red_harvest", "huntsmasters_call", "threefold_grace", "golden_verdict", "vipers_courtesy":
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
            description: "Leech restores an additional \(Self.wholePercent(amount))% of damage dealt",
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
        let description = "Increase your Companion's Physical damage by \(actual)"
        return ItemAffixPower(description: description, modifiers: modifiers, triggers: power.triggers)
    }

    static func normalizedCombatProcPower(_ power: ItemAffixPower, affixID: String) -> ItemAffixPower? {
        var triggers = power.triggers
        let description: String
        switch affixID {
        case "spitebloom":
            triggers.thornsDamageVsPoisonedFlat = max(triggers.thornsDamageVsPoisonedFlat, triggers.poisonOnThornsDamage)
            triggers.poisonOnThornsDamage = 0
            let actual = triggers.thornsDamageVsPoisonedFlat
            description = "Your Thorns deal \(actual) additional damage to Poisoned enemies"
        case "ashen_wake":
            triggers.burnDamageVsPoisonedFlat = max(triggers.burnDamageVsPoisonedFlat, triggers.onBurnApplyPoison)
            triggers.onBurnApplyPoison = 0
            triggers.onBurnDealPoisonChancePercent = 0
            let actual = triggers.burnDamageVsPoisonedFlat
            description = "Your Burn deals \(actual) additional damage to Poisoned enemies"
        case "cauterize":
            triggers.bleedDamageVsBurningFlat = max(triggers.bleedDamageVsBurningFlat, triggers.onBleedDealBurnDamage)
            triggers.onBleedDealBurnDamage = 0
            triggers.onBleedDealBurnChancePercent = 0
            let actual = triggers.bleedDamageVsBurningFlat
            description = "Your Bleed deals \(actual) additional damage to Burning enemies"
        case "mortar_and_pestle":
            triggers.healthRestoredNextPoisonDamagePercent = max(
                triggers.healthRestoredNextPoisonDamagePercent, triggers.healthRestoredPoisonPercent,
            )
            triggers.healthRestoredPoisonPercent = 0
            if triggers.healthRestoredNextPoisonDamagePercent == 0.5 {
                description = "Your next Poison attack gains bonus damage equal to half your latest healing received"
            } else {
                let percent = Self.wholePercent(triggers.healthRestoredNextPoisonDamagePercent)
                description = "Your next Poison attack gains bonus damage equal to \(percent)% of your latest healing received"
            }
        case "beacon":
            if triggers.firstHolyAttackHealPerTurn <= 0 {
                // Old Beacon rolled per-hit healing; its once-per-turn replacement doubles that saved roll once.
                triggers.firstHolyAttackHealPerTurn = SaturatedArithmetic.saturatingMul(triggers.holyDamageHealFlat, 2)
            }
            triggers.holyDamageHealFlat = 0
            let actual = triggers.firstHolyAttackHealPerTurn
            description = "Your first Holy attack that deals Health damage each turn restores \(actual) Health to the lowest-Health ally"
        default:
            return normalizedAdditionalCombatProcPower(power, affixID: affixID)
        }
        return ItemAffixPower(description: description, modifiers: power.modifiers, triggers: triggers)
    }

    private static func normalizedAdditionalCombatProcPower(_ power: ItemAffixPower, affixID: String) -> ItemAffixPower? {
        var triggers = power.triggers
        let description: String
        switch affixID {
        case "infected":
            triggers.bleedDamageVsPoisonedFlat = max(triggers.bleedDamageVsPoisonedFlat, triggers.onBleedApplyPoison)
            triggers.onBleedApplyPoison = 0
            triggers.onBleedDealPoisonChancePercent = 0
            triggers.bleedPoisonOncePerTurn = false
            let actual = triggers.bleedDamageVsPoisonedFlat
            description = "Your Bleed deals \(actual) additional damage to Poisoned enemies"
        case "brass_censer":
            triggers.holyAttackDamageVsPoisonedFlat = max(triggers.holyAttackDamageVsPoisonedFlat, triggers.holyDamagePoisonFlat)
            triggers.holyDamagePoisonFlat = 0
            let actual = triggers.holyAttackDamageVsPoisonedFlat
            description = "Your Holy attacks deal \(actual) additional damage to Poisoned enemies"
        case "heartshock":
            triggers.leechHealVsStunnedBelowHalfFlat = max(triggers.leechHealVsStunnedBelowHalfFlat, triggers.leechStunBelowHalfHealth)
            triggers.leechStunBelowHalfHealth = 0
            let actual = triggers.leechHealVsStunnedBelowHalfFlat
            description = "Below half Health, Leech restores \(actual) additional Health against Stunned enemies"
        default:
            return normalizedPreparedReactionPower(power, affixID: affixID)
        }
        return ItemAffixPower(description: description, modifiers: power.modifiers, triggers: triggers)
    }

    private static func normalizedPreparedReactionPower(_ power: ItemAffixPower, affixID: String) -> ItemAffixPower? {
        var triggers = power.triggers
        let description: String
        switch affixID {
        case "whiplash":
            triggers.dodgeNextStunAttackBonus = max(triggers.dodgeNextStunAttackBonus, triggers.dodgeDealStunFlat)
            triggers.dodgeDealStunFlat = 0
            let actual = triggers.dodgeNextStunAttackBonus
            description = "Dodging adds \(actual) damage to your next Stun attack"
        case "denouncing":
            triggers.purgeNextHolyAttackBonus = max(triggers.purgeNextHolyAttackBonus, triggers.onPurgeDealHolyDamage)
            triggers.onPurgeDealHolyDamage = 0
            let actual = triggers.purgeNextHolyAttackBonus
            description = "Purging an enemy adds \(actual) damage to your next Holy attack"
        default:
            return nil
        }
        return ItemAffixPower(description: description, modifiers: power.modifiers, triggers: triggers)
    }

    private static func normalizedGoldPower(_ power: ItemAffixPower, affixID: String) -> ItemAffixPower? {
        var triggers = power.triggers
        let description: String
        switch affixID {
        case "blood_price":
            triggers.leechGoldChancePercent = 0.10
            let actual = triggers.leechGoldFlat
            description = "Leech has a 10% chance to grant \(actual) Gold"
        case "cutpurse_knife":
            triggers.bleedDamageGoldFlat = 0
            triggers.bleedDamageGoldStealChancePercent = 0.10
            description = "Bleed damage has a 10% chance to also steal Gold"
        case "merchants_favor":
            triggers.goldPerTurn = 0
            triggers.victoryGoldPerDifferentCardCap = 7
            description = "On victory, gain 1 Gold for each different card you played, up to 7"
        default: return nil
        }
        return ItemAffixPower(description: description, modifiers: power.modifiers, triggers: triggers)
    }
}

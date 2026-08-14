import Foundation
import TrinketCore

public struct ItemBaseType: Identifiable, Equatable, Hashable, Sendable {
    public enum WeaponKind: Equatable, Hashable, Sendable {
        case oneHanded
        case twoHanded
        case offHand
    }

    public let id: String
    public let name: String
    public let slot: ItemSlot
    public let weaponKind: WeaponKind?
    public let keywordAffinities: Set<Keyword>

    public init(
        id: String,
        name: String,
        slot: ItemSlot,
        weaponKind: WeaponKind? = nil,
        keywordAffinities: Set<Keyword>
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.weaponKind = weaponKind
        self.keywordAffinities = keywordAffinities
    }

    public var affixPowerMultiplier: Int {
        weaponKind == .twoHanded ? 2 : 1
    }

    public func canEquip(in slot: ItemSlot) -> Bool {
        switch weaponKind {
        case .oneHanded:
            slot == .weapon || slot == .secondaryWeapon
        case .twoHanded:
            slot == .weapon
        case .offHand:
            slot == .secondaryWeapon
        case nil:
            slot.accepts(self.slot)
        }
    }

    public var defaultEquipmentSlot: ItemSlot {
        weaponKind == .offHand ? .secondaryWeapon : slot
    }
}

public extension ItemBaseType {
    /// Neutral base-item preview used before a generated reward's rarity is rolled.
    var previewArtReference: ItemArtReference? {
        ArtCatalog.itemArtByID["\(id)-basic"] ?? ArtCatalog.itemArtByID[id]
    }
}

public struct ItemAffix: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let keywords: Set<Keyword>

    public init(id: String, title: String, description: String, keywords: Set<Keyword>) {
        self.id = id
        self.title = title
        self.description = description
        self.keywords = keywords
    }
}

public struct ItemAffixPower: Codable, Equatable, Hashable, Sendable {
    public let description: String
    public let modifiers: [AffixModifier]
    public let triggers: CombatTraitTriggers

    public init(
        description: String,
        modifiers: [AffixModifier],
        triggers: CombatTraitTriggers = CombatTraitTriggers()
    ) {
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
    }

    public func scaled(by multiplier: Int) -> Self {
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

    func scalingAffixMagnitudes(
        by multiplier: Int,
        record: (Double, Double, Bool) -> Void
    ) -> Self {
        var scaled = self
        scaled.scale(\.cleanseSelfHeal, by: multiplier, record: record)
        scaled.scale(\.gainGoldBonusHealSelf, by: multiplier, record: record)
        scaled.scale(\.thornsPercent, by: multiplier, record: record)
        scaled.scale(\.onBleedApplyPoison, by: multiplier, record: record)
        scaled.scale(\.onBurnApplyPoison, by: multiplier, record: record)
        scaled.scale(\.onBleedDealBurnDamage, by: multiplier, record: record)
        scaled.scale(\.poisonDecayIncreaseChance, by: multiplier, record: record)
        scaled.scale(\.freezeDamageWhileBurningBonus, by: multiplier, record: record)
        scaled.scale(\.damageWhileTargetFrozenBonus, by: multiplier, record: record)
        scaled.scale(\.damageBelowHealthPercentBonus, by: multiplier, record: record)
        scaled.scale(\.damageAfterDodgeBonus, by: multiplier, record: record)
        scaled.scale(\.blockBrokenBlockFlat, by: multiplier, record: record)
        scaled.scale(\.companionLeechSharePercent, by: multiplier, record: record)
        scaled.scale(\.onceBelowHealthPercentHeal, by: multiplier, record: record)
        scaled.scale(\.blockOnDeathsDoor, by: multiplier, record: record)
        scaled.scale(\.spendManaBlockFlat, by: multiplier, record: record)
        scaled.scale(\.holyDamageBlockFlat, by: multiplier, record: record)
        scaled.scale(\.holyDamageCleanseCount, by: multiplier, record: record)
        scaled.scale(\.holyDamageHealFlat, by: multiplier, record: record)
        scaled.scale(\.dodgeGoldFlat, by: multiplier, record: record)
        scaled.scale(\.ignoreEnemyMitigationPercent, by: multiplier, record: record)
        scaled.scale(\.stunDealPhysicalFlat, by: multiplier, record: record)
        scaled.scale(\.damageWhileTargetStunnedBonus, by: multiplier, record: record)
        scaled.scale(\.dodgeBlockFlat, by: multiplier, record: record)
        scaled.scale(\.holyDamagePurgeCount, by: multiplier, record: record)
        scaled.scale(\.enemyStunnedPurgeCount, by: multiplier, record: record)
        scaled.scale(\.criticalPurgeCount, by: multiplier, record: record)
        scaled.scale(\.criticalActionGoldFlat, by: multiplier, record: record)
        scaled.scale(\.leechRestoreManaFlat, by: multiplier, record: record)
        scaled.scale(\.gainManaBlockFlat, by: multiplier, record: record)
        scaled.scale(\.defeatEnemyGoldFlat, by: multiplier, record: record)
        scaled.scale(\.leechGoldFlat, by: multiplier, record: record)
        scaled.scale(\.dodgeHealFlat, by: multiplier, record: record)
        scaled.scale(\.dodgeChanceBelowHealthPercentBonus, by: multiplier, record: record)
        scaled.scale(\.dodgeDealStunFlat, by: multiplier, record: record)
        scaled.scale(\.dodgeChanceBonus, by: multiplier, record: record)
        scaled.scale(\.holyDamagePoisonFlat, by: multiplier, record: record)
        scaled.scale(\.drawEveryOtherTurn, by: multiplier, record: record)
        scaled.scale(\.drawOnHealthLoss, by: multiplier, record: record)
        scaled.scale(\.physicalStunBuildupPercent, by: multiplier, record: record)
        scaled.scale(\.blockGainThornsPercent, by: multiplier, record: record)
        scaled.scale(\.drawOnSpendMana, by: multiplier, record: record)
        scaled.scale(\.physicalDamageBlockPercent, by: multiplier, record: record)
        scaled.scale(\.bleedDamageGoldFlat, by: multiplier, record: record)
        scaled.scale(\.goldPerTurn, by: multiplier, record: record)
        scaled.scale(\.healthRestoredPoisonPercent, by: multiplier, record: record)
        scaled.scale(\.sunderingBlockMultiplier, by: multiplier, record: record)
        scaled.scale(\.cardsPlayedManaFlat, by: multiplier, record: record)
        scaled.scale(\.victoryGoldFlat, by: multiplier, record: record)
        scaled.scale(\.healthPerTurn, by: multiplier, record: record)
        scaled.scale(\.companionCardsPerTurn, by: multiplier, record: record)
        scaled.scale(\.freezeExtraActionSkips, by: multiplier, record: record)
        scaled.scale(\.criticalChanceBonus, by: multiplier, record: record)
        return scaled
    }
}

public struct ItemAffixDefinition: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let slot: ItemSlot
    public let keywords: Set<Keyword>
    public let weight: Int
    public let basic: ItemAffixPower
    public let astral: ItemAffixPower

    public init(
        id: String,
        title: String,
        slot: ItemSlot,
        keywords: Set<Keyword>,
        weight: Int,
        basic: ItemAffixPower,
        astral: ItemAffixPower
    ) {
        self.id = id
        self.title = title
        self.slot = slot
        self.keywords = keywords
        self.weight = weight
        self.basic = basic
        self.astral = astral
    }

    public func power(for rarity: Rarity) -> ItemAffixPower {
        switch rarity {
        case .basic:
            basic
        case .astral:
            astral
        }
    }

    /// Utility affixes with no damage-type keywords (mitigation / restoration / resource).
    /// Safe to equip on any build without creating a keyword mismatch.
    public var isBuildGeneric: Bool {
        keywords.allSatisfy { $0.category != .damageType }
    }

    /// `true` when every damage type in this affix is present in `bias`, or the
    /// affix is build-generic. Hybrid damage affixes cannot introduce a
    /// damage type outside the selected build.
    public func isAligned(withBuildKeywords bias: Set<Keyword>) -> Bool {
        if isBuildGeneric {
            return true
        }
        guard !bias.isEmpty else { return true }
        let damageKeywords = keywords.filter { $0.category == .damageType }
        return damageKeywords.isSubset(of: bias)
    }

    public func resolved(for rarity: Rarity) -> ItemAffix {
        let power = power(for: rarity)
        return ItemAffix(
            id: id,
            title: title,
            description: power.description,
            keywords: keywords
        )
    }
}

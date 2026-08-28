import Foundation
import TrinketCore

public struct InventoryItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let templateID: String
    public let baseType: ItemBaseType
    public let rarity: Rarity
    public let displayName: String
    public let affixes: [ItemAffix]
    public let isCorrupted: Bool
    public let affixPowers: [ItemAffixPower]?

    public init(
        id: String,
        templateID: String? = nil,
        baseType: ItemBaseType,
        rarity: Rarity,
        displayName: String,
        affixes: [ItemAffix],
        isCorrupted: Bool = false,
        affixPowers: [ItemAffixPower]? = nil
    ) {
        self.id = id
        self.templateID = templateID ?? id
        self.baseType = baseType
        self.rarity = rarity
        self.displayName = displayName
        self.affixes = affixes
        self.isCorrupted = isCorrupted
        self.affixPowers = affixPowers
    }

    public func rewardInstance(for stageID: String) -> Self {
        if isTrinket || rarity == .unique {
            return self
        }
        return Self(
            id: "\(stageID)-\(templateID)",
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: displayName,
            affixes: affixes,
            isCorrupted: isCorrupted,
            affixPowers: affixPowers
        )
    }

    public func resolvedPower(at affixIndex: Int) -> ItemAffixPower? {
        let power: ItemAffixPower
        if let affixPowers, affixPowers.indices.contains(affixIndex) {
            power = affixPowers[affixIndex]
        } else {
            guard affixes.indices.contains(affixIndex),
                  let definition = GameContent.itemAffixDefinition(matching: affixes[affixIndex].id)
            else {
                return nil
            }
            power = definition.power(for: rarity)
        }
        return power.scaled(by: baseType.affixPowerMultiplier)
    }

    public var displayedAffixes: [ItemAffix] {
        affixes.enumerated().map { index, affix in
            guard let power = resolvedPower(at: index) else { return affix }
            return ItemAffix(
                id: affix.id,
                title: affix.title,
                description: power.description,
                keywords: affix.keywords,
                isCorrupted: affix.isCorrupted
            )
        }
    }

    public var hasCorruptedAffix: Bool {
        affixes.contains(where: \.isCorrupted)
    }

    public var isTrinket: Bool {
        baseType.slot == .trinket
    }

    public var keywords: Set<Keyword> {
        affixes.reduce(into: Set<Keyword>()) { $0.formUnion($1.keywords) }
    }

    public func isPerfectAffix(at index: Int) -> Bool {
        guard affixes.indices.contains(index),
              let storedPowers = affixPowers,
              storedPowers.indices.contains(index),
              let definition = GameContent.itemAffixDefinition(matching: affixes[index].id)
        else {
            return false
        }
        return storedPowers[index].isAtOrAboveRollMax(of: definition.power(for: rarity))
    }
}

public struct EquipmentLoadout: Equatable, Hashable, Sendable {
    public var itemIDsBySlot: [ItemSlot: String]

    public init(itemIDsBySlot: [ItemSlot: String] = [:]) {
        self.itemIDsBySlot = itemIDsBySlot
    }

    public func itemID(for slot: ItemSlot) -> String? {
        itemIDsBySlot[slot]
    }

    public mutating func equip(
        _ item: InventoryItem,
        in slot: ItemSlot? = nil,
        inventory: [InventoryItem]
    ) {
        let destination = slot ?? item.baseType.defaultEquipmentSlot
        guard canEquip(item, in: destination, inventory: inventory) else { return }
        for occupied in ItemSlot.allCases where occupied != destination {
            if itemIDsBySlot[occupied] == item.id {
                itemIDsBySlot[occupied] = nil
            }
        }
        if item.baseType.weaponKind == .twoHanded {
            if item.baseType.isRanged {
                if let secondaryID = itemIDsBySlot[.secondaryWeapon],
                   let secondary = inventory.first(where: { $0.id == secondaryID }),
                   !secondary.baseType.isQuiver {
                    itemIDsBySlot[.secondaryWeapon] = nil
                }
            } else {
                itemIDsBySlot[.secondaryWeapon] = nil
            }
        }
        itemIDsBySlot[destination] = item.id
    }

    public func canEquip(
        _ item: InventoryItem,
        in slot: ItemSlot,
        inventory: [InventoryItem]
    ) -> Bool {
        guard item.baseType.canEquip(in: slot) else { return false }
        guard trinketBaseIsFree(item, excluding: slot, inventory: inventory) else { return false }
        if slot == .weapon, !item.baseType.isRanged {
            if let secondaryID = itemID(for: .secondaryWeapon),
               let secondary = inventory.first(where: { $0.id == secondaryID }),
               secondary.baseType.isQuiver {
                return false
            }
        }
        guard slot == .secondaryWeapon else { return true }
        guard
            let primaryID = itemID(for: .weapon),
            let primary = inventory.first(where: { $0.id == primaryID })
        else {
            return !item.baseType.isQuiver
        }
        return Self.secondaryWeaponAllows(primary: primary.baseType, secondary: item.baseType)
    }

    static func secondaryWeaponAllows(primary: ItemBaseType, secondary: ItemBaseType) -> Bool {
        if secondary.isQuiver {
            return primary.isRanged
        }
        if primary.isRanged {
            return false
        }
        return primary.weaponKind != .twoHanded
    }

    private func trinketBaseIsFree(
        _ item: InventoryItem,
        excluding destination: ItemSlot,
        inventory: [InventoryItem]
    ) -> Bool {
        guard item.isTrinket else { return true }
        return itemIDs(inFamilyOf: destination).allSatisfy { siblingID in
            guard siblingID != item.id,
                  let worn = inventory.first(where: { $0.id == siblingID })
            else { return true }
            return worn.baseType.id != item.baseType.id
        }
    }

    public func isAvailable(_ slot: ItemSlot, inventory: [InventoryItem]) -> Bool {
        guard slot == .secondaryWeapon else { return true }
        guard
            let primaryID = itemID(for: .weapon),
            let primary = inventory.first(where: { $0.id == primaryID })
        else {
            return true
        }
        if let secondaryID = itemID(for: .secondaryWeapon),
           let secondary = inventory.first(where: { $0.id == secondaryID }),
           secondary.baseType.isQuiver {
            return primary.baseType.isRanged
        }
        if primary.baseType.isRanged {
            return true
        }
        return primary.baseType.weaponKind != .twoHanded
    }

    public mutating func unequip(_ slot: ItemSlot) {
        itemIDsBySlot[slot] = nil
    }

    public func itemIDs(inFamilyOf slot: ItemSlot) -> Set<String> {
        Set(ItemSlot.allCases.compactMap { candidate in
            guard candidate.baseItemSlot == slot.baseItemSlot else { return nil }
            return itemIDsBySlot[candidate]
        })
    }
}

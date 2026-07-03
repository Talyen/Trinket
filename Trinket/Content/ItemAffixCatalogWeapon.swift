import Foundation

enum ItemAffixCatalogWeapon {
    static let definitions: [ItemAffixDefinition] = [
        ItemAffixCatalogSupport.affix(
            id: "mighty",
            title: "Mighty",
            slot: .weapon,
            keywords: [.physical],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Strength by 1", modifiers: [.strength(1)]),
            astral: ItemAffixPower(description: "Increases Strength by 3", modifiers: [.strength(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "nimble",
            title: "Nimble",
            slot: .weapon,
            keywords: [.physical, .bleed],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Agility by 1", modifiers: [.agility(1)]),
            astral: ItemAffixPower(description: "Increases Agility by 3", modifiers: [.agility(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "arcane",
            title: "Arcane",
            slot: .weapon,
            keywords: [.burn, .freeze],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Intellect by 1", modifiers: [.intellect(1)]),
            astral: ItemAffixPower(description: "Increases Intellect by 3", modifiers: [.intellect(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "keen",
            title: "Keen",
            slot: .weapon,
            keywords: [.physical],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Physical damage dealt by 1", modifiers: [.damageDealt(.physical, 1)]),
            astral: ItemAffixPower(description: "Increases Physical damage dealt by 3", modifiers: [.damageDealt(.physical, 3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "serrated",
            title: "Serrated",
            slot: .weapon,
            keywords: [.bleed],
            weight: 10,
            basic: ItemAffixPower(description: "Increases Bleed damage dealt by 1", modifiers: [.damageDealt(.bleed, 1)]),
            astral: ItemAffixPower(description: "Increases Bleed damage dealt by 2", modifiers: [.damageDealt(.bleed, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "envenomed",
            title: "Envenomed",
            slot: .weapon,
            keywords: [.poison],
            weight: 10,
            basic: ItemAffixPower(description: "Increases Poison damage dealt by 1", modifiers: [.damageDealt(.poison, 1)]),
            astral: ItemAffixPower(description: "Increases Poison damage dealt by 2", modifiers: [.damageDealt(.poison, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "smoldering",
            title: "Smoldering",
            slot: .weapon,
            keywords: [.burn],
            weight: 10,
            basic: ItemAffixPower(description: "Increases Burn damage dealt by 1", modifiers: [.damageDealt(.burn, 1)]),
            astral: ItemAffixPower(description: "Increases Burn damage dealt by 2", modifiers: [.damageDealt(.burn, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "consecrated",
            title: "Consecrated",
            slot: .weapon,
            keywords: [.holy],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Holy damage dealt by 1", modifiers: [.damageDealt(.holy, 1)]),
            astral: ItemAffixPower(description: "Increases Holy damage dealt by 3", modifiers: [.damageDealt(.holy, 3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "wild",
            title: "Wild",
            slot: .weapon,
            keywords: [.nature],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Nature damage dealt by 1", modifiers: [.damageDealt(.nature, 1)]),
            astral: ItemAffixPower(description: "Increases Nature damage dealt by 2", modifiers: [.damageDealt(.nature, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "glacial",
            title: "Glacial",
            slot: .weapon,
            keywords: [.freeze],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Freeze damage dealt by 1", modifiers: [.damageDealt(.freeze, 1)]),
            astral: ItemAffixPower(description: "Increases Freeze damage dealt by 2", modifiers: [.damageDealt(.freeze, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "concussive",
            title: "Concussive",
            slot: .weapon,
            keywords: [.stun],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Stun damage dealt by 1", modifiers: [.damageDealt(.stun, 1)]),
            astral: ItemAffixPower(description: "Increases Stun damage dealt by 2", modifiers: [.damageDealt(.stun, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "lingering",
            title: "Lingering",
            slot: .weapon,
            keywords: [.bleed],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Bleed duration by 1", modifiers: [.bleedDuration(1)]),
            astral: ItemAffixPower(description: "Increases Bleed duration by 2", modifiers: [.bleedDuration(2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "duelists",
            title: "Duelist's",
            slot: .weapon,
            keywords: [.bleed, .physical],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Agility by 1 and Bleed damage dealt by 1", modifiers: [.agility(1), .damageDealt(.bleed, 1)]),
            astral: ItemAffixPower(description: "Increases Agility by 2 and Bleed damage dealt by 2", modifiers: [.agility(2), .damageDealt(.bleed, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "crusaders",
            title: "Crusader's",
            slot: .weapon,
            keywords: [.holy, .physical],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Strength by 1 and Holy damage dealt by 1", modifiers: [.strength(1), .damageDealt(.holy, 1)]),
            astral: ItemAffixPower(description: "Increases Strength by 2 and Holy damage dealt by 2", modifiers: [.strength(2), .damageDealt(.holy, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "pyromancers",
            title: "Pyromancer's",
            slot: .weapon,
            keywords: [.burn],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Intellect by 1 and Burn damage dealt by 1", modifiers: [.intellect(1), .damageDealt(.burn, 1)]),
            astral: ItemAffixPower(description: "Increases Intellect by 2 and Burn damage dealt by 2", modifiers: [.intellect(2), .damageDealt(.burn, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "sentinel",
            title: "Sentinel",
            slot: .weapon,
            keywords: [.block],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Block granted by 1", modifiers: [.blockGranted(1)]),
            astral: ItemAffixPower(description: "Increases Block granted by 3", modifiers: [.blockGranted(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "fortified",
            title: "Fortified",
            slot: .weapon,
            keywords: [.armor],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Armor granted by 5%", modifiers: [.armorGrantedPercent(0.05)]),
            astral: ItemAffixPower(description: "Increases Armor granted by 15%", modifiers: [.armorGrantedPercent(0.15)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "defenders",
            title: "Defender's",
            slot: .weapon,
            keywords: [.block, .armor],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Block granted by 1 and Armor granted by 5%", modifiers: [.blockGranted(1), .armorGrantedPercent(0.05)]),
            astral: ItemAffixPower(description: "Increases Block granted by 2 and Armor granted by 15%", modifiers: [.blockGranted(2), .armorGrantedPercent(0.15)])
        )
    ]
}

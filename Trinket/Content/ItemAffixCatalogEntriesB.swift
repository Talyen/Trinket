import Foundation

enum ItemAffixCatalogEntriesB {
    static let definitions: [ItemAffixDefinition] = [
        ItemAffixCatalogSupport.affix(
            id: "thick-skinned",
            title: "Thick-Skinned",
            slot: .armor,
            keywords: [.bleed],
            weight: 8,
            basic: ItemAffixPower(description: "Decreases Bleed damage taken by 10%", modifiers: [.damageTakenPercent(.bleed, 0.10)]),
            astral: ItemAffixPower(description: "Decreases Bleed damage taken by 25%", modifiers: [.damageTakenPercent(.bleed, 0.25)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "lucky",
            title: "Lucky",
            slot: .trinket,
            keywords: [.gold],
            weight: 10,
            basic: ItemAffixPower(description: "Increases Gold gained by 1", modifiers: [.goldGained(1)]),
            astral: ItemAffixPower(description: "Increases Gold gained by 4", modifiers: [.goldGained(4)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "vampiric",
            title: "Vampiric",
            slot: .trinket,
            keywords: [.leech],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Leech granted by 5%", modifiers: [.leechGrantedPercent(0.05)]),
            astral: ItemAffixPower(description: "Increases Leech granted by 15%", modifiers: [.leechGrantedPercent(0.15)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "bloodstone",
            title: "Bloodstone",
            slot: .trinket,
            keywords: [.leech, .health],
            weight: 8,
            basic: ItemAffixPower(description: "Increases health restored from Leech by 1", modifiers: [.leechHealing(1)]),
            astral: ItemAffixPower(description: "Increases health restored from Leech by 3", modifiers: [.leechHealing(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "lifeweave",
            title: "Lifeweave",
            slot: .armor,
            keywords: [.leech, .health],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Health restored by 1", modifiers: [.healthRestored(1)]),
            astral: ItemAffixPower(description: "Increases Health restored by 3", modifiers: [.healthRestored(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "verdant",
            title: "Verdant",
            slot: .trinket,
            keywords: [.nature, .health],
            weight: 10,
            basic: ItemAffixPower(description: "Increases Nature damage dealt by 1", modifiers: [.damageDealt(.nature, 1)]),
            astral: ItemAffixPower(description: "Increases Nature damage dealt by 2", modifiers: [.damageDealt(.nature, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "sparkling",
            title: "Sparkling",
            slot: .trinket,
            keywords: [.holy],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Holy damage dealt by 1", modifiers: [.damageDealt(.holy, 1)]),
            astral: ItemAffixPower(description: "Increases Holy damage dealt by 2", modifiers: [.damageDealt(.holy, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "steadfast",
            title: "Steadfast",
            slot: .trinket,
            keywords: [.armor, .block],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Block duration by 1 and Armor duration by 1", modifiers: [.blockDuration(1), .armorDuration(1)]),
            astral: ItemAffixPower(description: "Increases Block duration by 2 and Armor duration by 2", modifiers: [.blockDuration(2), .armorDuration(2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "fatebound",
            title: "Fatebound",
            slot: .trinket,
            keywords: [.holy, .gold],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Holy damage dealt by 1 and Gold gained by 1", modifiers: [.damageDealt(.holy, 1), .goldGained(1)]),
            astral: ItemAffixPower(description: "Increases Holy damage dealt by 2 and Gold gained by 4", modifiers: [.damageDealt(.holy, 2), .goldGained(4)])
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
            id: "guardians",
            title: "Guardian's",
            slot: .armor,
            keywords: [.block, .armor],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Toughness by 1 and Block granted by 1", modifiers: [.toughness(1), .blockGranted(1)]),
            astral: ItemAffixPower(description: "Increases Toughness by 2 and Block granted by 2", modifiers: [.toughness(2), .blockGranted(2)])
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
            id: "rime",
            title: "Rime",
            slot: .trinket,
            keywords: [.freeze],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Freeze damage dealt by 1", modifiers: [.damageDealt(.freeze, 1)]),
            astral: ItemAffixPower(description: "Increases Freeze damage dealt by 2", modifiers: [.damageDealt(.freeze, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "aegis",
            title: "Aegis",
            slot: .trinket,
            keywords: [.block],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Block granted by 1", modifiers: [.blockGranted(1)]),
            astral: ItemAffixPower(description: "Increases Block granted by 3", modifiers: [.blockGranted(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "etched",
            title: "Etched",
            slot: .trinket,
            keywords: [.armor],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Armor granted by 5%", modifiers: [.armorGrantedPercent(0.05)]),
            astral: ItemAffixPower(description: "Increases Armor granted by 15%", modifiers: [.armorGrantedPercent(0.15)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "shocking",
            title: "Shocking",
            slot: .trinket,
            keywords: [.stun],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Stun damage dealt by 1", modifiers: [.damageDealt(.stun, 1)]),
            astral: ItemAffixPower(description: "Increases Stun damage dealt by 2", modifiers: [.damageDealt(.stun, 2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "gilded",
            title: "Gilded",
            slot: .trinket,
            keywords: [.gold],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Gold gained by 1", modifiers: [.goldGained(1)]),
            astral: ItemAffixPower(description: "Increases Gold gained by 2", modifiers: [.goldGained(2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "defenders",
            title: "Defender's",
            slot: .weapon,
            keywords: [.block, .armor],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Block granted by 1 and Armor granted by 5%", modifiers: [.blockGranted(1), .armorGrantedPercent(0.05)]),
            astral: ItemAffixPower(description: "Increases Block granted by 2 and Armor granted by 15%", modifiers: [.blockGranted(2), .armorGrantedPercent(0.15)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "heartward",
            title: "Heartward",
            slot: .trinket,
            keywords: [.health],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Health restored by 1 and Maximum Health by 2", modifiers: [.healthRestored(1), .maximumHealth(2)]),
            astral: ItemAffixPower(description: "Increases Health restored by 3 and Maximum Health by 6", modifiers: [.healthRestored(3), .maximumHealth(6)])
        )
    ]
}

import Foundation

enum ItemAffixCatalogArmor {
    static let definitions: [ItemAffixDefinition] = [
        ItemAffixCatalogSupport.affix(
            id: "stalwart",
            title: "Stalwart",
            slot: .armor,
            keywords: [.armor, .block],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Toughness by 1", modifiers: [.toughness(1)]),
            astral: ItemAffixPower(description: "Increases Toughness by 3", modifiers: [.toughness(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "devout",
            title: "Devout",
            slot: .armor,
            keywords: [.holy],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Wisdom by 1", modifiers: [.wisdom(1)]),
            astral: ItemAffixPower(description: "Increases Wisdom by 3", modifiers: [.wisdom(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "reinforced",
            title: "Reinforced",
            slot: .armor,
            keywords: [.armor],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Armor granted by 10%", modifiers: [.armorGrantedPercent(0.10)]),
            astral: ItemAffixPower(description: "Increases Armor granted by 25%", modifiers: [.armorGrantedPercent(0.25)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "bulwark",
            title: "Bulwark",
            slot: .armor,
            keywords: [.block],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Block granted by 2", modifiers: [.blockGranted(2)]),
            astral: ItemAffixPower(description: "Increases Block granted by 5", modifiers: [.blockGranted(5)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "warding",
            title: "Warding",
            slot: .armor,
            keywords: [.block],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Block duration by 1", modifiers: [.blockDuration(1)]),
            astral: ItemAffixPower(description: "Increases Block duration by 2", modifiers: [.blockDuration(2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "anchored",
            title: "Anchored",
            slot: .armor,
            keywords: [.armor],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Armor duration by 1", modifiers: [.armorDuration(1)]),
            astral: ItemAffixPower(description: "Increases Armor duration by 2", modifiers: [.armorDuration(2)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "vital",
            title: "Vital",
            slot: .armor,
            keywords: [.health],
            weight: 10,
            basic: ItemAffixPower(description: "Increases Health restored by 1", modifiers: [.healthRestored(1)]),
            astral: ItemAffixPower(description: "Increases Health restored by 3", modifiers: [.healthRestored(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "emberguard",
            title: "Emberguard",
            slot: .armor,
            keywords: [.burn, .armor],
            weight: 8,
            basic: ItemAffixPower(description: "Decreases Burn damage taken by 10%", modifiers: [.damageTakenPercent(.burn, 0.10)]),
            astral: ItemAffixPower(description: "Decreases Burn damage taken by 25%", modifiers: [.damageTakenPercent(.burn, 0.25)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "antidotal",
            title: "Antidotal",
            slot: .armor,
            keywords: [.poison, .health],
            weight: 8,
            basic: ItemAffixPower(description: "Decreases Poison damage taken by 10%", modifiers: [.damageTakenPercent(.poison, 0.10)]),
            astral: ItemAffixPower(description: "Decreases Poison damage taken by 25%", modifiers: [.damageTakenPercent(.poison, 0.25)])
        ),
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
            id: "lifeweave",
            title: "Lifeweave",
            slot: .armor,
            keywords: [.leech, .health],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Health restored by 1", modifiers: [.healthRestored(1)]),
            astral: ItemAffixPower(description: "Increases Health restored by 3", modifiers: [.healthRestored(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "guardians",
            title: "Guardian's",
            slot: .armor,
            keywords: [.block, .armor],
            weight: 8,
            basic: ItemAffixPower(description: "Increases Toughness by 1 and Block granted by 1", modifiers: [.toughness(1), .blockGranted(1)]),
            astral: ItemAffixPower(description: "Increases Toughness by 2 and Block granted by 2", modifiers: [.toughness(2), .blockGranted(2)])
        )
    ]
}

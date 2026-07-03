import Foundation

enum ItemAffixCatalogEntriesA {
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
            id: "stalwart",
            title: "Stalwart",
            slot: .armor,
            keywords: [.armor, .block],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Toughness by 1", modifiers: [.toughness(1)]),
            astral: ItemAffixPower(description: "Increases Toughness by 3", modifiers: [.toughness(3)])
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
            id: "devout",
            title: "Devout",
            slot: .armor,
            keywords: [.holy],
            weight: 12,
            basic: ItemAffixPower(description: "Increases Wisdom by 1", modifiers: [.wisdom(1)]),
            astral: ItemAffixPower(description: "Increases Wisdom by 3", modifiers: [.wisdom(3)])
        ),
        ItemAffixCatalogSupport.affix(
            id: "hale",
            title: "Hale",
            slot: .trinket,
            keywords: [.health],
            weight: 10,
            basic: ItemAffixPower(description: "Increases Maximum Health by 4", modifiers: [.maximumHealth(4)]),
            astral: ItemAffixPower(description: "Increases Maximum Health by 12", modifiers: [.maximumHealth(12)])
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
        )
    ]
}

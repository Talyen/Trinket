import Foundation

enum ItemAffixCatalog {
    static let definitions: [ItemAffixDefinition] = [
        affix(
            id: "mighty",
            title: "Mighty",
            slot: .weapon,
            keywords: [.physical],
            weight: 12,
            basic: "Increases Strength by 1",
            basicModifiers: [.strength(1)],
            astral: "Increases Strength by 3",
            astralModifiers: [.strength(3)]
        ),
        affix(
            id: "nimble",
            title: "Nimble",
            slot: .weapon,
            keywords: [.physical, .bleed],
            weight: 12,
            basic: "Increases Agility by 1",
            basicModifiers: [.agility(1)],
            astral: "Increases Agility by 3",
            astralModifiers: [.agility(3)]
        ),
        affix(
            id: "stalwart",
            title: "Stalwart",
            slot: .armor,
            keywords: [.armor, .block],
            weight: 12,
            basic: "Increases Toughness by 1",
            basicModifiers: [.toughness(1)],
            astral: "Increases Toughness by 3",
            astralModifiers: [.toughness(3)]
        ),
        affix(
            id: "arcane",
            title: "Arcane",
            slot: .weapon,
            keywords: [.burn, .freeze],
            weight: 12,
            basic: "Increases Intellect by 1",
            basicModifiers: [.intellect(1)],
            astral: "Increases Intellect by 3",
            astralModifiers: [.intellect(3)]
        ),
        affix(
            id: "devout",
            title: "Devout",
            slot: .armor,
            keywords: [.holy],
            weight: 12,
            basic: "Increases Wisdom by 1",
            basicModifiers: [.wisdom(1)],
            astral: "Increases Wisdom by 3",
            astralModifiers: [.wisdom(3)]
        ),
        affix(
            id: "hale",
            title: "Hale",
            slot: .trinket,
            keywords: [.health],
            weight: 10,
            basic: "Increases Maximum Health by 4",
            basicModifiers: [.maximumHealth(4)],
            astral: "Increases Maximum Health by 12",
            astralModifiers: [.maximumHealth(12)]
        ),
        affix(
            id: "keen",
            title: "Keen",
            slot: .weapon,
            keywords: [.physical],
            weight: 12,
            basic: "Increases Physical damage dealt by 1",
            basicModifiers: [.damageDealt(.physical, 1)],
            astral: "Increases Physical damage dealt by 3",
            astralModifiers: [.damageDealt(.physical, 3)]
        ),
        affix(
            id: "serrated",
            title: "Serrated",
            slot: .weapon,
            keywords: [.bleed],
            weight: 10,
            basic: "Increases Bleed damage dealt by 1",
            basicModifiers: [.damageDealt(.bleed, 1)],
            astral: "Increases Bleed damage dealt by 2",
            astralModifiers: [.damageDealt(.bleed, 2)]
        ),
        affix(
            id: "envenomed",
            title: "Envenomed",
            slot: .weapon,
            keywords: [.poison],
            weight: 10,
            basic: "Increases Poison damage dealt by 1",
            basicModifiers: [.damageDealt(.poison, 1)],
            astral: "Increases Poison damage dealt by 2",
            astralModifiers: [.damageDealt(.poison, 2)]
        ),
        affix(
            id: "smoldering",
            title: "Smoldering",
            slot: .weapon,
            keywords: [.burn],
            weight: 10,
            basic: "Increases Burn damage dealt by 1",
            basicModifiers: [.damageDealt(.burn, 1)],
            astral: "Increases Burn damage dealt by 2",
            astralModifiers: [.damageDealt(.burn, 2)]
        ),
        affix(
            id: "consecrated",
            title: "Consecrated",
            slot: .weapon,
            keywords: [.holy],
            weight: 8,
            basic: "Increases Holy damage dealt by 1",
            basicModifiers: [.damageDealt(.holy, 1)],
            astral: "Increases Holy damage dealt by 3",
            astralModifiers: [.damageDealt(.holy, 3)]
        ),
        affix(
            id: "wild",
            title: "Wild",
            slot: .weapon,
            keywords: [.nature],
            weight: 8,
            basic: "Increases Nature damage dealt by 1",
            basicModifiers: [.damageDealt(.nature, 1)],
            astral: "Increases Nature damage dealt by 2",
            astralModifiers: [.damageDealt(.nature, 2)]
        ),
        affix(
            id: "glacial",
            title: "Glacial",
            slot: .weapon,
            keywords: [.freeze],
            weight: 8,
            basic: "Increases Freeze damage dealt by 1",
            basicModifiers: [.damageDealt(.freeze, 1)],
            astral: "Increases Freeze damage dealt by 2",
            astralModifiers: [.damageDealt(.freeze, 2)]
        ),
        affix(
            id: "concussive",
            title: "Concussive",
            slot: .weapon,
            keywords: [.stun],
            weight: 8,
            basic: "Increases Stun damage dealt by 1",
            basicModifiers: [.damageDealt(.stun, 1)],
            astral: "Increases Stun damage dealt by 2",
            astralModifiers: [.damageDealt(.stun, 2)]
        ),
        affix(
            id: "lingering",
            title: "Lingering",
            slot: .weapon,
            keywords: [.bleed],
            weight: 8,
            basic: "Increases Bleed duration by 1",
            basicModifiers: [.bleedDuration(1)],
            astral: "Increases Bleed duration by 2",
            astralModifiers: [.bleedDuration(2)]
        ),
        affix(
            id: "reinforced",
            title: "Reinforced",
            slot: .armor,
            keywords: [.armor],
            weight: 12,
            basic: "Increases Armor granted by 10%",
            basicModifiers: [.armorGrantedPercent(0.10)],
            astral: "Increases Armor granted by 25%",
            astralModifiers: [.armorGrantedPercent(0.25)]
        ),
        affix(
            id: "bulwark",
            title: "Bulwark",
            slot: .armor,
            keywords: [.block],
            weight: 12,
            basic: "Increases Block granted by 2",
            basicModifiers: [.blockGranted(2)],
            astral: "Increases Block granted by 5",
            astralModifiers: [.blockGranted(5)]
        ),
        affix(
            id: "warding",
            title: "Warding",
            slot: .armor,
            keywords: [.block],
            weight: 8,
            basic: "Increases Block duration by 1",
            basicModifiers: [.blockDuration(1)],
            astral: "Increases Block duration by 2",
            astralModifiers: [.blockDuration(2)]
        ),
        affix(
            id: "anchored",
            title: "Anchored",
            slot: .armor,
            keywords: [.armor],
            weight: 8,
            basic: "Increases Armor duration by 1",
            basicModifiers: [.armorDuration(1)],
            astral: "Increases Armor duration by 2",
            astralModifiers: [.armorDuration(2)]
        ),
        affix(
            id: "vital",
            title: "Vital",
            slot: .armor,
            keywords: [.health],
            weight: 10,
            basic: "Increases Health restored by 1",
            basicModifiers: [.healthRestored(1)],
            astral: "Increases Health restored by 3",
            astralModifiers: [.healthRestored(3)]
        ),
        affix(
            id: "emberguard",
            title: "Emberguard",
            slot: .armor,
            keywords: [.burn, .armor],
            weight: 8,
            basic: "Decreases Burn damage taken by 10%",
            basicModifiers: [.damageTakenPercent(.burn, 0.10)],
            astral: "Decreases Burn damage taken by 25%",
            astralModifiers: [.damageTakenPercent(.burn, 0.25)]
        ),
        affix(
            id: "antidotal",
            title: "Antidotal",
            slot: .armor,
            keywords: [.poison, .health],
            weight: 8,
            basic: "Decreases Poison damage taken by 10%",
            basicModifiers: [.damageTakenPercent(.poison, 0.10)],
            astral: "Decreases Poison damage taken by 25%",
            astralModifiers: [.damageTakenPercent(.poison, 0.25)]
        ),
        affix(
            id: "thick-skinned",
            title: "Thick-Skinned",
            slot: .armor,
            keywords: [.bleed],
            weight: 8,
            basic: "Decreases Bleed damage taken by 10%",
            basicModifiers: [.damageTakenPercent(.bleed, 0.10)],
            astral: "Decreases Bleed damage taken by 25%",
            astralModifiers: [.damageTakenPercent(.bleed, 0.25)]
        ),
        affix(
            id: "lucky",
            title: "Lucky",
            slot: .trinket,
            keywords: [.gold],
            weight: 10,
            basic: "Increases Gold gained by 1",
            basicModifiers: [.goldGained(1)],
            astral: "Increases Gold gained by 4",
            astralModifiers: [.goldGained(4)]
        ),
        affix(
            id: "vampiric",
            title: "Vampiric",
            slot: .trinket,
            keywords: [.leech],
            weight: 8,
            basic: "Increases Leech granted by 5%",
            basicModifiers: [.leechGrantedPercent(0.05)],
            astral: "Increases Leech granted by 15%",
            astralModifiers: [.leechGrantedPercent(0.15)]
        ),
        affix(
            id: "bloodstone",
            title: "Bloodstone",
            slot: .trinket,
            keywords: [.leech, .health],
            weight: 8,
            basic: "Increases health restored from Leech by 1",
            basicModifiers: [.leechHealing(1)],
            astral: "Increases health restored from Leech by 3",
            astralModifiers: [.leechHealing(3)]
        ),
        affix(
            id: "lifeweave",
            title: "Lifeweave",
            slot: .armor,
            keywords: [.leech, .health],
            weight: 8,
            basic: "Increases Health restored by 1",
            basicModifiers: [.healthRestored(1)],
            astral: "Increases Health restored by 3",
            astralModifiers: [.healthRestored(3)]
        ),
        affix(
            id: "verdant",
            title: "Verdant",
            slot: .trinket,
            keywords: [.nature, .health],
            weight: 10,
            basic: "Increases Nature damage dealt by 1",
            basicModifiers: [.damageDealt(.nature, 1)],
            astral: "Increases Nature damage dealt by 2",
            astralModifiers: [.damageDealt(.nature, 2)]
        ),
        affix(
            id: "sparkling",
            title: "Sparkling",
            slot: .trinket,
            keywords: [.holy],
            weight: 8,
            basic: "Increases Holy damage dealt by 1",
            basicModifiers: [.damageDealt(.holy, 1)],
            astral: "Increases Holy damage dealt by 2",
            astralModifiers: [.damageDealt(.holy, 2)]
        ),
        affix(
            id: "steadfast",
            title: "Steadfast",
            slot: .trinket,
            keywords: [.armor, .block],
            weight: 8,
            basic: "Increases Block duration by 1 and Armor duration by 1",
            basicModifiers: [.blockDuration(1), .armorDuration(1)],
            astral: "Increases Block duration by 2 and Armor duration by 2",
            astralModifiers: [.blockDuration(2), .armorDuration(2)]
        ),
        affix(
            id: "fatebound",
            title: "Fatebound",
            slot: .trinket,
            keywords: [.holy, .gold],
            weight: 8,
            basic: "Increases Holy damage dealt by 1 and Gold gained by 1",
            basicModifiers: [.damageDealt(.holy, 1), .goldGained(1)],
            astral: "Increases Holy damage dealt by 2 and Gold gained by 4",
            astralModifiers: [.damageDealt(.holy, 2), .goldGained(4)]
        ),
        affix(
            id: "duelists",
            title: "Duelist's",
            slot: .weapon,
            keywords: [.bleed, .physical],
            weight: 8,
            basic: "Increases Agility by 1 and Bleed damage dealt by 1",
            basicModifiers: [.agility(1), .damageDealt(.bleed, 1)],
            astral: "Increases Agility by 2 and Bleed damage dealt by 2",
            astralModifiers: [.agility(2), .damageDealt(.bleed, 2)]
        ),
        affix(
            id: "crusaders",
            title: "Crusader's",
            slot: .weapon,
            keywords: [.holy, .physical],
            weight: 8,
            basic: "Increases Strength by 1 and Holy damage dealt by 1",
            basicModifiers: [.strength(1), .damageDealt(.holy, 1)],
            astral: "Increases Strength by 2 and Holy damage dealt by 2",
            astralModifiers: [.strength(2), .damageDealt(.holy, 2)]
        ),
        affix(
            id: "pyromancers",
            title: "Pyromancer's",
            slot: .weapon,
            keywords: [.burn],
            weight: 8,
            basic: "Increases Intellect by 1 and Burn damage dealt by 1",
            basicModifiers: [.intellect(1), .damageDealt(.burn, 1)],
            astral: "Increases Intellect by 2 and Burn damage dealt by 2",
            astralModifiers: [.intellect(2), .damageDealt(.burn, 2)]
        ),
        affix(
            id: "guardians",
            title: "Guardian's",
            slot: .armor,
            keywords: [.block, .armor],
            weight: 8,
            basic: "Increases Toughness by 1 and Block granted by 1",
            basicModifiers: [.toughness(1), .blockGranted(1)],
            astral: "Increases Toughness by 2 and Block granted by 2",
            astralModifiers: [.toughness(2), .blockGranted(2)]
        ),
        affix(
            id: "sentinel",
            title: "Sentinel",
            slot: .weapon,
            keywords: [.block],
            weight: 8,
            basic: "Increases Block granted by 1",
            basicModifiers: [.blockGranted(1)],
            astral: "Increases Block granted by 3",
            astralModifiers: [.blockGranted(3)]
        ),
        affix(
            id: "fortified",
            title: "Fortified",
            slot: .weapon,
            keywords: [.armor],
            weight: 8,
            basic: "Increases Armor granted by 5%",
            basicModifiers: [.armorGrantedPercent(0.05)],
            astral: "Increases Armor granted by 15%",
            astralModifiers: [.armorGrantedPercent(0.15)]
        ),
        affix(
            id: "rime",
            title: "Rime",
            slot: .trinket,
            keywords: [.freeze],
            weight: 8,
            basic: "Increases Freeze damage dealt by 1",
            basicModifiers: [.damageDealt(.freeze, 1)],
            astral: "Increases Freeze damage dealt by 2",
            astralModifiers: [.damageDealt(.freeze, 2)]
        ),
        affix(
            id: "aegis",
            title: "Aegis",
            slot: .trinket,
            keywords: [.block],
            weight: 8,
            basic: "Increases Block granted by 1",
            basicModifiers: [.blockGranted(1)],
            astral: "Increases Block granted by 3",
            astralModifiers: [.blockGranted(3)]
        ),
        affix(
            id: "etched",
            title: "Etched",
            slot: .trinket,
            keywords: [.armor],
            weight: 8,
            basic: "Increases Armor granted by 5%",
            basicModifiers: [.armorGrantedPercent(0.05)],
            astral: "Increases Armor granted by 15%",
            astralModifiers: [.armorGrantedPercent(0.15)]
        ),
        affix(
            id: "shocking",
            title: "Shocking",
            slot: .trinket,
            keywords: [.stun],
            weight: 8,
            basic: "Increases Stun damage dealt by 1",
            basicModifiers: [.damageDealt(.stun, 1)],
            astral: "Increases Stun damage dealt by 2",
            astralModifiers: [.damageDealt(.stun, 2)]
        ),
        affix(
            id: "gilded",
            title: "Gilded",
            slot: .trinket,
            keywords: [.gold],
            weight: 8,
            basic: "Increases Gold gained by 1",
            basicModifiers: [.goldGained(1)],
            astral: "Increases Gold gained by 2",
            astralModifiers: [.goldGained(2)]
        ),
        affix(
            id: "defenders",
            title: "Defender's",
            slot: .weapon,
            keywords: [.block, .armor],
            weight: 8,
            basic: "Increases Block granted by 1 and Armor granted by 5%",
            basicModifiers: [.blockGranted(1), .armorGrantedPercent(0.05)],
            astral: "Increases Block granted by 2 and Armor granted by 15%",
            astralModifiers: [.blockGranted(2), .armorGrantedPercent(0.15)]
        ),
        affix(
            id: "heartward",
            title: "Heartward",
            slot: .trinket,
            keywords: [.health],
            weight: 8,
            basic: "Increases Health restored by 1 and Maximum Health by 2",
            basicModifiers: [.healthRestored(1), .maximumHealth(2)],
            astral: "Increases Health restored by 3 and Maximum Health by 6",
            astralModifiers: [.healthRestored(3), .maximumHealth(6)]
        )
    ]

    private static func affix(
        id: String,
        title: String,
        slot: ItemSlot,
        keywords: [Keyword],
        weight: Int,
        basic: String,
        basicModifiers: [AffixModifier],
        astral: String,
        astralModifiers: [AffixModifier]
    ) -> ItemAffixDefinition {
        ItemAffixDefinition(
            id: id,
            title: title,
            slot: slot,
            keywords: Set(keywords),
            weight: weight,
            basic: ItemAffixPower(description: basic, modifiers: basicModifiers),
            astral: ItemAffixPower(description: astral, modifiers: astralModifiers)
        )
    }
}

import Foundation
import TrinketCore

enum ItemAffixCatalogSupport {
    static func affix(
        id: String,
        title: String,
        slot: ItemSlot,
        keywords: [Keyword],
        weight: Int,
        basic: ItemAffixPower,
        astral: ItemAffixPower
    ) -> ItemAffixDefinition {
        ItemAffixDefinition(
            id: id,
            title: title,
            slot: slot,
            keywords: Set(keywords),
            weight: weight,
            basic: basic,
            astral: astral
        )
    }
}

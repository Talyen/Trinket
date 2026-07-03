import Foundation

enum ItemAffixCatalog {
    static let definitions: [ItemAffixDefinition] =
        ItemAffixCatalogWeapon.definitions
            + ItemAffixCatalogArmor.definitions
            + ItemAffixCatalogTrinket.definitions
}

import Foundation
import TrinketCore

public extension InventoryItem {
    /// Resolve base-item nouns by identity, keeping attacks with the same English name distinct.
    func localizedDisplayName(locale: Locale) -> String {
        if displayName == baseType.name {
            return baseType.localizedName(locale: locale)
        }
        return ContentCopy.localized(displayName, locale: locale)
    }
}

public extension ItemBaseType {
    func localizedName(locale: Locale) -> String {
        guard let resource = ContentCopy.itemNameResource(id) else {
            return ContentCopy.localized(name, locale: locale)
        }
        return LocalizedGameText(resource, locale: locale).text
    }
}

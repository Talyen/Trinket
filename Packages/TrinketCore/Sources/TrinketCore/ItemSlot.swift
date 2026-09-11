import Foundation

public enum ItemSlot: String, CaseIterable, Identifiable, Hashable, Sendable {
    case weapon = "Weapon"
    case secondaryWeapon = "Secondary Weapon"
    case armor = "Armor"
    case accessory = "Accessory"
    case secondaryAccessory = "Secondary Accessory"
    case trinket = "Trinket"
    case secondaryTrinket = "Secondary Trinket"

    public var id: String {
        rawValue
    }

    public var baseItemSlot: Self {
        switch self {
        case .secondaryWeapon:
            .weapon
        case .secondaryAccessory:
            .accessory
        case .secondaryTrinket:
            .trinket
        default:
            self
        }
    }

    public var displayName: String {
        switch self {
        case .secondaryWeapon:
            Self.weapon.rawValue
        case .secondaryAccessory:
            Self.accessory.rawValue
        case .secondaryTrinket:
            Self.trinket.rawValue
        default:
            rawValue
        }
    }

    public var accessibilityIdentifier: String {
        "\(rawValue) item slot"
    }

    public func accepts(_ baseTypeSlot: Self) -> Bool {
        baseTypeSlot == baseItemSlot
    }
}

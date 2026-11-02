public enum ItemSlot: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
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

    /// Whether this is a secondary / off-hand slot rather than a primary slot.
    public var isSecondary: Bool {
        self != baseItemSlot
    }

    /// The pairing slot that shares this slot's base item slot, if one exists.
    public var siblingSlot: Self? {
        switch self {
        case .weapon: .secondaryWeapon
        case .secondaryWeapon: .weapon
        case .armor: nil
        case .accessory: .secondaryAccessory
        case .secondaryAccessory: .accessory
        case .trinket: .secondaryTrinket
        case .secondaryTrinket: .trinket
        }
    }

    /// Other slots that share this slot's base item slot (excluding `self`).
    public var siblingSlots: [Self] {
        siblingSlot.map { [$0] } ?? []
    }

    /// All slots that share this slot's base item slot, with the primary slot first.
    public var familySlots: [Self] {
        if let sibling = siblingSlot {
            isSecondary ? [sibling, self] : [self, sibling]
        } else {
            [self]
        }
    }

    /// The canonical primary slots: weapon, armor, accessory, and trinket.
    public static let baseSlots: [Self] = [.weapon, .armor, .accessory, .trinket]

    /// Secondary slots share their base slot's display name ("Secondary Weapon"
    /// shows as "Weapon"); `accessibilityIdentifier` keeps the full name so
    /// overlapping slots stay distinguishable to assistive tech.
    public var displayName: String {
        baseItemSlot.rawValue
    }

    public var accessibilityIdentifier: String {
        "\(rawValue) item slot"
    }

    public func accepts(_ slot: Self) -> Bool {
        slot.baseItemSlot == baseItemSlot
    }
}

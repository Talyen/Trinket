import TrinketCore
import TrinketDesignSystem

/// Display name and icon; the matching tint lives with the color tokens in
/// `TrinketDesignSystem/HomesteadResource+Color.swift`.
public extension HomesteadResource {
    var displayName: String {
        switch self {
        case .wood: String(localized: L10n.ui_homestead_wood_73114)
        case .stone: String(localized: L10n.ui_homestead_stone_6ffa6)
        case .iron: String(localized: L10n.ui_homestead_iron_bd223)
        case .food: String(localized: L10n.ui_homestead_food_e4eb1)
        case .herbs: String(localized: L10n.ui_homestead_herbs_52b83)
        case .hide: String(localized: L10n.ui_homestead_hide_ac20a)
        case .gems: String(localized: L10n.ui_homestead_gems_60243)
        case .gold: String(localized: L10n.ui_homestead_gold_6249d)
        }
    }

    var icon: GameIcon {
        switch self {
        case .wood: .system("tree.fill")
        case .stone: .system("mountain.2.fill")
        case .iron: .system("hammer.fill")
        case .food: .system("carrot.fill")
        case .herbs: .system("leaf.fill")
        case .hide: .system("square.stack.3d.up.fill")
        case .gems: .system("diamond.fill")
        case .gold: Keyword.gold.visualStyle.icon
        }
    }

    var walletAnimationID: String {
        "Homestead Wallet Resource \(rawValue)"
    }
}

public extension HomesteadNodeCategory {
    var artID: String {
        switch self {
        case .farming: "wheatField"
        case .crafting: "blacksmithForge"
        case .alchemy: "alchemyLab"
        case .training: "hunterLodge"
        case .arcana: "moonlitSanctum"
        }
    }

    var icon: GameIcon {
        switch self {
        case .farming: .system("leaf.fill")
        case .crafting: .system("hammer.fill")
        case .alchemy: .system("flask.fill")
        case .training: .system("target")
        case .arcana: .system("moon.stars.fill")
        }
    }
}

public extension [ResourceAmount] {
    var formattedYieldList: String {
        let parts = map { "\($0.quantity) \($0.resource.displayName)" }
        switch parts.count {
        case 0:
            return "nothing"
        case 1:
            return parts[0]
        case 2:
            return String(localized: L10n.ui_homestead_1_and_2_16d5b("\(parts[0])", "\(parts[1])"))
        default:
            let head = parts.dropLast().joined(separator: ", ")
            return String(localized: L10n.ui_homestead_1_and_2_2ac9d("\(head)", "\(parts[parts.count - 1])"))
        }
    }
}

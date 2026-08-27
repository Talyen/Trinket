import TrinketCore

public extension HomesteadResource {
    var displayName: String {
        switch self {
        case .wood: "Wood"
        case .stone: "Stone"
        case .iron: "Iron"
        case .food: "Food"
        case .herbs: "Herbs"
        case .hide: "Hide"
        case .crystal: "Crystal"
        case .gold: "Gold"
        }
    }

    var symbolName: String {
        switch self {
        case .wood: "tree.fill"
        case .stone: "mountain.2.fill"
        case .iron: "hammer.fill"
        case .food: "carrot.fill"
        case .herbs: "leaf.fill"
        case .hide: "pawprint.fill"
        case .crystal: "sparkles"
        case .gold: "dollarsign.circle.fill"
        }
    }

    var walletAnimationID: String {
        "Homestead Wallet Resource \(rawValue)"
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
            return "\(parts[0]) and \(parts[1])"
        default:
            let head = parts.dropLast().joined(separator: ", ")
            return "\(head), and \(parts[parts.count - 1])"
        }
    }
}

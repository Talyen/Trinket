import Foundation
import SwiftData
import TrinketContent
import TrinketCore

@Model
public final class HomesteadModel {
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \HomesteadResourceBalanceModel.homestead)
    public var resources: [HomesteadResourceBalanceModel]?
    @Relationship(deleteRule: .cascade, inverse: \HomesteadNodeTierModel.homestead)
    public var nodeTiers: [HomesteadNodeTierModel]?

    public init() {}
}

@Model
public final class HomesteadResourceBalanceModel {
    public var resourceID: String = ""
    public var quantity: Int = 0
    public var homestead: HomesteadModel?

    public init(resourceID: String = "", quantity: Int = 0) {
        self.resourceID = resourceID
        self.quantity = quantity
    }
}

@Model
public final class HomesteadNodeTierModel {
    public var nodeID: String = ""
    public var tier: Int = 0
    public var homestead: HomesteadModel?

    public init(nodeID: String = "", tier: Int = 0) {
        self.nodeID = nodeID
        self.tier = tier
    }
}

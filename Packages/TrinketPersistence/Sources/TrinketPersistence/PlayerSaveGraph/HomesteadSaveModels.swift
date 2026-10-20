import Foundation
import SwiftData
import TrinketContent
import TrinketCore

@Model
final class HomesteadModel {
    var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \HomesteadResourceBalanceModel.homestead)
    var resources: [HomesteadResourceBalanceModel]?
    @Relationship(deleteRule: .cascade, inverse: \HomesteadPendingProductionModel.homestead)
    var pendingProduction: [HomesteadPendingProductionModel]?
    @Relationship(deleteRule: .cascade, inverse: \HomesteadNodeTierModel.homestead)
    var nodeTiers: [HomesteadNodeTierModel]?
    var wishedTemplateID: String?
    var lastProductionAt: Date = Date()
    var goldRewardRemainder: Int = 0
    var gemsRewardRemainder: Int = 0

    init() {}
}

@Model
final class HomesteadResourceBalanceModel {
    var resourceID: String = ""
    var quantity: Int = 0
    var homestead: HomesteadModel?

    init(resourceID: String = "", quantity: Int = 0) {
        self.resourceID = resourceID
        self.quantity = quantity
    }
}

@Model
final class HomesteadPendingProductionModel {
    var resourceID: String = ""
    var quantity: Double = 0
    var homestead: HomesteadModel?

    init(resourceID: String = "", quantity: Double = 0) {
        self.resourceID = resourceID
        self.quantity = quantity
    }
}

@Model
final class HomesteadNodeTierModel {
    var nodeID: String = ""
    var tier: Int = 0
    var homestead: HomesteadModel?

    init(nodeID: String = "", tier: Int = 0) {
        self.nodeID = nodeID
        self.tier = tier
    }
}

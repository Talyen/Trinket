import Testing
import TrinketCore
@testable import TrinketContent

struct HomesteadCatalogTests {
    @Test func `homestead tiers have concise stage names`() throws {
        for definition in GameContent.homesteadNodes {
            for tier in definition.tiers {
                try #expect(!tier.stageName.isEmpty, "\(definition.id) tier \(tier.tier)")
                try #expect(tier.stageName.split(separator: " ").count <= 3, "\(definition.id) tier \(tier.tier)")
            }
        }
    }

    @Test func `production nodes have four tiers of one increasing resource`() throws {
        for node in GameContent.homesteadNodes {
            try #expect(node.maxTier == 4, "\(node.title) should have four tiers")
        }

        let productionNodes = GameContent.homesteadNodes.filter { definition in
            definition.tiers.contains { $0.production != nil }
        }
        try #expect(!productionNodes.isEmpty)

        for definition in productionNodes {
            let productions = definition.tiers.compactMap(\.production)
            try #expect(productions.count == 4, "\(definition.id)")
            try #expect(productions.count == definition.tiers.count, "\(definition.id)")
            let resource = try #require(productions.first?.resource)
            try #expect(productions.allSatisfy { $0.resource == resource }, "\(definition.id)")
            let quantities = productions.map(\.quantity)
            try #expect(
                zip(quantities, quantities.dropFirst()).allSatisfy { $0 < $1 },
                "\(definition.id)",
            )
        }
    }
}

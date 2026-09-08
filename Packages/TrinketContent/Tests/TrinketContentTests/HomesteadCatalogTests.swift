import Testing
import TrinketCore
@testable import TrinketContent

struct HomesteadCatalogTests {
    @Test func `homestead node IDs are unique`() throws {
        let ids = GameContent.homesteadNodes.map(\.id)
        try #expect(Set(ids).count == ids.count)
    }

    @Test func `homestead prerequisites reference known nodes`() throws {
        let knownIDs = Set(GameContent.homesteadNodes.map(\.id))
        for node in GameContent.homesteadNodes {
            for requirement in node.prerequisites {
                try #expect(
                    knownIDs.contains(requirement.nodeID),
                    "Node \(node.id) references unknown prerequisite \(requirement.nodeID)",
                )
            }
        }
    }

    @Test func `homestead tiers strengthen effects and stay party scoped`() throws {
        for node in GameContent.homesteadNodes {
            let nodeID = node.id
            let tier1 = HomesteadEffects.from(nodeTiers: [nodeID: 1])
            let tier4 = HomesteadEffects.from(nodeTiers: [nodeID: 4])
            switch nodeID {
            case .moonlitSanctum:
                try #expect(tier1.astralChanceBonusPercent == 5)
                try #expect(tier4.astralChanceBonusPercent == 20)
                try #expect(tier1.heroModifiers.isEmpty)
                try #expect(tier1.companionModifiers.isEmpty)
            case .wishingWell:
                try #expect(tier1.goldFindPercent == 5)
                try #expect(tier4.goldFindPercent == 20)
                try #expect(tier1.heroModifiers.isEmpty)
                try #expect(tier1.companionModifiers.isEmpty)
            case .hunterLodge:
                try #expect(tier1.companionModifiers.isEmpty)
                try #expect(tier4.companionModifiers.isEmpty)
                try #expect(tier1.heroModifiers.count == 1)
                try #expect(tier4.heroModifiers.count == 1)
                try #expect(tier4.heroModifiers[0].numericValue > tier1.heroModifiers[0].numericValue)
            case .agilityTraining:
                try #expect(tier1.heroModifiers.isEmpty)
                try #expect(tier4.heroModifiers.isEmpty)
                try #expect(tier1.companionModifiers.count == 1)
                try #expect(tier4.companionModifiers.count == 1)
                try #expect(
                    tier4.companionModifiers[0].numericValue > tier1.companionModifiers[0].numericValue,
                )
            default:
                try #expect(tier1.heroModifiers == tier1.companionModifiers)
                try #expect(tier4.heroModifiers == tier4.companionModifiers)
                try #expect(!tier1.heroModifiers.isEmpty)
                try #expect(tier1.heroModifiers.count == tier4.heroModifiers.count)
                for (lower, higher) in zip(tier1.heroModifiers, tier4.heroModifiers) {
                    try #expect(higher.numericValue > lower.numericValue)
                }
            }
        }
    }

    @Test func `homestead combat bonuses match authored tier values`() {
        let culinary = HomesteadEffects.from(nodeTiers: [.culinaryArts: 1])
        #expect(culinary.heroModifiers == [.damageTakenPercent(.burn, 0.10)])
        #expect(culinary.companionModifiers == culinary.heroModifiers)

        let culinaryMax = HomesteadEffects.from(nodeTiers: [.culinaryArts: 4])
        #expect(culinaryMax.heroModifiers == [.damageTakenPercent(.burn, 0.40)])

        let wool = HomesteadEffects.from(nodeTiers: [.woolTailoring: 1])
        #expect(wool.heroModifiers == [.damageTakenPercent(.freeze, 0.15)])
        let woolMax = HomesteadEffects.from(nodeTiers: [.woolTailoring: 4])
        #expect(woolMax.heroModifiers == [.damageTakenPercent(.freeze, 0.5)])

        let alchemy = HomesteadEffects.from(nodeTiers: [.alchemyLab: 1])
        #expect(alchemy.heroModifiers == [
            .poisonDamageDealtPercent(0.05),
            .damageTakenPercent(.poison, 0.10),
        ])
        #expect(alchemy.companionModifiers == alchemy.heroModifiers)

        let lodge = HomesteadEffects.from(nodeTiers: [.hunterLodge: 4])
        #expect(lodge.heroModifiers == [.companionDamageDealt(4)])
        #expect(lodge.companionModifiers.isEmpty)

        let agility = HomesteadEffects.from(nodeTiers: [.agilityTraining: 2])
        #expect(agility.heroModifiers.isEmpty)
        #expect(agility.companionModifiers == [.dodgeChanceBonus(0.04)])
    }

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

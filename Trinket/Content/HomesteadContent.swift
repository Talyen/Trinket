import SwiftUI

extension GameContent {
    static let homesteadNodes: [HomesteadNodeDefinition] = [
        HomesteadNodeDefinition(
            id: .hearth,
            title: "Hearth",
            summary: "The warm center of the Homestead and the trunk for future growth.",
            symbolName: "flame.fill",
            tint: .red,
            branch: .trunk,
            prerequisites: [],
            tiers: [
                HomesteadNodeTier(
                    tier: 1,
                    cost: [ResourceAmount(.wood, 12), ResourceAmount(.stone, 6)],
                    bonus: HomesteadBonus(
                        title: "Homestead Founded",
                        description: "Unlocks the first construction projects."
                    )
                ),
                HomesteadNodeTier(
                    tier: 2,
                    cost: [ResourceAmount(.wood, 24), ResourceAmount(.stone, 16), ResourceAmount(.food, 8)],
                    bonus: HomesteadBonus(
                        title: "Settled Rhythm",
                        description: "Material rewards from stages gain +1 when present."
                    )
                ),
                HomesteadNodeTier(
                    tier: 3,
                    cost: [ResourceAmount(.wood, 40), ResourceAmount(.stone, 28), ResourceAmount(.iron, 10), ResourceAmount(.gold, 45)],
                    bonus: HomesteadBonus(
                        title: "Village Anchor",
                        description: "Unlocks advanced Homestead branches and reinforces resource gains."
                    )
                )
            ]
        ),
        HomesteadNodeDefinition(
            id: .lumberCamp,
            title: "Lumber Camp",
            summary: "A practical camp that turns forest routes into steady building supplies.",
            symbolName: "tree.fill",
            tint: .brown,
            branch: .left,
            prerequisites: [HomesteadNodeRequirement(.hearth)],
            tiers: [
                HomesteadNodeTier(
                    tier: 1,
                    cost: [ResourceAmount(.wood, 8), ResourceAmount(.gold, 10)],
                    bonus: HomesteadBonus(
                        title: "Wood Routes",
                        description: "Stages can award Wood for Homestead construction."
                    )
                ),
                HomesteadNodeTier(
                    tier: 2,
                    cost: [ResourceAmount(.wood, 20), ResourceAmount(.stone, 8), ResourceAmount(.gold, 20)],
                    bonus: HomesteadBonus(
                        title: "Better Axes",
                        description: "Wood rewards from stages gain +1 when present."
                    )
                ),
                HomesteadNodeTier(
                    tier: 3,
                    cost: [ResourceAmount(.wood, 36), ResourceAmount(.stone, 18), ResourceAmount(.iron, 6), ResourceAmount(.gold, 35)],
                    bonus: HomesteadBonus(
                        title: "Seasoned Crew",
                        description: "Wood-heavy projects become easier to sustain."
                    )
                )
            ]
        ),
        HomesteadNodeDefinition(
            id: .stoneYard,
            title: "Stone Yard",
            summary: "A quarry yard for durable walls, roads, and future workshops.",
            symbolName: "mountain.2.fill",
            tint: .gray,
            branch: .right,
            prerequisites: [HomesteadNodeRequirement(.hearth)],
            tiers: [
                HomesteadNodeTier(
                    tier: 1,
                    cost: [ResourceAmount(.wood, 10), ResourceAmount(.stone, 10), ResourceAmount(.gold, 12)],
                    bonus: HomesteadBonus(
                        title: "Stone Routes",
                        description: "Stages can award Stone for sturdier construction."
                    )
                ),
                HomesteadNodeTier(
                    tier: 2,
                    cost: [ResourceAmount(.wood, 18), ResourceAmount(.stone, 24), ResourceAmount(.gold, 24)],
                    bonus: HomesteadBonus(
                        title: "Cut Stone",
                        description: "Stone rewards from stages gain +1 when present."
                    )
                ),
                HomesteadNodeTier(
                    tier: 3,
                    cost: [ResourceAmount(.stone, 44), ResourceAmount(.iron, 8), ResourceAmount(.gold, 38)],
                    bonus: HomesteadBonus(
                        title: "Foundation Work",
                        description: "Major buildings gain a stronger construction base."
                    )
                )
            ]
        ),
        HomesteadNodeDefinition(
            id: .garden,
            title: "Garden",
            summary: "A living branch for food stores, herbs, and gentler journey support.",
            symbolName: "leaf.fill",
            tint: .green,
            branch: .left,
            prerequisites: [HomesteadNodeRequirement(.lumberCamp)],
            tiers: [
                HomesteadNodeTier(
                    tier: 1,
                    cost: [ResourceAmount(.wood, 18), ResourceAmount(.stone, 6), ResourceAmount(.food, 8), ResourceAmount(.gold, 16)],
                    bonus: HomesteadBonus(
                        title: "Seed Beds",
                        description: "Stages can award Food and Herbs."
                    )
                ),
                HomesteadNodeTier(
                    tier: 2,
                    cost: [ResourceAmount(.wood, 28), ResourceAmount(.food, 18), ResourceAmount(.herbs, 8), ResourceAmount(.gold, 28)],
                    bonus: HomesteadBonus(
                        title: "Tended Rows",
                        description: "Food and Herb rewards from stages gain +1 when present."
                    )
                ),
                HomesteadNodeTier(
                    tier: 3,
                    cost: [ResourceAmount(.wood, 36), ResourceAmount(.stone, 18), ResourceAmount(.food, 28), ResourceAmount(.herbs, 16), ResourceAmount(.gold, 42)],
                    bonus: HomesteadBonus(
                        title: "Harvest Stores",
                        description: "Rest and Event rewards can lean further into Food and Herbs."
                    )
                )
            ]
        ),
        HomesteadNodeDefinition(
            id: .blacksmithWorkshop,
            title: "Blacksmith's Workshop",
            summary: "A forge for metalwork, item support, and focused Physical power.",
            symbolName: "hammer.fill",
            tint: .orange,
            branch: .right,
            prerequisites: [
                HomesteadNodeRequirement(.stoneYard),
                HomesteadNodeRequirement(.lumberCamp)
            ],
            tiers: [
                HomesteadNodeTier(
                    tier: 1,
                    cost: [ResourceAmount(.wood, 22), ResourceAmount(.stone, 18), ResourceAmount(.iron, 8), ResourceAmount(.gold, 24)],
                    bonus: HomesteadBonus(
                        title: "Working Forge",
                        description: "Stages can award Iron for advanced construction."
                    )
                ),
                HomesteadNodeTier(
                    tier: 2,
                    cost: [ResourceAmount(.wood, 30), ResourceAmount(.stone, 28), ResourceAmount(.iron, 18), ResourceAmount(.gold, 40)],
                    bonus: HomesteadBonus(
                        title: "Sharper Tools",
                        description: "Iron rewards from stages gain +1 when present."
                    )
                ),
                HomesteadNodeTier(
                    tier: 3,
                    cost: [ResourceAmount(.stone, 42), ResourceAmount(.iron, 32), ResourceAmount(.crystal, 4), ResourceAmount(.gold, 60)],
                    bonus: HomesteadBonus(
                        title: "Tempered Edge",
                        description: "Future combat tuning can grant a small Physical damage bonus."
                    )
                )
            ]
        ),
        HomesteadNodeDefinition(
            id: .alchemistsLab,
            title: "Alchemist's Lab",
            summary: "A precise workspace for herbs, tonics, and restorative experiments.",
            symbolName: "testtube.2",
            tint: .mint,
            branch: .left,
            prerequisites: [
                HomesteadNodeRequirement(.garden, tier: 2),
                HomesteadNodeRequirement(.stoneYard)
            ],
            tiers: [
                HomesteadNodeTier(
                    tier: 1,
                    cost: [ResourceAmount(.stone, 18), ResourceAmount(.food, 12), ResourceAmount(.herbs, 14), ResourceAmount(.gold, 28)],
                    bonus: HomesteadBonus(
                        title: "Herbal Workbench",
                        description: "Unlocks Herb spending for support upgrades."
                    )
                ),
                HomesteadNodeTier(
                    tier: 2,
                    cost: [ResourceAmount(.stone, 28), ResourceAmount(.herbs, 26), ResourceAmount(.crystal, 3), ResourceAmount(.gold, 44)],
                    bonus: HomesteadBonus(
                        title: "Restorative Notes",
                        description: "Future utility tuning can improve rest and healing rewards."
                    )
                ),
                HomesteadNodeTier(
                    tier: 3,
                    cost: [ResourceAmount(.iron, 10), ResourceAmount(.herbs, 42), ResourceAmount(.crystal, 8), ResourceAmount(.gold, 66)],
                    bonus: HomesteadBonus(
                        title: "Refined Reagents",
                        description: "Future combat tuning can support Health, Poison, or Nature effects."
                    )
                )
            ]
        ),
        HomesteadNodeDefinition(
            id: .arcaneTower,
            title: "Arcane Tower",
            summary: "A late branch for crystal work, rare rewards, and magical study.",
            symbolName: "sparkles",
            tint: .purple,
            branch: .right,
            prerequisites: [
                HomesteadNodeRequirement(.hearth, tier: 3),
                HomesteadNodeRequirement(.blacksmithWorkshop, tier: 2)
            ],
            tiers: [
                HomesteadNodeTier(
                    tier: 1,
                    cost: [ResourceAmount(.stone, 30), ResourceAmount(.iron, 14), ResourceAmount(.crystal, 8), ResourceAmount(.gold, 45)],
                    bonus: HomesteadBonus(
                        title: "Crystal Focus",
                        description: "Unlocks Crystal spending for magical Homestead upgrades."
                    )
                ),
                HomesteadNodeTier(
                    tier: 2,
                    cost: [ResourceAmount(.stone, 42), ResourceAmount(.iron, 22), ResourceAmount(.crystal, 16), ResourceAmount(.gold, 70)],
                    bonus: HomesteadBonus(
                        title: "Resonant Study",
                        description: "Crystal rewards from stages gain +1 when present."
                    )
                ),
                HomesteadNodeTier(
                    tier: 3,
                    cost: [ResourceAmount(.iron, 34), ResourceAmount(.herbs, 24), ResourceAmount(.crystal, 30), ResourceAmount(.gold, 100)],
                    bonus: HomesteadBonus(
                        title: "Attuned Spire",
                        description: "Future combat tuning can support non-Physical keyword bonuses."
                    )
                )
            ]
        )
    ]

    static func homesteadNode(matching id: HomesteadNodeID) -> HomesteadNodeDefinition? {
        homesteadNodes.first { $0.id == id }
    }
}

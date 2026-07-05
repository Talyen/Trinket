import TrinketContent
import TrinketCore
import TrinketPersistence

enum HomesteadProgression {
    static func recommendedProject(
        definitions: [HomesteadNodeDefinition],
        screen: HomesteadScreenState
    ) -> HomesteadNodeDefinition? {
        let statuses = definitions.map { screen.projectStatus(for: $0) }

        return statuses.first(where: \.canBuildOrUpgrade)?.definition
            ?? statuses.first(where: { $0.isUnlocked && !$0.isComplete })?.definition
            ?? statuses.first(where: { !$0.isUnlocked })?.definition
            ?? statuses.first?.definition
    }

    static func visibleDefinitions(
        in category: HomesteadNodeCategory,
        all definitions: [HomesteadNodeDefinition],
        homestead: PlayerHomesteadState
    ) -> [HomesteadNodeDefinition] {
        let categoryDefinitions = definitions.filter { $0.category == category }
        let visible = categoryDefinitions.filter { definition in
            homestead.tier(for: definition.id) > 0 || homestead.isUnlocked(definition)
        }

        guard let nextLocked = categoryDefinitions.first(where: { definition in
            !visible.contains(definition) && shouldRevealLocked(definition, homestead: homestead)
        }) else {
            return visible
        }

        return visible + [nextLocked]
    }

    static func walletResources(
        for featured: HomesteadNodeDefinition?,
        screen: HomesteadScreenState
    ) -> [HomesteadResource] {
        var resources = HomesteadResource.allCases.filter { screen.balance(for: $0) > 0 }
        if let featured,
           let nextTier = screen.homestead.nextTier(for: featured) {
            for amount in nextTier.cost where !resources.contains(amount.resource) {
                resources.append(amount.resource)
            }
        }
        return resources.isEmpty ? [.wood, .stone, .gold] : resources
    }

    private static func shouldRevealLocked(
        _ definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadState
    ) -> Bool {
        guard !definition.prerequisites.isEmpty else { return true }
        return definition.prerequisites.allSatisfy { requirement in
            guard let prerequisite = GameContent.homesteadNode(matching: requirement.nodeID) else {
                return false
            }
            return homestead.tier(for: requirement.nodeID) > 0 || homestead.isUnlocked(prerequisite)
        }
    }
}

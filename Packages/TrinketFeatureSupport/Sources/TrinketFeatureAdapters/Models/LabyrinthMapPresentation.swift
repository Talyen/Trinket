import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

public enum LabyrinthMapNodeState: Equatable {
    case locked
    case reachable
    case cleared
}

public enum LabyrinthMapPresentation {
    public static func floorNodes(
        for cluster: LabyrinthCluster,
        in state: PlayerLabyrinthState
    ) -> [LabyrinthNode] {
        cluster.nodeIDs.compactMap { state.nodes[$0] }.sorted {
            let left = $0.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1)
            let right = $1.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1)
            return left.row == right.row ? left.column < right.column : left.row < right.row
        }
    }

    public static func effectiveType(
        for node: LabyrinthNode,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> LabyrinthNodeType {
        guard node.type.canonical == .recruit else { return node.type.canonical }
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: node.recruitEventID,
            encounterID: node.id,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs
        )
        if case .mystery = resolution {
            return .mystery
        }
        return .recruit
    }

    public static func state(
        for node: LabyrinthNode,
        in labyrinth: PlayerLabyrinthState
    ) -> LabyrinthMapNodeState {
        if node.isCleared {
            return .cleared
        }
        return labyrinth.isNodeReachable(node.id) ? .reachable : .locked
    }

    public static func actionTitle(
        for _: LabyrinthNode,
        type: LabyrinthNodeType
    ) -> String {
        switch type.canonical {
        case .battle: "Battle"
        case .boss: "Challenge Boss"
        case .shop: "Visit Shop"
        case .rest: "Rest at Shrine"
        case .mystery, .event: "Approach Mystery"
        case .recruit: "Recruit"
        case .craft: "Use Crafting Altar"
        case .entrance: "Enter Labyrinth"
        }
    }

    public static func tint(for type: LabyrinthNodeType) -> Color {
        switch type.canonical {
        case .battle, .boss: TrinketDesign.Colors.encounterBattle
        case .shop: TrinketDesign.Colors.encounterShop
        case .rest: TrinketDesign.Colors.encounterRest
        case .mystery, .event, .recruit, .craft, .entrance:
            TrinketDesign.Colors.encounterEvent
        }
    }

    public static func symbolName(
        for type: LabyrinthNodeType,
        recruitEventID: String?
    ) -> String {
        if type.canonical == .recruit {
            return GameContent.recruitEncounterSymbolName(forEventID: recruitEventID)
        }
        return type.symbolName
    }
}

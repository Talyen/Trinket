import SwiftUI
import TrinketContent
import TrinketDesignSystem

public enum LabyrinthMapNodeState: Equatable {
    case locked
    case reachable
    case cleared
}

public enum LabyrinthMapPresentation {
    public static func effectiveType(
        for node: LabyrinthNode,
        worldSeed: UInt64,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>,
        access: ContentAccessPolicy = .fullGame,
    ) -> LabyrinthNodeType {
        guard node.type == .recruit else { return node.type }
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: node.recruitEventID,
            encounterID: node.id,
            worldSeed: worldSeed,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs,
            access: access,
        )
        if case .mystery = resolution {
            return .mystery
        }
        return .recruit
    }

    public static func actionTitle(
        for _: LabyrinthNode,
        type: LabyrinthNodeType,
    ) -> String {
        switch type {
        case .battle: "Battle"
        case .boss: "Challenge Boss"
        case .shop: "Visit Shop"
        case .mystery: "Approach Mystery"
        case .recruit: "Recruit"
        case .entrance: "Enter Labyrinth"
        }
    }

    public static func tint(for type: LabyrinthNodeType) -> Color {
        switch type {
        case .battle, .boss:
            TrinketDesign.Colors.encounterBattle
        case .shop:
            TrinketDesign.Colors.encounterShop
        case .mystery, .recruit, .entrance:
            TrinketDesign.Colors.encounterEvent
        }
    }

    public static func icon(
        for type: LabyrinthNodeType,
        recruitEventID: String?,
    ) -> GameIcon {
        if type == .recruit {
            return GameIcon(id: GameContent.recruitEncounterIconID(forEventID: recruitEventID))
        }
        return GameIcon(id: type.iconID)
    }

    public static func recruitEncounterArtReference(
        for node: LabyrinthNode,
        worldSeed: UInt64,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>,
        access: ContentAccessPolicy = .fullGame,
    ) -> EncounterArtReference? {
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: node.recruitEventID,
            encounterID: node.id,
            worldSeed: worldSeed,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs,
            access: access,
        )
        guard case let .recruit(event) = resolution else { return nil }
        return GameContent.recruitEncounterArtReference(for: event)
    }

    public static func destinationEncounterArtID(for type: LabyrinthNodeType) -> String? {
        switch type {
        case .shop: "destination-merchant-shop"
        case .battle, .boss, .mystery, .recruit, .entrance:
            nil
        }
    }

    public static func hexRadius(
        forAvailableWidth availableWidth: CGFloat,
        edgePad: CGFloat = 0,
    ) -> CGFloat {
        let usableWidth = max(1, availableWidth - edgePad * 2)
        let columns = CGFloat(LabyrinthMapLayout.fullColumnsAcross)
        return usableWidth / (columns * CGFloat(3).squareRoot())
    }
}

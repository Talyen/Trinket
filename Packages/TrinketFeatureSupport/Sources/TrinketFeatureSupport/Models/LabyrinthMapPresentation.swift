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
        unlockedCompanionIDs: Set<String>
    ) -> LabyrinthNodeType {
        guard node.type.canonical == .recruit else { return node.type.canonical }
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: node.recruitEventID,
            encounterID: node.id,
            worldSeed: worldSeed,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs
        )
        if case .mystery = resolution {
            return .mystery
        }
        return .recruit
    }

    public static func actionTitle(
        for _: LabyrinthNode,
        type: LabyrinthNodeType
    ) -> String {
        switch type.canonical {
        case .battle: "Battle"
        case .boss: "Challenge Boss"
        case .shop: "Visit Shop"
        case .rest: "Rest at Campfire"
        case .mystery, .event, .craft: "Approach Mystery"
        case .recruit: "Recruit"
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
        // The Campfire flame is Labyrinth-only; Journey's rest stage keeps the shared symbol.
        if type.canonical == .rest {
            return "flame.fill"
        }
        return type.symbolName
    }

    /// Seeded recruit scene art for map seals and inspectors; nil when the node falls back to mystery.
    public static func recruitEncounterArtReference(
        for node: LabyrinthNode,
        worldSeed: UInt64,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> EncounterArtReference? {
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: node.recruitEventID,
            encounterID: node.id,
            worldSeed: worldSeed,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs
        )
        guard case let .recruit(event) = resolution else { return nil }
        return GameContent.recruitEncounterArtReference(for: event)
    }

    /// Shared destination encounter art for Labyrinth map seals and inspectors.
    public static func destinationEncounterArtID(for type: LabyrinthNodeType) -> String? {
        switch type.canonical {
        case .shop: "destination-merchant-shop"
        case .rest: "destination-campfire"
        case .battle, .boss, .mystery, .event, .recruit, .craft, .entrance:
            nil
        }
    }

    /// Pointy-top hex radius that fills `availableWidth` for
    /// `LabyrinthMapLayout.fullColumnsAcross` columns edge-to-edge.
    public static func hexRadius(
        forAvailableWidth availableWidth: CGFloat,
        edgePad: CGFloat = 0
    ) -> CGFloat {
        let usableWidth = max(1, availableWidth - edgePad * 2)
        let columns = CGFloat(LabyrinthMapLayout.fullColumnsAcross)
        return usableWidth / (columns * CGFloat(3).squareRoot())
    }
}

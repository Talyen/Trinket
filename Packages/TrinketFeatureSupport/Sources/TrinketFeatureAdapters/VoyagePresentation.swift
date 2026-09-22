import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public extension StageSelectRowPresentation where Item == VoyageOffer {
    static func voyageOffers(_ offers: [VoyageOffer]) -> [Self] {
        offers.map { offer in
            Self(
                item: offer, isActive: true, activeEyebrow: offer.difficulty.title, mapLabel: offer.difficulty.title,
                title: GameContent.chapter(id: offer.chapterID)?.title ?? "Voyage", encounterTypeTitle: "Voyage",
                icon: .system("location.north.fill"), tint: TrinketDesign.Colors.accent, primaryActionTitle: "Embark",
                showsPartyPicker: true, isArtworkInteractive: false,
                rowAccessibilityID: AccessibilityID.Voyage.row(offer.difficulty.rawValue),
                artworkAccessibilityID: AccessibilityID.Voyage.artwork(offer.difficulty.rawValue),
                actionAccessibilityID: AccessibilityID.Voyage.action(offer.difficulty.rawValue),
                activeDetailAccessibilityID: AccessibilityID.Voyage.detail(offer.difficulty.rawValue),
                partyControlAccessibilityID: AccessibilityID.Voyage.party(offer.difficulty.rawValue),
            )
        }
    }
}

public extension StageSelectRowPresentation where Item == VoyageNode {
    static func voyageNodes(_ run: VoyageRun) -> [Self] {
        run.nodes.enumerated().map { index, node in
            let label = "Node \(index + 1)"
            return Self(
                item: node, isActive: node.id == run.nextNode?.id, activeEyebrow: label,
                mapLabel: label, title: node.enemyID.flatMap { GameContent.enemy(matching: $0)?.name } ?? node.type.title,
                encounterTypeTitle: node.isCleared ? "Completed" : node.type.title,
                icon: GameIcon(id: node.type.iconID), tint: LabyrinthMapPresentation.tint(for: node.type),
                primaryActionTitle: node.type.isCombat ? "Battle" : node.type.primaryActionTitle,
                showsPartyPicker: node.type.isCombat, isArtworkInteractive: true,
                rowAccessibilityID: AccessibilityID.Voyage.row(node.id),
                artworkAccessibilityID: AccessibilityID.Voyage.artwork(node.id),
                actionAccessibilityID: AccessibilityID.Voyage.action(node.id),
                activeDetailAccessibilityID: AccessibilityID.Voyage.detail(node.id),
                partyControlAccessibilityID: AccessibilityID.Voyage.party(node.id),
                modifiers: LabyrinthCatalog.modifiers(ids: node.modifierIDs), allowsCompactInspection: true,
            )
        }
    }
}

import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public extension StageSelectRowPresentation where Item == VoyageOffer {
    static func voyageOffers(_ offers: [VoyageOffer], inventory: PlayerInventoryState) -> [Self] {
        offers.map { offer in
            let modifier = offer.rewardModifier.resolved(
                ownedTrinketIDs: inventory.ownedTrinketIDs, ownedUniqueIDs: inventory.ownedUniqueIDs,
            )
            return Self(
                item: offer, isActive: true, activeEyebrow: offer.difficulty.title, mapLabel: offer.difficulty.title,
                title: GameContent.chapter(id: offer.chapterID)?.title ?? String(localized: L10n.ui_voyagepresentation_voyage_10d91),
                encounterTypeTitle: String(localized: L10n.ui_voyagepresentation_voyage_10d91),
                icon: .system("location.north.fill"), tint: TrinketDesign.Colors.accent,
                primaryActionTitle: String(localized: L10n.ui_voyagepresentation_embark_883ea),
                showsPartyPicker: true, isArtworkInteractive: false,
                rowAccessibilityID: AccessibilityID.Voyage.row(offer.difficulty.rawValue),
                artworkAccessibilityID: AccessibilityID.Voyage.artwork(offer.difficulty.rawValue),
                actionAccessibilityID: AccessibilityID.Voyage.action(offer.difficulty.rawValue),
                activeDetailAccessibilityID: AccessibilityID.Voyage.detail(offer.difficulty.rawValue),
                partyControlAccessibilityID: AccessibilityID.Voyage.party(offer.difficulty.rawValue),
                modifiers: [ModifierCaptionPresentation(modifier)],
            )
        }
    }
}

public extension StageSelectRowPresentation where Item == VoyageNode {
    static func voyageNodes(_ run: VoyageRun, inventory: PlayerInventoryState) -> [Self] {
        run.nodes.filter { !$0.isCleared }.map { node in
            let isActive = node.id == run.nextNode?.id
            return Self(
                item: node, isActive: isActive, activeEyebrow: "",
                mapLabel: "", title: node.enemyID.flatMap { GameContent.enemy(matching: $0)?.name } ?? node.type.title,
                encounterTypeTitle: node.type.title,
                icon: GameIcon(id: node.type.iconID), tint: LabyrinthMapPresentation.tint(for: node.type),
                primaryActionTitle: node.type.isCombat ? String(localized: L10n.ui_voyagepresentation_battle_1b18e) : node.type
                    .primaryActionTitle,
                showsPartyPicker: node.type.isCombat, isArtworkInteractive: node.type.isCombat,
                rowAccessibilityID: AccessibilityID.Voyage.row(node.id),
                artworkAccessibilityID: AccessibilityID.Voyage.artwork(node.id),
                actionAccessibilityID: AccessibilityID.Voyage.action(node.id),
                activeDetailAccessibilityID: AccessibilityID.Voyage.detail(node.id),
                partyControlAccessibilityID: AccessibilityID.Voyage.party(node.id),
                modifiers: isActive
                    ? RewardOwnership(inventory).modifiers(ids: node.modifierIDs, enemyIsBoss: node.type == .boss)
                    .map(ModifierCaptionPresentation.init)
                    : [],
                allowsCompactInspection: node.type.isCombat,
            )
        }
    }
}

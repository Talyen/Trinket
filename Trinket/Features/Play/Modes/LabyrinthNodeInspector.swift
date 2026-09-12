import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct LabyrinthNodeInspector: View {
    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.presentPlayCombatantDetail) private var presentPlayCombatantDetail

    let node: LabyrinthNode
    let state: PlayerLabyrinthState
    let onMessage: (StageMapMessage) -> Void

    private var type: LabyrinthNodeType {
        LabyrinthMapPresentation.effectiveType(
            for: node,
            worldSeed: playerSave.worldSeed,
            unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
            unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs,
            access: playerSave.contentAccess,
        )
    }

    private var presentation: StageSelectRowPresentation<LabyrinthNode> {
        StageSelectRowPresentation.labyrinthRow(
            for: node,
            type: type,
            title: subjectTitle,
            isArtworkInteractive: enemyDetail != nil,
        )
    }

    var body: some View {
        StageSelectActiveCard(
            presentation: presentation,
            isPrimaryActionDisabled: isBattleActive,
            onArtworkTap: {
                if let enemyDetail {
                    presentPlayCombatantDetail(enemyDetail)
                }
            },
            onPrimaryAction: {
                if let message = labyrinth.handleNodeAction(nodeID: node.id) {
                    onMessage(message)
                    return false
                }
                return true
            },
            artwork: {
                LabyrinthNodeArtwork(
                    node: node,
                    type: type,
                    resolvedMysteryEvent: labyrinth.previewMysteryEvent(for: node),
                    style: .inspector,
                )
            },
            partyPickerSheet: {
                StageBattlePartyPickerSheet()
            },
            artworkAccessory: {
                modifierArtworkCaption
            },
        )
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthNodeInspector)
    }

    private var subjectTitle: String {
        guard type.isCombat,
              let enemyID = node.enemyID,
              let enemy = GameContent.enemy(matching: enemyID)
        else { return type.title }
        return enemy.combatant.name
    }

    private var enemyDetail: CombatantCardDetail? {
        guard let encounter = labyrinth.resolvedEncounter(for: node) else {
            return nil
        }
        return CombatantCardDetail(
            combatant: encounter.combatant,
            progression: .at(level: encounter.level),
            labyrinthModifiers: LabyrinthCatalog.modifiers(ids: node.modifierIDs),
        )
    }

    private var modifiers: [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers(ids: node.modifierIDs)
    }

    @ViewBuilder
    private var modifierArtworkCaption: some View {
        if !modifiers.isEmpty {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(modifiers) { modifier in
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                        HStack(spacing: TrinketDesign.Spacing.small) {
                            GameIconImage(modifierIcon(for: modifier))
                                .symbolRenderingMode(.hierarchical)
                                .accessibilityHidden(true)
                            Text(balanced: modifier.title.uppercased())
                                .trinketFittedText()
                        }
                        .trinketTypography(.eyebrow)
                        .trinketOnArtText(.title)

                        KeywordDescriptionText(text: modifier.effect.description)
                            .trinketTypography(.footnote)
                            .trinketOnArtText(.eyebrow)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Spacing.medium)
            .padding(.top, TrinketDesign.Spacing.extraLarge)
            .padding(.bottom, TrinketDesign.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [
                        .clear,
                        TrinketDesign.Colors.Overlay.ink.opacity(0.82),
                    ],
                    startPoint: .top,
                    endPoint: .bottom,
                )
            }
            .allowsHitTesting(false)
        }
    }

    private func modifierIcon(for modifier: LabyrinthModifierDefinition) -> GameIcon {
        switch modifier.id.rawValue {
        case "ironPressure": Keyword.physical.visualStyle.icon
        case "ashTithe": Keyword.burn.visualStyle.icon
        case "bloodMarket": Keyword.bleed.visualStyle.icon
        case "serpentBloom": Keyword.poison.visualStyle.icon
        case "rimeTax", "frostboundWard": Keyword.freeze.visualStyle.icon
        case "sunTithe": Keyword.holy.visualStyle.icon
        case "concussionToll": Keyword.stun.visualStyle.icon
        case "bulwarkBargain", "wardedFlesh": Keyword.block.visualStyle.icon
        case "vampiricLedger": Keyword.leech.visualStyle.icon
        case "bountyMark": Keyword.gold.visualStyle.icon
        case "scholarsToll": .system("book.fill")
        case "scavengersLuck": .system("shippingbox.fill")
        case "shopDiscount": .system("percent")
        case "appraisersEye": .system("eye.fill")
        default: .system("sparkles")
        }
    }
}

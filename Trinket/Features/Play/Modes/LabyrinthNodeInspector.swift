import SwiftUI
import TrinketAppState
import TrinketContent
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
            unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs
        )
    }

    private var presentation: StageSelectRowPresentation<LabyrinthNode> {
        StageSelectRowPresentation.labyrinthRow(
            for: node,
            type: type,
            title: subjectTitle,
            isArtworkInteractive: enemyDetail != nil
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
                }
            },
            artwork: {
                LabyrinthNodeArtwork(
                    node: node,
                    type: type,
                    resolvedMysteryEvent: labyrinth.previewMysteryEvent(for: node),
                    style: .inspector
                )
            },
            partyPickerSheet: {
                StageBattlePartyPickerSheet()
            },
            artworkAccessory: {
                modifierArtworkCaption
            }
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
            labyrinthModifiers: LabyrinthCatalog.modifiers(ids: node.modifierIDs)
        )
    }

    private var modifiers: [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers(ids: node.modifierIDs)
    }

    @ViewBuilder
    private var modifierArtworkCaption: some View {
        if !modifiers.isEmpty {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(modifiers) { modifier in
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                        HStack(spacing: TrinketDesign.Metrics.denseSpacing) {
                            Image(systemName: modifierSymbolName(for: modifier))
                                .symbolRenderingMode(.hierarchical)
                            Text(modifier.title.uppercased())
                        }
                        .trinketTypography(.eyebrow)
                        .trinketOnArtText(.title)

                        Text(modifier.effect.description)
                            .trinketTypography(.footnote)
                            .trinketOnArtText(.eyebrow)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
            .padding(.top, TrinketDesign.Metrics.extraLargeSpacing)
            .padding(.bottom, TrinketDesign.Metrics.mediumSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [
                        .clear,
                        TrinketDesign.Colors.Overlay.ink.opacity(0.82),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
        }
    }

    private func modifierSymbolName(for modifier: LabyrinthModifierDefinition) -> String {
        switch modifier.id.rawValue {
        case "ironPressure": "burst.fill"
        case "ashTithe": "flame.fill"
        case "bloodMarket", "serpentBloom": "drop.fill"
        case "rimeTax", "frostboundWard": "snowflake"
        case "sunTithe": "sun.max.fill"
        case "concussionToll": "bolt.fill"
        case "bulwarkBargain", "wardedFlesh": "shield.fill"
        case "vampiricLedger": "heart.fill"
        case "bountyMark": "banknote.fill"
        case "scholarsToll": "book.fill"
        case "scavengersLuck": "shippingbox.fill"
        case "shopDiscount": "percent"
        case "appraisersEye": "eyeball"
        default: "sparkles"
        }
    }
}

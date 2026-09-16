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
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.presentPlayCombatantDetail) private var presentPlayCombatantDetail

    let node: LabyrinthNode
    let type: LabyrinthNodeType
    let resolvedMysteryEvent: MysteryEvent?
    let recruitArtwork: EncounterArtReference?
    let onPrimaryAction: () -> Bool

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
            onPrimaryAction: onPrimaryAction,
            artwork: {
                LabyrinthNodeArtwork(
                    node: node,
                    type: type,
                    resolvedMysteryEvent: resolvedMysteryEvent,
                    recruitArtwork: recruitArtwork,
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
        return makePlayEnemyDetail(
            combatant: encounter.combatant,
            level: encounter.level,
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
                            GameIconImage(LabyrinthModifierPresentation.style(for: modifier).icon)
                                .symbolRenderingMode(.hierarchical)
                                .accessibilityHidden(true)
                            Text(balanced: modifier.title.uppercased())
                                .trinketFittedText()
                        }
                        .trinketTypography(.eyebrow)
                        .foregroundStyle(LabyrinthModifierPresentation.style(for: modifier).color)
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
}

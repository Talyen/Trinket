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
    @Environment(PlayerSaveStore.self) private var playerSave

    let node: LabyrinthNode
    let type: LabyrinthNodeType
    let resolvedMysteryEvent: MysteryEvent?
    let recruitArtwork: EncounterArtReference?
    let onPrimaryAction: () -> Bool

    private var isPaywalled: Bool {
        guard let cluster = playerSave.labyrinth.cluster(for: node.id) else { return false }
        return !playerSave.contentAccess.allowsLabyrinthFloor(cluster.depthBand)
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
            isLockedContent: isPaywalled,
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
            nodeModifiers: RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs),
        )
    }

    private var modifiers: [NodeModifierDefinition] {
        RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs)
    }

    private var modifierArtworkCaption: some View {
        StageSelectModifierCaption(modifiers: modifiers.map(ModifierCaptionPresentation.init))
    }
}

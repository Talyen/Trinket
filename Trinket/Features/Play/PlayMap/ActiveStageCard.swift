import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ActiveStageCard: View {
    let stage: Stage
    let activeHero: Combatant
    let activePet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    @State private var actionFeedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EncounterArtworkButton(stage: stage, isLocked: false, onEnemyTap: onEnemyTap)

            VStack(alignment: .leading, spacing: 8) {
                StageStatusHeader(stage: stage, state: .active)

                Text(stage.flavorText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ActivePartyPickerRow(
                hero: activeHero,
                pet: activePet,
                onHeroPicker: onHeroPicker,
                onPetPicker: onPetPicker
            )

            Button {
                actionFeedbackTrigger += 1
                onPrimaryAction()
            } label: {
                Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .tint(stage.encounter.mapTint)
            .accessibilityIdentifier(StageMapID.stageNode(for: stage))
            .accessibilityLabel("\(stage.mapLabel), active \(stage.encounter.title)")
            .sensoryFeedback(.selection, trigger: actionFeedbackTrigger)
        }
        .trinketSurface(.selected)
    }
}

private struct EncounterArtworkButton: View {
    let stage: Stage
    let isLocked: Bool
    let onEnemyTap: () -> Void

    var body: some View {
        Group {
            if stage.encounter.battleEnemyID != nil {
                Button(action: onEnemyTap) {
                    artwork
                }
                // UIStyleCheck: allow - Artwork opens enemy details without button chrome.
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(stage.mapLabel) Enemy Art")
                .accessibilityLabel("\(stage.mapLabel), \(stage.encounterSubjectName) details")
            } else {
                artwork
            }
        }
    }

    private var artwork: some View {
        EncounterArtwork(stage: stage)
            .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
            .clipShape(TrinketDesign.cardShape)
            .trinketLockedCardEffect(isLocked: isLocked, text: isLocked ? "Locked" : nil)
    }
}

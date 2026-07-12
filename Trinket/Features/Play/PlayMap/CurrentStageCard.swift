import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Active detail embedded in the Campaign stage row.
struct CurrentStageCard: View {
    @Environment(AppState.self) private var appState

    let stage: Stage
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    @State private var actionFeedbackTrigger = 0
    @State private var isPartyPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            identity

            HStack(spacing: 8) {
                Button {
                    actionFeedbackTrigger += 1
                    onPrimaryAction()
                } label: {
                    Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(controlSize: .regular)
                .tint(stage.encounter.mapTint)
                .accessibilityIdentifier(StageMapID.stageAction(for: stage))
                .accessibilityLabel("\(stage.mapLabel), \(stage.encounter.primaryActionTitle)")
                .trinketSensoryFeedback(
                    .selection,
                    trigger: actionFeedbackTrigger,
                    enabled: appState.options.hapticsEnabled
                )

                if stage.encounter.battleEnemyID != nil {
                    Button {
                        isPartyPickerPresented = true
                    } label: {
                        Image(systemName: "person.2.fill")
                            .font(.body.weight(.semibold))
                            // UIStyleCheck: allow - Keeps the one-off party icon's tap target compact and legible.
                            .frame(minWidth: 24, minHeight: 24)
                            .trinketGlassChip(.utility)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Play.stagePartyControl)
                    .accessibilityLabel("Choose party")
                    .accessibilityValue(
                        "Hero: \(appState.roster.activeHero.name), Pet: \(appState.roster.activePet.name)"
                    )
                    .accessibilityHint("Choose a different hero or pet")
                }
            }
        }
        .padding(14)
        .trinketSurface(.card)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .strokeBorder(stage.encounter.mapTint.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.activeStageDetail)
        .sheet(isPresented: $isPartyPickerPresented) {
            StageBattlePartyPickerSheet(accentColor: stage.encounter.mapTint)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var identity: some View {
        HStack(alignment: .top, spacing: 12) {
            activeArtwork
                .frame(width: 96, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.compact, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(stage.encounterSubjectName)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.mapLabel)
                    HStack(spacing: 5) {
                        Text(stage.encounterTypeTitle)
                            .foregroundStyle(stage.encounter.mapTint)
                        Image(systemName: stage.encounter.symbolName)
                            .foregroundStyle(stage.encounter.mapTint)
                            .accessibilityHidden(true)
                    }
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var activeArtwork: some View {
        if stage.encounter.battleEnemyID != nil {
            Button(action: onEnemyTap) {
                EncounterArtwork(stage: stage)
            }
            // UIStyleCheck: allow - Encounter artwork is the enemy-detail affordance.
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(stage.mapLabel) Enemy Art")
            .accessibilityLabel("\(stage.mapLabel), \(stage.encounterSubjectName) details")
        } else {
            EncounterArtwork(stage: stage)
                .accessibilityIdentifier(
                    stage.recruitCombatant == nil
                        ? "\(stage.mapLabel) Encounter Art"
                        : "\(stage.mapLabel) Recruit Art"
                )
        }
    }
}

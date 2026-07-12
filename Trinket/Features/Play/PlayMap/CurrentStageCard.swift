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

    private let artWidth: CGFloat = 112
    private let artHeight: CGFloat = 84

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
                    partyPickerButton
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
                .frame(width: artWidth, height: artHeight)
                .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.compact, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(stage.encounterSubjectName)
                    .trinketTypography(.sectionDisplay)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                StageMapMetaLine(stage: stage, role: .navigation)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var partyPickerButton: some View {
        Button {
            isPartyPickerPresented = true
        } label: {
            Image(systemName: "person.2.fill")
                .font(.body.weight(.semibold))
                // UIStyleCheck: allow - Compact party icon sits beside the primary CTA without chip chrome.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Play.stagePartyControl)
        .accessibilityLabel("Choose party")
        .accessibilityValue(
            "Hero: \(appState.roster.activeHero.name), Pet: \(appState.roster.activePet.name)"
        )
        .accessibilityHint("Choose a different hero or pet")
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

/// Shared stage index + type meta (type tinted, no SF Symbol).
struct StageMapMetaLine: View {
    let stage: Stage
    var role: TypographyRole = .caption

    var body: some View {
        HStack(spacing: 4) {
            Text(stage.mapLabel)
            Text("·")
                .accessibilityHidden(true)
            Text(stage.encounterTypeTitle)
                .foregroundStyle(stage.encounter.mapTint)
        }
        .trinketTypography(role)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage.mapMetaLabel)
    }
}

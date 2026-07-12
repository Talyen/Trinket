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

    private var hasBattleEnemy: Bool {
        stage.encounter.battleEnemyID != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            stageArtFrame

            footerDock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(TrinketDesign.cardShape)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.activeStageDetail)
        .sheet(isPresented: $isPartyPickerPresented) {
            StageBattlePartyPickerSheet(accentColor: stage.encounter.mapTint)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    /// Full-bleed 4:3 encounter art with no chrome overlays.
    private var stageArtFrame: some View {
        Color.clear
            .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    stageArt
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
    }

    private var footerDock: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Metrics.smallSpacing) {
            titleBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            actionControls
                .layoutPriority(1)
        }
        .padding(.horizontal, TrinketDesign.Metrics.smallSpacing)
        .padding(.vertical, TrinketDesign.Metrics.smallSpacing)
        .padding(TrinketDesign.Metrics.mediumSpacing)
        .background(TrinketDesign.Colors.surface)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stage.mapLabel.uppercased())
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(stage.mapLabel)

            Text(stage.encounterSubjectName)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var actionControls: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Metrics.smallSpacing) {
            if hasBattleEnemy {
                partyPickerButton
            }
            primaryActionButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var primaryActionButton: some View {
        Button {
            actionFeedbackTrigger += 1
            onPrimaryAction()
        } label: {
            Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .trinketPrimaryActionButton(
            controlSize: .regular,
            tint: stage.encounter.mapTint,
            labelColor: TrinketDesign.Colors.Overlay.paper
        )
        .accessibilityIdentifier(StageMapID.stageAction(for: stage))
        .accessibilityLabel("\(stage.mapLabel), \(stage.encounter.primaryActionTitle)")
        .trinketSensoryFeedback(
            .selection,
            trigger: actionFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private var partyPickerButton: some View {
        Button {
            isPartyPickerPresented = true
        } label: {
            Image(systemName: "person.2.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                // UIStyleCheck: allow - Compact party icon beside the primary CTA without chip chrome.
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
    private var stageArt: some View {
        if hasBattleEnemy {
            Button(action: onEnemyTap) {
                EncounterArtwork(stage: stage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // UIStyleCheck: allow - Encounter artwork is the enemy-detail affordance.
            .buttonStyle(.plain)
            .accessibilityIdentifier(stageArtAccessibilityIdentifier)
            .accessibilityLabel("\(stage.mapLabel), \(stage.encounterSubjectName) details")
        } else {
            EncounterArtwork(stage: stage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(stageArtAccessibilityIdentifier)
                .accessibilityHidden(true)
        }
    }

    private var stageArtAccessibilityIdentifier: String {
        if hasBattleEnemy {
            return "\(stage.mapLabel) Enemy Art"
        }
        if stage.recruitCombatant != nil {
            return "\(stage.mapLabel) Recruit Art"
        }
        return "\(stage.mapLabel) Encounter Art"
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

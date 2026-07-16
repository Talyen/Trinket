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
                        .trinketArtworkBlend(.perimeter(into: .canvas))
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.activeStageDetail)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stage.mapLabel.uppercased())
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)

            Text(stage.encounterSubjectName)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
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
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Play.stagePartyControl)
    }

    @ViewBuilder
    private var stageArt: some View {
        if hasBattleEnemy {
            Button(action: onEnemyTap) {
                EncounterArtwork(stage: stage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // UIStyleCheck: allow - Encounter artwork is the enemy-detail affordance.
            .trinketQuietTapButtonStyle()
            .accessibilityIdentifier(stageArtAccessibilityIdentifier)

        } else {
            EncounterArtwork(stage: stage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(stageArtAccessibilityIdentifier)
        }
    }

    private var stageArtAccessibilityIdentifier: String {
        if hasBattleEnemy {
            return "\(stage.mapLabel) Enemy Art"
        }
        if case .mysteryEvent = stage.encounter {
            return "\(stage.mapLabel) Mystery Art"
        }
        return "\(stage.mapLabel) Encounter Art"
    }
}

/// Shared stage index + type meta, with an optional encounter icon for compact rows.
struct StageMapMetaLine: View {
    let stage: Stage
    var role: TypographyRole = .caption
    var showsEncounterIcon = false

    var body: some View {
        HStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            Text(stage.mapLabel)
            Text("·")

            Text(stage.encounterTypeTitle)
                .foregroundStyle(stage.encounter.mapTint)
            if showsEncounterIcon {
                Image(systemName: stage.encounter.symbolName)
                    .foregroundStyle(stage.encounter.mapTint)
            }
        }
        .trinketTypography(role)
        .foregroundStyle(.secondary)
    }
}

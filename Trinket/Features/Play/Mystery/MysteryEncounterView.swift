import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport

struct MysteryEncounterView: View {
    @Environment(OptionsStore.self) private var options
    @Environment(EncounterPlayMode.self) private var encounters
    @Bindable var session: MysteryEncounterSession

    @State private var selectedDetail: CombatantDetailContext?
    @State private var selectedChoiceID: String?
    @State private var choiceFeedbackTrigger = 0

    var body: some View {
        ZStack {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                MysteryUnlockContent(
                    session: session,
                    unlockedID: unlockedID,
                    onSelectDetail: { selectedDetail = $0 },
                    onFinish: { encounters.finishActiveMysteryEncounter(dismiss: false) },
                    onDismiss: { encounters.dismissActiveMysteryEncounter() },
                )
                .transition(.opacity)
            } else if session.showsReward, let result = session.applyResult {
                MysteryRewardContent(
                    session: session,
                    result: result,
                    onFinish: { encounters.finishActiveMysteryEncounter() },
                )
                .transition(.opacity)
            } else if session.showsCorruptionReveal, let result = session.corruptionResult {
                MysteryCorruptionRevealContent(
                    session: session,
                    result: result,
                    onFinish: { encounters.finishActiveMysteryCorruptionReveal() },
                )
                .transition(.opacity)
            } else if session.showsCorruptItemChoice {
                MysteryCorruptItemChoiceContent(
                    session: session,
                    onCorruptItem: { encounters.corruptActiveMysteryItem(itemID: $0) },
                    onCancelCorruptSelection: { encounters.cancelActiveMysteryCorruptSelection() },
                )
                .transition(.opacity)
            } else {
                readingContent
                    .transition(.opacity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: screenPhase)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .sheet(item: $selectedDetail) { context in
            NavigationStack {
                RosterCombatantDetailView(
                    kind: context.kind,
                    combatantID: context.combatantID,
                    hapticsEnabled: options.hapticsEnabled,
                    effectsVolume: options.effectsVolume,
                    hidesNavigationBar: false,
                )
            }
            .trinketDetailSheet()
        }
    }

    private var screenPhase: MysteryScreenPhase {
        if session.showsReveal {
            return .reveal
        }
        if session.showsReward {
            return .reward
        }
        if session.showsCorruptionReveal {
            return .corruptionReveal
        }
        if session.showsCorruptItemChoice {
            return .corruptItemChoice
        }
        return .reading
    }

    private enum MysteryScreenPhase: Equatable {
        case reading
        case reveal
        case reward
        case corruptionReveal
        case corruptItemChoice
    }

    private var readingContent: some View {
        DetailHeroScrollShell(
            title: session.event.title,
            heroHeightPolicy: .cinematicLandscape,
            hidesNavigationBar: true,
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                eyebrow: "MYSTERY",
                title: session.event.title,
                titleAccessibilityIdentifier: AccessibilityID.Mystery.encounterTitle,
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.largeSpacing,
            ) {
                heroArtwork
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                narrativeCard
                mysteryPersistFailureBanner(session.persistFailureMessage)
                mysteryChoices
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
        }
        .safeAreaInset(edge: .bottom) {
            mysteryConfirmAction
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        }
    }

    private var narrativeCard: some View {
        Text(session.event.narrative)
            .trinketTypography(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(AccessibilityID.Mystery.encounterNarrative)
            .padding(TrinketDesign.Metrics.largeSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .trinketCardSurface()
    }

    private var mysteryChoices: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
            if session.event.choices.count > 1 {
                Text("PICK A REWARD")
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            ForEach(session.event.choices, id: \.id) { choice in
                MysteryChoiceCard(
                    choice: choice,
                    isSelected: selectedChoiceID == choice.id,
                    isDisabled: session.isResolvingChoice,
                    materialQuantity: session.previewMaterialQuantity,
                    heroExperienceAward: session.previewHeroExperienceAward,
                    companionExperienceAward: session.previewCompanionExperienceAward,
                ) {
                    guard selectedChoiceID != choice.id else { return }
                    selectedChoiceID = choice.id
                    choiceFeedbackTrigger += 1
                }
            }
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: choiceFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private var mysteryConfirmAction: some View {
        Button {
            guard let selectedChoiceID else { return }
            _ = encounters.resolveActiveMysteryChoice(choiceID: selectedChoiceID)
        } label: {
            Text("Confirm")
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton(
            accessibilityIdentifier: AccessibilityID.Mystery.confirmChoiceButton,
        )
        .trinketCenteredPrimaryAction()
        .disabled(selectedChoiceID == nil || session.isResolvingChoice)
        .padding(.top, TrinketDesign.Metrics.smallSpacing)
    }

    private var heroArtwork: some View {
        MysteryEventHeroArtwork(event: session.event, chapterID: session.stage.chapterID)
    }
}

@MainActor
@ViewBuilder
func mysteryPersistFailureBanner(
    _ message: String?,
    centered: Bool = false,
) -> some View {
    if let message {
        Text(message)
            .trinketTypography(.badge)
            .foregroundStyle(TrinketDesign.Colors.warning)
            .multilineTextAlignment(centered ? .center : .leading)
            .accessibilityIdentifier(AccessibilityID.Mystery.persistFailure)
            .transition(.opacity)
    }
}

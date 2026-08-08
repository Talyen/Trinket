import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct MysteryEncounterView: View {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @Bindable var session: MysteryEncounterSession
    let onResolveChoice: (String?) -> Bool
    let onCorruptItem: (String) -> Bool
    let onCancelCorruptSelection: () -> Void
    let onFinish: () -> Bool
    let onFinishCorruptionReveal: () -> Bool

    @State private var selectedDetail: CombatantDetailContext?
    @State private var artAppeared = false
    @State private var narrativeAppeared = false
    @State private var selectedChoiceID: String?
    @State private var choiceFeedbackTrigger = 0

    var body: some View {
        Group {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                MysteryUnlockContent(
                    session: session,
                    unlockedID: unlockedID,
                    onSelectDetail: { selectedDetail = $0 },
                    onFinish: onFinish
                )
            } else if session.showsReward, let result = session.applyResult {
                MysteryRewardContent(session: session, result: result, onFinish: onFinish)
            } else if session.showsCorruptionReveal, let result = session.corruptionResult {
                MysteryCorruptionRevealContent(
                    session: session,
                    result: result,
                    onFinish: onFinishCorruptionReveal
                )
            } else if session.showsCorruptItemChoice {
                MysteryCorruptItemChoiceContent(
                    session: session,
                    onCorruptItem: onCorruptItem,
                    onCancelCorruptSelection: onCancelCorruptSelection
                )
            } else {
                readingContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketScreenBackground()
        .sheet(item: $selectedDetail) { context in
            NavigationStack {
                RosterCombatantDetailView(
                    kind: context.kind,
                    combatantID: context.combatantID,
                    hapticsEnabled: options.hapticsEnabled,
                    effectsVolume: options.effectsVolume,
                    hidesNavigationBar: false
                )
            }
            .trinketDetailSheet()
        }
        .onAppear {
            EncounterReadingEntrance.present(
                artAppeared: $artAppeared,
                copyAppeared: $narrativeAppeared
            )
        }
    }

    private var readingContent: some View {
        DetailHeroScrollShell(
            title: session.event.title,
            heroHeightPolicy: .cinematicLandscape,
            hidesNavigationBar: true
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                eyebrow: "MYSTERY",
                title: session.event.title,
                titleAccessibilityIdentifier: AccessibilityID.Mystery.encounterTitle,
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.largeSpacing
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
            .padding(.top, TrinketDesign.Metrics.largeSpacing)
            .padding(.bottom, TrinketDesign.Metrics.compactTabBarContentClearance)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            mysteryConfirmAction
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
                    materialQuantity: materialQuantity
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
            enabled: options.hapticsEnabled
        )
    }

    private var mysteryConfirmAction: some View {
        Button {
            guard let selectedChoiceID else { return }
            _ = onResolveChoice(selectedChoiceID)
        } label: {
            Text("Confirm")
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton(
            accessibilityIdentifier: AccessibilityID.Mystery.confirmChoiceButton
        )
        .disabled(selectedChoiceID == nil || session.isResolvingChoice)
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        .frame(maxWidth: .infinity)
        .trinketMaterial(.bottomBar, cornerRadius: 0)
        .background(alignment: .top) {
            LinearGradient(
                colors: [
                    TrinketDesign.Colors.canvas.opacity(0),
                    TrinketDesign.Colors.canvas.opacity(0.88),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            .offset(y: -28)
            .allowsHitTesting(false)
        }
    }

    private var materialQuantity: Int {
        MysteryEffectApplier.materialQuantity(
            forLevel: MysteryEffectApplier.resolvedEncounterLevel(
                stage: session.stage,
                labyrinthNodeID: session.labyrinthNodeID,
                save: playerSave.currentSave
            )
        )
    }

    private var heroArtwork: some View {
        MysteryEventHeroArtwork(event: session.event, chapterID: session.stage.chapterID)
    }
}

@MainActor
@ViewBuilder
func mysteryPersistFailureBanner(
    _ message: String?,
    centered: Bool = false
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

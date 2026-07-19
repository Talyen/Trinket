import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct MysteryEncounterView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: MysteryEncounterSession

    @State private var selectedDetail: CombatantDetailContext?
    @State private var artAppeared = false
    @State private var narrativeAppeared = false
    @State private var welcomeFeedbackTrigger = 0
    @State private var unlockFeedbackTrigger = 0
    @State private var unlockRevealPhase: UnlockRevealPhase = .hidden
    @State private var hasStartedUnlockReveal = false
    @State private var unlockRevealTask: Task<Void, Never>?

    var body: some View {
        Group {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                unlockRevealContent(unlockedID: unlockedID)
            } else if session.showsItemChoice {
                MysteryItemChoiceContent(
                    session: session,
                    onSelectItem: { itemID in
                        _ = appState.selectActiveMysteryItem(itemID: itemID)
                    }
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
                    hidesNavigationBar: false
                )
            }
            .trinketDetailSheet()
        }
        .onAppear {
            presentReadingEntrance()
        }
        .onDisappear {
            unlockRevealTask?.cancel()
            unlockRevealTask = nil
            // Cancel without completion left Recruit locked when @State survived
            // (same class as VictoryView / ExperienceBar onDisappear snap).
            if hasStartedUnlockReveal {
                finishUnlockReveal()
            }
        }
    }

    private var readingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                recruitArtwork
                    .opacity(artAppeared ? 1 : 0)
                    .scaleEffect(artAppeared ? 1 : 0.94)

                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Text(session.event.title)
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(AccessibilityID.Mystery.encounterTitle)

                    Text(session.event.narrative)
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AccessibilityID.Mystery.encounterNarrative)
                }
                .opacity(narrativeAppeared ? 1 : 0)
                .offset(y: narrativeAppeared ? 0 : 8)

                if let choice = session.event.choices.first {
                    mysteryPersistFailureBanner(session.persistFailureMessage)

                    Button {
                        welcomeFeedbackTrigger += 1
                        _ = appState.resolveActiveMysteryChoice(choiceID: choice.id)
                    } label: {
                        Text(choice.label)
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .tint(TrinketDesign.Colors.encounterEvent)
                    .disabled(session.isResolvingChoice)
                    .accessibilityIdentifier(AccessibilityID.Mystery.welcomeButton)
                    .trinketSensoryFeedback(
                        .selection,
                        trigger: welcomeFeedbackTrigger,
                        enabled: appState.options.hapticsEnabled
                    )
                    .padding(.top, TrinketDesign.Metrics.smallSpacing)
                }
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
    }

    @ViewBuilder
    private var recruitArtwork: some View {
        if session.combatant != nil {
            EncounterArtwork(stage: recruitArtworkStage)
                .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()

        } else {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Colors.encounterEvent.opacity(0.14))
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay {
                    Image(systemName: "sparkles")
                        .trinketTypography(.screenTitle)
                        .foregroundStyle(TrinketDesign.Colors.encounterEvent)
                }
                .frame(maxWidth: .infinity)
        }
    }

    private var recruitArtworkStage: Stage {
        Stage(
            id: session.stage.id,
            chapterID: session.stage.chapterID,
            chapterNumber: session.stage.chapterNumber,
            stageNumber: session.stage.stageNumber,
            flavorText: session.stage.flavorText,
            encounter: .mysteryEvent(eventID: session.event.id),
            rewards: session.stage.rewards
        )
    }

    @ViewBuilder
    private func unlockRevealContent(unlockedID: String) -> some View {
        if let combatant = revealCombatant(id: unlockedID) {
            recruitUnlockStage(combatant: combatant)
                .trinketSensoryFeedback(
                    .success,
                    trigger: unlockFeedbackTrigger,
                    enabled: appState.options.hapticsEnabled
                )
                .onAppear {
                    unlockFeedbackTrigger += 1
                    startUnlockReveal()
                }
        }
    }

    private func recruitUnlockStage(combatant: Combatant) -> some View {
        let artVisible = unlockRevealPhase >= .art

        return RewardRevealShell(
            eyebrow: combatant.role == .companion ? "New Companion" : "New Hero",
            eyebrowAccessibilityIdentifier: AccessibilityID.Mystery.unlockEyebrow,
            title: combatant.name,
            subtitle: "UNLOCKED",
            subtitleAccessibilityIdentifier: AccessibilityID.Mystery.unlockSubtitle,
            titleAccessibilityIdentifier: AccessibilityID.Mystery.unlockName,
            eyebrowOpacity: unlockRevealPhase.opacity(visibleFrom: .eyebrow),
            titleOpacity: unlockRevealPhase.opacity(visibleFrom: .title),
            subtitleOpacity: unlockRevealPhase.opacity(visibleFrom: .subtitle),
            content: {
                VStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Button {
                        selectedDetail = CombatantDetailContext(
                            kind: combatant.role == .companion ? .companion : .hero,
                            combatantID: combatant.id
                        )
                    } label: {
                        CombatantArtwork(combatant: combatant, variant: .hero)
                            .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
                            .clipShape(TrinketDesign.cardShape)
                            .trinketCardSurface()
                    }
                    // UIStyleCheck: allow - Unlock art is the tap target for combatant detail; no button chrome.
                    .trinketQuietTapButtonStyle()
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
                    .opacity(artVisible ? 1 : 0)
                    .scaleEffect(artVisible ? 1 : 0.94)
                    .frame(maxWidth: 430)
                    .allowsHitTesting(artVisible)

                    mysteryPersistFailureBanner(session.persistFailureMessage, centered: true)
                }
            },
            primaryActionTitle: unlockRevealPhase >= .complete ? "Recruit" : nil,
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            isPrimaryActionDisabled: false,
            onPrimaryAction: {
                _ = appState.finishActiveMysteryEncounter()
            },
            pinsPrimaryActionToBottom: false,
            primaryActionWidthFraction: 0.5
        )
    }

    private func startUnlockReveal() {
        guard !hasStartedUnlockReveal else { return }
        hasStartedUnlockReveal = true
        unlockRevealTask?.cancel()
        unlockRevealTask = Task { @MainActor in
            let clock = SuspendingClock()
            let stagger = TrinketMotion.Reward.resourceStagger
            let steps: [(UnlockRevealPhase, Animation)] = [
                (.eyebrow, TrinketMotion.Reward.reveal),
                (.title, TrinketMotion.Reward.reveal),
                (.subtitle, TrinketMotion.Reward.stateChange),
                (.art, TrinketMotion.Reward.reveal)
            ]

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.itemRevealDelay))
            guard !Task.isCancelled else { return }

            for (index, step) in steps.enumerated() {
                if index > 0 {
                    try? await clock.sleep(for: .seconds(stagger))
                    guard !Task.isCancelled else { return }
                }
                withAnimation(step.1) {
                    unlockRevealPhase = step.0
                }
            }

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.completionDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                finishUnlockReveal()
            }
            unlockRevealTask = nil
        }
    }

    private func finishUnlockReveal() {
        guard unlockRevealPhase != .complete else { return }
        unlockRevealPhase = .complete
    }

    private func revealCombatant(id: String) -> Combatant? {
        if let sessionCombatant = session.combatant, sessionCombatant.id == id {
            return appState.roster.configuredCombatant(sessionCombatant)
        }
        let catalog = GameContent.heroes + GameContent.companions
        guard let combatant = catalog.first(where: { $0.id == id }) else { return nil }
        return appState.roster.configuredCombatant(combatant)
    }

    private func presentReadingEntrance() {
        withAnimation(.easeOut(duration: 0.35)) {
            artAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.08)) {
            narrativeAppeared = true
        }
    }
}

/// Ordered chrome reveal for mystery unlock; drives `RewardRevealShell` opacities.
private enum UnlockRevealPhase: Int, Comparable {
    case hidden = 0
    case eyebrow = 1
    case title = 2
    case subtitle = 3
    case art = 4
    case complete = 5

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func opacity(visibleFrom phase: UnlockRevealPhase) -> Double {
        self >= phase ? 1 : 0
    }
}

@ViewBuilder
private func mysteryPersistFailureBanner(
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

private struct MysteryItemChoiceContent: View {
    @Bindable var session: MysteryEncounterSession
    let onSelectItem: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Text("Choose a Find")
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(AccessibilityID.Mystery.chooseItemTitle)

                    Text("Three relics answer the scrolls. Take one.")
                        .trinketTypography(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    mysteryPersistFailureBanner(session.persistFailureMessage)
                }

                LazyVGrid(
                    columns: TrinketDesign.Metrics.collectionGridItems,
                    spacing: TrinketDesign.Metrics.largeSpacing
                ) {
                    ForEach(session.itemCandidates) { item in
                        Button {
                            onSelectItem(item.id)
                        } label: {
                            VStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                                ItemCard(
                                    item: item,
                                    showsAffixCount: false,
                                    showsName: false,
                                    appliesCardSurface: false
                                )
                                Text(item.displayName)
                                    .trinketTypography(.badge)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        // UIStyleCheck: allow - Mystery item pick uses card art without button chrome.
                        .trinketQuietTapButtonStyle()
                        .disabled(session.isResolvingChoice)
                        .accessibilityIdentifier(AccessibilityID.Mystery.chooseItemCard(itemID: item.id))
                    }
                }
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
    }
}

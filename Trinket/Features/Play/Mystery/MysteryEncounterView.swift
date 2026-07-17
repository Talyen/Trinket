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
    @State private var inviteTapTrigger = 0
    @State private var shroudRevealStarted = false
    @State private var shroudRevealProgress: CGFloat = 0
    @State private var showUnlockEyebrow = false
    @State private var showUnlockTitle = false
    @State private var showUnlockSubtitle = false
    @State private var showUnlockCTA = false
    @State private var hasStartedChromeSequence = false
    @State private var chromeRevealTask: Task<Void, Never>?

    var body: some View {
        Group {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                unlockReveal(unlockedID: unlockedID)
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
            chromeRevealTask?.cancel()
            chromeRevealTask = nil
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
                    if let persistFailure = session.persistFailureMessage {
                        Text(persistFailure)
                            .trinketTypography(.badge)
                            .foregroundStyle(TrinketDesign.Colors.warning)
                            .accessibilityIdentifier(AccessibilityID.Mystery.persistFailure)
                            .transition(.opacity)
                    }

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
    private func unlockReveal(unlockedID: String) -> some View {
        if let combatant = revealCombatant(id: unlockedID) {
            recruitUnlockStage(combatant: combatant)
                .trinketSensoryFeedback(
                    .success,
                    trigger: unlockFeedbackTrigger,
                    enabled: appState.options.hapticsEnabled
                )
                .trinketSensoryFeedback(
                    .selection,
                    trigger: inviteTapTrigger,
                    enabled: appState.options.hapticsEnabled
                )
                .onChange(of: shroudRevealProgress) { _, progress in
                    guard progress >= TrinketMotion.RecruitReveal.clearEnd else { return }
                    startUnlockChromeSequence()
                }
        }
    }

    private func recruitUnlockStage(combatant: Combatant) -> some View {
        let clear = shroudRevealStarted
            ? recruitRevealClearAmount(progress: shroudRevealProgress)
            : 0

        return ZStack {
            // Art stays geometrically centered; chrome overlays so fade-in never nudges it.
            Button {
                if shroudRevealStarted {
                    guard clear >= 1 else { return }
                    selectedDetail = CombatantDetailContext(
                        kind: combatant.role == .companion ? .companion : .hero,
                        combatantID: combatant.id
                    )
                } else {
                    beginShroudReveal()
                }
            } label: {
                RecruitCeremonyArt(
                    stage: session.stage,
                    combatant: combatant,
                    clearAmount: clear,
                    isBreathingEnabled: !shroudRevealStarted
                )
            }
            // UIStyleCheck: allow - Invitation / unlock art is the tap target; no button chrome.
            .trinketQuietTapButtonStyle()
            .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
            .frame(maxWidth: 430)
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

            VStack(spacing: 0) {
                unlockChromeHeader(combatant: combatant)
                    .padding(.top, TrinketDesign.Metrics.contentTopPadding)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .allowsHitTesting(false)

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                unlockChromeFooter
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .padding(.bottom, TrinketDesign.Metrics.extraLargeSpacing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unlockChromeHeader(combatant: Combatant) -> some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            if showUnlockEyebrow {
                Text(combatant.role == .companion ? "New Companion" : "New Hero")
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .textCase(.uppercase)
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockEyebrow)
                    .transition(.opacity)
            }

            if showUnlockTitle {
                Text(combatant.name)
                    .trinketTypography(.screenDisplay)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockName)
                    .transition(.opacity)
            }

            if showUnlockSubtitle {
                Text("UNLOCKED")
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockSubtitle)
                    .transition(.opacity)
            }

            if let persistFailure = session.persistFailureMessage {
                Text(persistFailure)
                    .trinketTypography(.badge)
                    .foregroundStyle(TrinketDesign.Colors.warning)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(AccessibilityID.Mystery.persistFailure)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var unlockChromeFooter: some View {
        if showUnlockCTA {
            Button {
                _ = appState.finishActiveMysteryEncounter()
            } label: {
                Text("Recruit")
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .accessibilityIdentifier(AccessibilityID.Mystery.continueButton)
            .containerRelativeFrame(.horizontal) { width, _ in width * 0.5 }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }

    private func beginShroudReveal() {
        inviteTapTrigger += 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            shroudRevealStarted = true
            shroudRevealProgress = 0
        }
        withAnimation(TrinketMotion.RecruitReveal.peel) {
            shroudRevealProgress = 1
        }
        unlockFeedbackTrigger += 1
    }

    private func startUnlockChromeSequence() {
        guard !hasStartedChromeSequence else { return }
        hasStartedChromeSequence = true
        chromeRevealTask?.cancel()
        chromeRevealTask = Task { @MainActor in
            let clock = SuspendingClock()
            let stagger = TrinketMotion.Reward.resourceStagger

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.itemRevealDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.reveal) {
                showUnlockEyebrow = true
            }

            try? await clock.sleep(for: .seconds(stagger))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.reveal) {
                showUnlockTitle = true
            }

            try? await clock.sleep(for: .seconds(stagger))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                showUnlockSubtitle = true
            }

            try? await clock.sleep(for: .seconds(TrinketMotion.Reward.completionDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                showUnlockCTA = true
            }
            chromeRevealTask = nil
        }
    }

    private func recruitRevealClearAmount(progress: CGFloat) -> CGFloat {
        let motion = TrinketMotion.RecruitReveal.self
        let span = motion.clearEnd - motion.clearStart
        guard span > 0 else { return 1 }
        let t = min(1, max(0, (progress - motion.clearStart) / span))
        return t * t * (3 - 2 * t)
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

                    if let persistFailure = session.persistFailureMessage {
                        Text(persistFailure)
                            .trinketTypography(.badge)
                            .foregroundStyle(TrinketDesign.Colors.warning)
                            .accessibilityIdentifier(AccessibilityID.Mystery.persistFailure)
                            .transition(.opacity)
                    }
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

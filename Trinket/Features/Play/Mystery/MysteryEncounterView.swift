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

    var body: some View {
        Group {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                unlockReveal(unlockedID: unlockedID)
            } else if session.showsItemChoice {
                itemChoiceContent
            } else {
                readingContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
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

    private var itemChoiceContent: some View {
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
                            _ = appState.selectActiveMysteryItem(itemID: item.id)
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
        let combatant = revealCombatant(id: unlockedID)
        RewardRevealShell(
            eyebrow: combatant.map { $0.role == .companion ? "New Companion" : "New Hero" } ?? "Unlocked",
            eyebrowAccessibilityIdentifier: AccessibilityID.Mystery.unlockEyebrow,
            title: combatant?.name ?? "New Ally",
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Mystery.unlockName,
            content: {
                VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                    if let combatant {
                        recruitRevealContent(combatant)
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
            },
            primaryActionTitle: "Recruit",
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            isPrimaryActionDisabled: false,
            onPrimaryAction: { _ = appState.finishActiveMysteryEncounter() },
            pinsPrimaryActionToBottom: true
        )
        .onAppear {
            unlockFeedbackTrigger += 1
        }
        .trinketSensoryFeedback(
            .success,
            trigger: unlockFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private func recruitRevealContent(_ combatant: Combatant) -> some View {
        VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
            Button {
                selectedDetail = CombatantDetailContext(
                    kind: combatant.role == .companion ? .companion : .hero,
                    combatantID: combatant.id
                )
            } label: {
                ZStack(alignment: .bottom) {
                    CombatantArtwork(combatant: combatant, variant: .hero)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                }
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()
                .frame(maxWidth: 430)
            }
            // UIStyleCheck: allow - Unlock art opens detail without button chrome.
            .trinketQuietTapButtonStyle()
            .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
        }
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

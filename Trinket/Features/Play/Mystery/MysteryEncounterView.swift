import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct MysteryEncounterView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: MysteryEncounterSession

    @State private var selectedDetail: CombatantDetailContext?
    @State private var artAppeared = false
    @State private var narrativeAppeared = false
    @State private var revealCardScale: CGFloat = 0.86
    @State private var revealCardOpacity: Double = 0
    @State private var welcomeFeedbackTrigger = 0
    @State private var unlockFeedbackTrigger = 0

    var body: some View {
        Group {
            if session.showsReveal, let unlockedID = session.unlockedCombatantID {
                unlockReveal(unlockedID: unlockedID)
            } else {
                readingContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .sheet(item: $selectedDetail) { context in
            NavigationStack {
                appState.rosterCombatantDetail(
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
        .onChange(of: session.phase) { _, newPhase in
            if newPhase == .revealing {
                presentRevealEntrance()
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
        if let combatant = session.combatant {
            CombatantArtwork(combatant: combatant, variant: .hero)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()
                .frame(maxWidth: .infinity)

        } else {
            TrinketDesign.cardShape
                .fill(TrinketDesign.Colors.encounterEvent.opacity(0.14))
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(TrinketDesign.Colors.encounterEvent)
                }
                .frame(maxWidth: .infinity)
        }
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
                if let combatant {
                    recruitRevealContent(combatant)
                }
            },
            primaryActionTitle: "Recruit",
            primaryActionAccessibilityIdentifier: AccessibilityID.Mystery.continueButton,
            isPrimaryActionDisabled: false,
            onPrimaryAction: appState.finishActiveMysteryEncounter,
            pinsPrimaryActionToBottom: false
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
                .scaleEffect(revealCardScale)
                .opacity(revealCardOpacity)
            }
            // UIStyleCheck: allow - Unlock art opens detail without button chrome.
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
        }
    }

    private func revealCombatant(id: String) -> Combatant? {
        if let sessionCombatant = session.combatant, sessionCombatant.id == id {
            return appState.roster.current.configuredCombatant(sessionCombatant)
        }
        let catalog = GameContent.heroes + GameContent.companions
        guard let combatant = catalog.first(where: { $0.id == id }) else { return nil }
        return appState.roster.current.configuredCombatant(combatant)
    }

    private func presentReadingEntrance() {
        withAnimation(.easeOut(duration: 0.35)) {
            artAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.08)) {
            narrativeAppeared = true
        }
    }

    private func presentRevealEntrance() {
        revealCardScale = 0.86
        revealCardOpacity = 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            revealCardScale = 1
            revealCardOpacity = 1
        }
    }
}

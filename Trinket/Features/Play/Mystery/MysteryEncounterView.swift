import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

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

    private var reduceMotion: Bool {
        accessibilityReduceMotion
    }

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

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
            appState.rosterCombatantDetail(
                kind: context.kind,
                combatantID: context.combatantID,
                hidesNavigationBar: false
            )
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
            VStack(alignment: .leading, spacing: 20) {
                recruitArtwork
                    .opacity(artAppeared ? 1 : 0)
                    .scaleEffect(artAppeared ? 1 : (reduceMotion ? 1 : 0.94))

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.event.title)
                        .font(.title.bold())
                        .accessibilityIdentifier(AccessibilityID.Mystery.encounterTitle)

                    Text(session.event.narrative)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AccessibilityID.Mystery.encounterNarrative)
                }
                .opacity(narrativeAppeared ? 1 : 0)
                .offset(y: narrativeAppeared || reduceMotion ? 0 : 8)

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
                    .padding(.top, 8)
                }
            }
            .padding(24)
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
                .accessibilityLabel(combatant.name)
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
        ScrollView {
            VStack(spacing: 22) {
                Text(combatant.map { $0.role == .pet ? "New Pet" : "New Hero" } ?? "Unlocked")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockEyebrow)

                if let combatant {
                    Button {
                        selectedDetail = CombatantDetailContext(
                            kind: combatant.role == .pet ? .pet : .hero,
                            combatantID: combatant.id
                        )
                    } label: {
                        VStack(spacing: 12) {
                            CombatantCard(combatant: combatant, showsName: false)
                                .frame(maxWidth: 220)
                                .scaleEffect(revealCardScale)
                                .opacity(revealCardOpacity)

                            Text(combatant.name)
                                .font(.largeTitle.bold())
                                .accessibilityIdentifier(AccessibilityID.Mystery.unlockName)

                            Text("\(combatant.growthArchetype.displayName) · Tap to inspect")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier(AccessibilityID.Mystery.unlockSubtitle)
                        }
                    }
                    // UIStyleCheck: allow - Unlock card opens detail without button chrome.
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Mystery.unlockCard(name: combatant.name))
                    .accessibilityHint("Shows combatant details")
                }

                Button {
                    appState.finishActiveMysteryEncounter()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .accessibilityIdentifier(AccessibilityID.Mystery.continueButton)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .trinketSurface(.reward)
        }
        .onAppear {
            unlockFeedbackTrigger += 1
        }
        .trinketSensoryFeedback(
            .success,
            trigger: unlockFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private func revealCombatant(id: String) -> Combatant? {
        if let sessionCombatant = session.combatant, sessionCombatant.id == id {
            return appState.roster.current.configuredCombatant(sessionCombatant)
        }
        let catalog = GameContent.heroes + GameContent.pets
        guard let combatant = catalog.first(where: { $0.id == id }) else { return nil }
        return appState.roster.current.configuredCombatant(combatant)
    }

    private func presentReadingEntrance() {
        guard !reduceMotion else {
            artAppeared = true
            narrativeAppeared = true
            return
        }
        withAnimation(.easeOut(duration: 0.35)) {
            artAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.08)) {
            narrativeAppeared = true
        }
    }

    private func presentRevealEntrance() {
        guard !reduceMotion else {
            revealCardScale = 1
            revealCardOpacity = 1
            return
        }
        revealCardScale = 0.86
        revealCardOpacity = 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            revealCardScale = 1
            revealCardOpacity = 1
        }
    }
}

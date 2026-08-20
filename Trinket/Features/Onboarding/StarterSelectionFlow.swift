import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct StarterSelectionFlow: View {
    private enum Destination: Hashable {
        case companion
    }

    @State private var path: [Destination]
    @State private var selectedHeroID: String?
    @State private var selectedCompanionID: String?

    let confirmHero: (String) -> Bool
    let confirmCompanion: (String) -> Bool

    init(
        initialSelection: StarterSelectionState,
        confirmHero: @escaping (String) -> Bool,
        confirmCompanion: @escaping (String) -> Bool
    ) {
        _path = State(initialValue: initialSelection.phase == .chooseCompanion ? [.companion] : [])
        _selectedHeroID = State(initialValue: initialSelection.heroID)
        self.confirmHero = confirmHero
        self.confirmCompanion = confirmCompanion
    }

    var body: some View {
        NavigationStack(path: $path) {
            StarterChoiceScreen(
                title: "Choose a Hero",
                roleName: "Hero",
                combatants: GameContent.starterHeroes,
                selectedID: $selectedHeroID,
                screenAccessibilityID: AccessibilityID.Onboarding.heroScreen,
                onConfirm: confirmSelectedHero
            )
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .companion:
                    StarterChoiceScreen(
                        title: "Choose a Companion",
                        roleName: "Companion",
                        combatants: GameContent.starterCompanions,
                        selectedID: $selectedCompanionID,
                        screenAccessibilityID: AccessibilityID.Onboarding.companionScreen,
                        onConfirm: confirmSelectedCompanion
                    )
                }
            }
        }
    }

    private func confirmSelectedHero() -> Bool {
        guard let selectedHeroID, confirmHero(selectedHeroID) else { return false }
        path.append(.companion)
        return true
    }

    private func confirmSelectedCompanion() -> Bool {
        guard let selectedCompanionID else { return false }
        return confirmCompanion(selectedCompanionID)
    }
}

private struct StarterChoiceScreen: View {
    @Environment(OptionsStore.self) private var options
    @Binding var selectedID: String?
    @State private var inspectedCombatant: Combatant?
    @State private var selectionFeedbackTrigger = 0
    @State private var showsSaveFailure = false
    @State private var isConfirming = false

    let title: String
    let roleName: String
    let combatants: [Combatant]
    let screenAccessibilityID: String
    let onConfirm: () -> Bool

    init(
        title: String,
        roleName: String,
        combatants: [Combatant],
        selectedID: Binding<String?>,
        screenAccessibilityID: String,
        onConfirm: @escaping () -> Bool
    ) {
        self.title = title
        self.roleName = roleName
        self.combatants = combatants
        _selectedID = selectedID
        self.screenAccessibilityID = screenAccessibilityID
        self.onConfirm = onConfirm
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                Text("Tap to select. Touch and hold to view details.")
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                pyramid

                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    Button("Confirm", action: confirm)
                        .disabled(selectedID == nil || isConfirming)
                        .trinketPrimaryActionButton(
                            accessibilityIdentifier: AccessibilityID.Onboarding.confirm(role: roleName)
                        )
                        .trinketCenteredPrimaryAction()
                        .accessibilityLabel(confirmAccessibilityLabel)

                    Text("(Don't worry, you'll unlock everyone as you play!)")
                        .trinketTypography(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, TrinketDesign.Metrics.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.sectionSpacing)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(screenAccessibilityID)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
        .onAppear {
            isConfirming = false
        }
        .alert("Couldn't Save Progress", isPresented: $showsSaveFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your choice was not saved. Please try again.")
        }
        .sheet(item: $inspectedCombatant) { combatant in
            NavigationStack {
                CombatantDetailPane(snapshot: CombatantCardDetail(combatant: combatant))
                    .accessibilityIdentifier(
                        AccessibilityID.Onboarding.detail(combatantID: combatant.id)
                    )
            }
            .trinketDetailSheet()
        }
    }

    @ViewBuilder
    private var pyramid: some View {
        if let first = combatants.first {
            VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                choiceButton(first)
                    .starterChoiceCardWidth()

                HStack(alignment: .top, spacing: TrinketDesign.Metrics.largeSpacing) {
                    ForEach(combatants.dropFirst()) { combatant in
                        choiceButton(combatant)
                            .starterChoiceCardWidth()
                    }
                }
            }
        }
    }

    private func choiceButton(_ combatant: Combatant) -> some View {
        InspectableTapButton(
            action: { select(combatant) },
            longPress: { inspectedCombatant = combatant },
            label: {
                CombatantCard(
                    combatant: combatant,
                    isSelected: selectedID == combatant.id
                )
                .overlay(alignment: .topTrailing) {
                    if selectedID == combatant.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(TrinketDesign.Colors.accent)
                            .padding(TrinketDesign.Metrics.smallSpacing)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        )
        .trinketSelectionCardButtonStyle()
        .accessibilityIdentifier(
            AccessibilityID.Onboarding.option(
                role: roleName,
                combatantID: combatant.id
            )
        )
        .accessibilityValue(selectedID == combatant.id ? "Selected" : "Not selected")
    }

    private var confirmAccessibilityLabel: String {
        guard let selectedID,
              let combatant = combatants.first(where: { $0.id == selectedID })
        else { return "Confirm \(roleName)" }
        return "Confirm \(combatant.name)"
    }

    private func select(_ combatant: Combatant) {
        guard selectedID != combatant.id else { return }
        withAnimation(TrinketMotion.Interaction.selection) {
            selectedID = combatant.id
        }
        selectionFeedbackTrigger += 1
    }

    private func confirm() {
        guard selectedID != nil, !isConfirming else { return }
        isConfirming = true
        if !onConfirm() {
            isConfirming = false
            showsSaveFailure = true
        }
    }
}

private extension View {
    func starterChoiceCardWidth() -> some View {
        containerRelativeFrame(.horizontal) { width, _ in
            let margins = 2 * TrinketDesign.Metrics.contentMargin
            let spacing = TrinketDesign.Metrics.largeSpacing
            return max(
                1,
                min(
                    TrinketDesign.Metrics.collectionGridMaximum,
                    (width - margins - spacing) / 2
                )
            )
        }
    }
}

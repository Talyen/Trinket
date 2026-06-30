import SwiftUI

struct CombatantStatusCard: View {
    enum Prominence {
        case enemy
        case party
    }

    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let prominence: Prominence
    let cardWidth: CGFloat
    let showsText: Bool
    var isPaused: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                BattleArtCard(
                    combatant: combatant,
                    showsText: showsText,
                    isPaused: isPaused
                )
                .frame(width: cardWidth)

                CombatHealthBar(
                    health: health,
                    maxHealth: maxHealth,
                    fillColor: combatant.healthBarColor
                )
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(combatant.name) card")
            .accessibilityValue(healthText)
            .accessibilityHint("Shows details")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: prominence == .enemy ? .infinity : cardWidth)
        .accessibilityIdentifier("\(combatant.name) card")
    }

    private var healthText: String {
        "\(health)/\(maxHealth) HP"
    }
}

struct BattleArtCard: View {
    let combatant: Combatant
    let showsText: Bool
    var isPaused: Bool = false

    var body: some View {
        TrinketDesign.cardShape
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                ZStack(alignment: .bottom) {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .clipShape(TrinketDesign.cardShape)

                    if showsText {
                        Rectangle()
                            // UIStyleCheck: allow - battle art labels need readable material over artwork.
                            .fill(.ultraThinMaterial)
                            .frame(maxHeight: 60)

                        Text(combatant.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                            .padding(12)
                    }
                }
            }
            .trinketCardSurface()
    }
}

struct CombatFeedbackOverlay: View {
    let events: [BattleState.ActionEvent]
    let reduceMotion: Bool
    let onRemoveEvent: (Int) -> Void

    static let stackSpacing: CGFloat = 52

    var body: some View {
        ZStack {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                CombatFeedbackEventView(
                    event: event,
                    stackIndex: index,
                    reduceMotion: reduceMotion,
                    onRemove: { onRemoveEvent(event.id) }
                )
                .task(id: event.id) {
                    try? await Task.sleep(for: .seconds(1.0))
                    onRemoveEvent(event.id)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct CombatFeedbackEventView: View {
    let event: BattleState.ActionEvent
    let stackIndex: Int
    let reduceMotion: Bool
    let onRemove: () -> Void

    @State private var rmOpacity = 0.0

    var body: some View {
        if reduceMotion {
            feedbackLabel
                .opacity(rmOpacity)
                .offset(y: CGFloat(stackIndex) * CombatFeedbackOverlay.stackSpacing)
                .task(id: event.id) {
                    withAnimation(.easeOut(duration: 0.15)) { rmOpacity = 1.0 }
                    try? await Task.sleep(for: .seconds(0.7))
                    withAnimation(.easeOut(duration: 0.15)) { rmOpacity = 0.0 }
                }
        } else {
            KeyframeAnimator(
                initialValue: CombatFeedbackAnimationState(),
                trigger: event.id
            ) { state in
                feedbackLabel
                    .scaleEffect(state.scale)
                    .opacity(state.opacity)
                    .offset(y: state.verticalOffset + CGFloat(stackIndex) * CombatFeedbackOverlay.stackSpacing)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.1, duration: 0.16)
                    SpringKeyframe(1.0, duration: 0.24)
                    SpringKeyframe(0.98, duration: 0.55)
                }

                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1.0, duration: 0.18)
                    CubicKeyframe(1.0, duration: 0.52)
                    CubicKeyframe(0.0, duration: 0.25)
                }

                KeyframeTrack(\.verticalOffset) {
                    SpringKeyframe(-8, duration: 0.16)
                    SpringKeyframe(-34, duration: 0.58)
                    SpringKeyframe(-48, duration: 0.21)
                }
            }
        }
    }

    private var feedbackLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: event.keyword.visualStyle.symbolName)
                .font(.caption.bold())
                .symbolEffect(.bounce, value: event.id)

            Text(event.floatingText)
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(event.keyword.visualStyle.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // UIStyleCheck: allow - combat feedback is transient floating battle chrome.
        .glassEffect(.regular)
        .clipShape(Capsule())
    }
}

struct CombatFeedbackAnimationState {
    var opacity = 1.0
    var scale = 1.0
    var verticalOffset = 0.0
}

struct VictoryView: View {
    let enemyName: String
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void

    @State private var bounceCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .accessibilityHidden(true)
                    .symbolEffect(.bounce, value: bounceCount)
                    .onAppear {
                        bounceCount += 1
                    }

                VStack(spacing: 8) {
                    Text("Victory")
                        .font(.largeTitle.bold())

                    Text("\(enemyName) is defeated.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VictoryPlaceholderSection(
                    title: "Experience",
                    message: "Hero and Pet experience will appear here later."
                )

                VictoryPlaceholderSection(
                    title: "Rewards",
                    message: "Items, Gold, materials, and unlocks are not implemented yet."
                )

                Button {
                    onPrimaryAction()
                } label: {
                    Text(primaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                // UIStyleCheck: allow - victory uses the native prominent primary action.
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DefeatView: View {
    let enemyName: String
    let onBattleAgain: () -> Void

    @State private var shakeCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(TrinketDesign.Colors.destructive)
                    .accessibilityHidden(true)
                    .symbolEffect(.bounce, value: shakeCount)
                    .onAppear {
                        shakeCount += 1
                    }

                VStack(spacing: 8) {
                    Text("Defeat")
                        .font(.largeTitle.bold())

                    Text("\(enemyName) has defeated your party.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VictoryPlaceholderSection(
                    title: "Lost Progress",
                    message: "Experience and rewards are lost in defeat."
                )

                Button {
                    onBattleAgain()
                } label: {
                    Text("Battle Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(TrinketDesign.Colors.destructive)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VictoryPlaceholderSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .trinketCardSurface()
    }
}

struct BattleLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let entries: [BattleState.LogEntry]

    var body: some View {
        NavigationStack {
            List {
                Section("Battle Log") {
                    ForEach(entries) { entry in
                        Text(entry.text)
                    }
                }
            }
            .navigationTitle("Combat Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

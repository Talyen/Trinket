import SwiftUI

enum BattleCardGridLayout {
    static let artAspectRatio: CGFloat = 3.0 / 4.0
    static let outerPadding: CGFloat = 10
    static let cardSpacing: CGFloat = 10

    struct Metrics: Equatable {
        let enemySize: CGSize
        let partySize: CGSize
        let outerPadding: CGFloat
        let cardSpacing: CGFloat
    }

    static func metrics(in containerSize: CGSize) -> Metrics {
        let innerWidth = max(containerSize.width - 2 * outerPadding, 0)
        let innerHeight = max(containerSize.height - 2 * outerPadding, 0)
        guard innerWidth > 0, innerHeight > 0 else {
            return Metrics(enemySize: .zero, partySize: .zero, outerPadding: outerPadding, cardSpacing: cardSpacing)
        }

        let maxPartyWidth = max((innerWidth - cardSpacing) / 2, 0)
        let maxBalancedPartyWidth = max((innerHeight - cardSpacing) * artAspectRatio / 2, 0)
        let partyWidth = min(maxPartyWidth, maxBalancedPartyWidth)
        let partyHeight = partyWidth / artAspectRatio

        let enemyHeight = max(innerHeight - partyHeight - cardSpacing, 0)
        let enemyWidth = min(innerWidth, enemyHeight * artAspectRatio)

        return Metrics(
            enemySize: CGSize(width: enemyWidth, height: enemyWidth / artAspectRatio),
            partySize: CGSize(width: partyWidth, height: partyHeight),
            outerPadding: outerPadding,
            cardSpacing: cardSpacing
        )
    }
}

struct BattleArtViewport: View {
    let combatant: Combatant

    var body: some View {
        ZStack {
            if let artReference = combatant.artReference {
                Image(artReference.imageName)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .accessibilityLabel(artReference.accessibilityLabel)
            } else {
                placeholderArt
                    .accessibilityLabel("\(combatant.name) placeholder art")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var placeholderArt: some View {
        let style: TrinketDesign.CardPlaceholderStyle
        switch combatant.role {
        case .hero: style = .hero
        case .pet: style = .pet
        case .enemy: style = .enemy
        }

        return ZStack {
            style.color.opacity(0.18)

            Image(systemName: style.symbolName)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}

struct BattleCombatantPane: View {
    enum HealthBarPlacement {
        case top
        case bottom
    }

    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let healthBarPlacement: HealthBarPlacement
    let events: [ActionEvent]
    let reduceMotion: Bool
    let onRemoveEvent: (Int) -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                BattleArtViewport(combatant: combatant)

                healthScrim

                healthBar

                CombatFeedbackOverlay(
                    events: events,
                    reduceMotion: reduceMotion,
                    onRemoveEvent: onRemoveEvent
                )
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketCardSurface()
            .contentShape(TrinketDesign.cardShape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(combatant.name) card")
            .accessibilityValue(healthText)
            .accessibilityHint("Shows details")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("\(combatant.name) card")
    }

    private var healthText: String {
        "\(health)/\(maxHealth) HP"
    }

    private var healthBar: some View {
        VStack {
            if healthBarPlacement == .bottom {
                Spacer(minLength: 0)
            }

            CombatHealthBar(
                health: health,
                maxHealth: maxHealth,
                fillColor: combatant.healthBarColor
            )
            .accessibilityHidden(true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if healthBarPlacement == .top {
                Spacer(minLength: 0)
            }
        }
    }

    private var healthScrim: some View {
        VStack {
            if healthBarPlacement == .bottom {
                Spacer(minLength: 0)
            }

            LinearGradient(
                // UIStyleCheck: allow - battle health bars need readable contrast over full-bleed art.
                colors: [Color.black.opacity(0.42), .clear],
                startPoint: healthBarPlacement == .top ? .top : .bottom,
                endPoint: healthBarPlacement == .top ? .bottom : .top
            )
            .frame(height: 54)

            if healthBarPlacement == .top {
                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct CombatFeedbackOverlay: View {
    let events: [ActionEvent]
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
    let event: ActionEvent
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
        let display = ActionEventFormatter.display(for: event)
        return HStack(spacing: 6) {
            Image(systemName: display.keyword.visualStyle.symbolName)
                .font(.caption.bold())
                .symbolEffect(.bounce, value: event.id)

            Text(display.text)
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(display.keyword.visualStyle.color)
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
    let summary: BattleVictorySummary
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

                VictoryRewardSection(title: "Experience") {
                    if summary.experience > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            ExperienceBar(
                                combatantName: summary.heroName,
                                pre: summary.heroProgressionBefore,
                                post: summary.heroProgressionAfter,
                                fillColor: TrinketDesign.Colors.progression
                            )
                            .accessibilityIdentifier("\(summary.heroName) experience bar")

                            ExperienceBar(
                                combatantName: summary.petName,
                                pre: summary.petProgressionBefore,
                                post: summary.petProgressionAfter,
                                fillColor: TrinketDesign.Colors.progression
                            )
                            .accessibilityIdentifier("\(summary.petName) experience bar")
                        }
                    } else {
                        VictoryRewardRow(
                            symbolName: "star",
                            tint: .secondary,
                            text: "No experience awarded."
                        )
                    }
                }

                VictoryRewardSection(title: "Rewards") {
                    if summary.totalGold > 0 {
                        VictoryRewardRow(
                            symbolName: Keyword.gold.visualStyle.symbolName,
                            tint: Keyword.gold.visualStyle.color,
                            text: "+\(summary.totalGold) Gold"
                        )
                    }

                    if summary.itemNames.isEmpty {
                        if summary.totalGold == 0 {
                            VictoryRewardRow(
                                symbolName: "bag",
                                tint: .secondary,
                                text: "No items awarded."
                            )
                        }
                    } else {
                        ForEach(summary.itemNames, id: \.self) { itemName in
                            VictoryRewardRow(
                                symbolName: "bag.fill",
                                tint: Color.accentColor,
                                text: itemName
                            )
                        }
                    }
                }

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

struct VictoryRewardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .trinketCardSurface()
    }
}

struct VictoryRewardRow: View {
    let symbolName: String
    let tint: Color
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
        }
    }
}

struct BattleLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let entries: [LogEntry]

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

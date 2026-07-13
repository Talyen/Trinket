import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct VictoryView: View {
    private enum PresentationState {
        case experienceAndChest
        case rewardsOpened
    }

    @Environment(AppState.self) private var appState

    let enemyName: String
    let summary: BattleVictorySummary
    let primaryActionTitle: String
    let onPrimaryAction: () -> Bool

    @State private var presentationState = PresentationState.experienceAndChest
    @State private var shouldSnapExperience = false
    @State private var openFeedbackTrigger = 0
    @State private var isCompleting = false
    @State private var hasRevealedFocus = false
    @State private var hasSettledResources = false
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        RewardRevealShell(
            eyebrow: nil,
            eyebrowAccessibilityIdentifier: nil,
            title: "Victory",
            subtitle: "\(enemyName) is defeated.",
            titleAccessibilityIdentifier: AccessibilityID.Battle.victory,
            titleColor: TrinketDesign.Colors.accent,
            content: {
                Group {
                    switch presentationState {
                    case .experienceAndChest:
                        experienceAndChest
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    case .rewardsOpened:
                        openedRewards
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(TrinketMotion.Reward.stateChange, value: presentationState)
            },
            primaryActionTitle: presentationState == .experienceAndChest
                ? "Open Rewards"
                : primaryActionTitle,
            primaryActionAccessibilityIdentifier: presentationState == .experienceAndChest
                ? AccessibilityID.Battle.openRewards
                : "\(primaryActionTitle) Button",
            isPrimaryActionDisabled: isCompleting,
            onPrimaryAction: handlePrimaryAction
        )
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: openFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
        .onDisappear {
            revealTask?.cancel()
            revealTask = nil
        }
    }

    private var experienceAndChest: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            experiencePanel

            Button(action: openRewards) {
                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    RewardChestView(isOpen: false, isEnticing: true)
                        .frame(maxWidth: 340)

                    rewardAwaitingDivider
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
            }
            .trinketArtworkNavigationCardButtonStyle()
            .accessibilityIdentifier(AccessibilityID.Battle.rewardChest)
        }
    }

    @ViewBuilder
    private var experiencePanel: some View {
        if summary.hasExperienceAwards {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                ExperienceBar(
                    combatantName: summary.heroName,
                    artworkName: summary.heroArtworkName,
                    pre: summary.heroProgressionBefore,
                    post: summary.heroProgressionAfter,
                    fillColor: TrinketDesign.Colors.progression,
                    experienceAward: summary.experience,
                    snapToFinal: shouldSnapExperience
                )
                .accessibilityIdentifier("\(summary.heroName) experience bar")

                ExperienceBar(
                    combatantName: summary.companionName,
                    artworkName: summary.companionArtworkName,
                    pre: summary.companionProgressionBefore,
                    post: summary.companionProgressionAfter,
                    fillColor: TrinketDesign.Colors.progression,
                    experienceAward: summary.companionExperience,
                    snapToFinal: shouldSnapExperience
                )
                .accessibilityIdentifier("\(summary.companionName) experience bar")
            }
            .trinketSurface(.secondary)
            .accessibilityIdentifier(AccessibilityID.Battle.experience)
        } else {
            BattleOutcomeRewardRow(
                symbolName: "star",
                tint: .secondary,
                text: "No experience awarded."
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .trinketSurface(.secondary)
            .accessibilityIdentifier(AccessibilityID.Battle.experience)
        }
    }

    private var openedRewards: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            ZStack(alignment: .top) {
                RewardChestView(isOpen: true, isEnticing: false)
                    .frame(maxWidth: 250)

                if summary.rewardItems.isEmpty {
                    noItemRewardFocus
                        .padding(.top, 148)
                        .opacity(hasRevealedFocus ? 1 : 0)
                        .offset(y: hasRevealedFocus ? 0 : 18)
                } else {
                    rewardItemPager
                        .padding(.top, 136)
                        .opacity(hasRevealedFocus ? 1 : 0)
                        .offset(y: hasRevealedFocus ? 0 : 18)
                }
            }
            .padding(.top, -TrinketDesign.Metrics.smallSpacing)

            if !summary.rewardItems.isEmpty {
                resourceRewards
                    .opacity(hasSettledResources ? 1 : 0)
                    .offset(y: hasSettledResources ? 0 : 10)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Battle.rewards)
    }

    private var rewardItemPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                ForEach(summary.rewardItems) { item in
                    RewardItemRevealCard(item: item)
                        .containerRelativeFrame(.horizontal)
                        .accessibilityIdentifier(AccessibilityID.Battle.rewardItem(item.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
    }

    private var rewardAwaitingDivider: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            Rectangle()
                .fill(TrinketDesign.Colors.accent.opacity(0.42))
                .frame(height: 1)

            Image(systemName: "diamond.fill")
                .font(.caption2)

            Text("Rewards Await")
                .trinketTypography(.sectionDisplay)
                .fixedSize()

            Image(systemName: "diamond.fill")
                .font(.caption2)

            Rectangle()
                .fill(TrinketDesign.Colors.accent.opacity(0.42))
                .frame(height: 1)
        }
        .foregroundStyle(TrinketDesign.Colors.accent)
    }

    private var noItemRewardFocus: some View {
        let materials = summary.materialRewards.filter { $0.quantity > 0 }
        return ScrollView(.horizontal) {
            HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                if summary.totalGold > 0 {
                    RewardResourceTile(
                        symbolName: Keyword.gold.visualStyle.symbolName,
                        tint: Keyword.gold.visualStyle.color,
                        amount: summary.totalGold,
                        title: "Gold"
                    )
                }

                ForEach(materials, id: \.resource) { reward in
                    RewardResourceTile(
                        symbolName: reward.resource.symbolName,
                        tint: reward.resource.tint,
                        amount: reward.quantity,
                        title: reward.resource.displayName
                    )
                }

                if summary.totalGold == 0, materials.isEmpty {
                    RewardResourceTile(
                        symbolName: "sparkles",
                        tint: TrinketDesign.Colors.accent,
                        amount: nil,
                        title: "Victory"
                    )
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.smallSpacing)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var resourceRewards: some View {
        let materials = summary.materialRewards.filter { $0.quantity > 0 }
        if summary.totalGold > 0 || !materials.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    resourceRewardChips(materials: materials)
                }
                .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
            }
            .scrollIndicators(.hidden)
        } else if summary.rewardItems.isEmpty {
            Text("No additional rewards.")
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func resourceRewardChips(materials: [ResourceAmount]) -> some View {
        if summary.totalGold > 0 {
            RewardResourceChip(
                symbolName: Keyword.gold.visualStyle.symbolName,
                tint: Keyword.gold.visualStyle.color,
                text: "+\(summary.totalGold) Gold"
            )
        }

        ForEach(materials, id: \.resource) { reward in
            RewardResourceChip(
                symbolName: reward.resource.symbolName,
                tint: reward.resource.tint,
                text: "+\(reward.quantity) \(reward.resource.displayName)"
            )
        }
    }

    private func handlePrimaryAction() {
        switch presentationState {
        case .experienceAndChest:
            openRewards()
        case .rewardsOpened:
            guard !isCompleting else { return }
            isCompleting = onPrimaryAction()
        }
    }

    private func openRewards() {
        guard presentationState == .experienceAndChest else { return }
        shouldSnapExperience = true
        appState.sfxPlayer.play(SFXID.uiConfirm, volume: appState.options.effectsVolume)
        openFeedbackTrigger += 1
        withAnimation(TrinketMotion.Reward.reveal) {
            presentationState = .rewardsOpened
        }
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            let clock = SuspendingClock()
            try? await clock.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.reveal) {
                hasRevealedFocus = true
            }
            try? await clock.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.stateChange) {
                hasSettledResources = true
            }
        }
    }
}

private struct RewardChestView: View {
    let isOpen: Bool
    let isEnticing: Bool

    @State private var isBreathing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(TrinketDesign.Colors.accent.opacity(isOpen ? 0.28 : 0.16))
                .frame(width: isOpen ? 190 : 240, height: isOpen ? 54 : 72)
                .blur(radius: isOpen ? 20 : 14)
                .scaleEffect(isBreathing ? 1.08 : 0.94)

            Image(isOpen ? "reward_chest_open" : "reward_chest_closed")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: isOpen ? 235 : 330)
                .scaleEffect(isBreathing ? 1.018 : 0.99)
                .offset(y: isBreathing ? -3 : 2)
                .shadow(
                    color: TrinketDesign.Colors.accent.opacity(isBreathing ? 0.34 : 0.16),
                    radius: isBreathing ? 18 : 10,
                    y: 5
                )
        }
        .frame(height: isOpen ? 210 : 250)
        .onAppear {
            guard isEnticing else { return }
            withAnimation(TrinketMotion.Reward.chestBreathing) {
                isBreathing = true
            }
        }
        .onDisappear {
            isBreathing = false
        }
    }
}

private struct RewardItemRevealCard: View {
    let item: InventoryItem

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ItemArtwork(item: item, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(TrinketDesign.Colors.surface, in: TrinketDesign.cardShape)
                .clipShape(TrinketDesign.cardShape)

            VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(item.displayName)
                    .trinketTypography(.sectionDisplay)
                    .multilineTextAlignment(.center)

                Text(item.rarity.label.uppercased())
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(TrinketDesign.Colors.accent)
            }

            if !item.affixes.isEmpty {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                    ForEach(item.affixes) { affix in
                        HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Metrics.smallSpacing) {
                            Text(affix.title)
                                .trinketTypography(.cardTitle)
                                .layoutPriority(1)

                            KeywordDescriptionText(text: affix.description)
                                .trinketTypography(.secondaryBody)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
                        .padding(.vertical, TrinketDesign.Metrics.smallSpacing)
                        .trinketSurface(.secondary)
                    }
                }
            }
        }
        .trinketSurface(.reward)
    }
}

private struct RewardResourceChip: View {
    let symbolName: String
    let tint: Color
    let text: String

    var body: some View {
        Label(text, systemImage: symbolName)
            .trinketTypography(.badge)
            .foregroundStyle(tint)
            .trinketGlassChip(.emphasis)
    }
}

private struct RewardResourceTile: View {
    let symbolName: String
    let tint: Color
    let amount: Int?
    let title: String

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            Image(systemName: symbolName)
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(tint)

            if let amount {
                Text("+\(amount)")
                    .trinketTypography(.sectionDisplay)
                    .monospacedDigit()
            }

            Text(title)
                .trinketTypography(.badge)
                .foregroundStyle(.secondary)
        }
        .frame(width: 148, height: 168)
        .trinketSurface(.reward)
    }
}

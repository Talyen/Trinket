import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    private let columns = [
        GridItem(.adaptive(minimum: 98), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(HomesteadResource.allCases) { resource in
                HStack(spacing: 7) {
                    Image(systemName: resource.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(resource.tint)
                        .frame(width: 18)

                    Text(resource.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 0)

                    Text("\(homestead.balance(for: resource, roster: roster))")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(resource.displayName), \(homestead.balance(for: resource, roster: roster))")
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
    }
}

struct HomesteadProjectShelf: View {
    let category: HomesteadNodeCategory
    let definitions: [HomesteadNodeDefinition]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let recentUpgradeID: HomesteadNodeID?
    let onBuild: (HomesteadNodeDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue)
                .font(.headline)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(definitions) { definition in
                        HomesteadProjectCard(
                            definition: definition,
                            status: HomesteadProjectStatus(
                                definition: definition,
                                homestead: homestead,
                                roster: roster
                            ),
                            isRecentlyUpgraded: recentUpgradeID == definition.id,
                            onBuild: { onBuild(definition) }
                        )
                        .containerRelativeFrame(.horizontal) { length, _ in
                            min(length - 48, 340)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, TrinketDesign.Metrics.contentMargin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

struct HomesteadProjectCard: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let isRecentlyUpgraded: Bool
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                HomesteadNodeDetailView(definition: definition)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HomesteadBuildingArtwork(definition: definition)
                        .aspectRatio(4.0 / 3.0, contentMode: .fit)
                        .saturation(status.isUnlocked ? 1 : 0.1)
                        .opacity(status.isUnlocked ? 1 : 0.56)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(definition.title)
                                .font(.headline)
                                .foregroundStyle(status.isUnlocked ? .primary : .secondary)
                                .lineLimit(2)

                            Spacer(minLength: 0)

                            Image(systemName: trailingSymbolName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(trailingSymbolColor)
                        }

                        HomesteadTierPips(
                            currentTier: status.currentTier,
                            maxTier: definition.maxTier,
                            tint: definition.tint,
                            isUnlocked: status.isUnlocked
                        )
                    }

                    if let nextTier = status.nextTier {
                        HomesteadCompactCostChips(
                            cost: nextTier.cost,
                            status: status
                        )
                    }
                }
                .contentShape(Rectangle())
            }
            // UIStyleCheck: allow - Card navigation should not render as a bordered button.
            .buttonStyle(.plain)

            if status.isComplete {
                Label("Complete", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            } else {
                Button(action: onBuild) {
                    Label(status.actionTitle, systemImage: status.canBuildOrUpgrade ? "hammer.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .disabled(!status.canBuildOrUpgrade)
            }
        }
        .padding(12)
        .trinketCardSurface()
        .overlay {
            if isRecentlyUpgraded {
                TrinketDesign.cardShape
                    .stroke(TrinketDesign.Colors.success.opacity(0.72), lineWidth: 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    private var trailingSymbolName: String {
        if !status.isUnlocked { return "lock.fill" }
        if status.isComplete { return "checkmark.seal.fill" }
        return status.canBuildOrUpgrade ? "hammer.circle.fill" : "circle.dashed"
    }

    private var trailingSymbolColor: Color {
        if !status.isUnlocked { return .secondary }
        if status.isComplete { return TrinketDesign.Colors.success }
        return status.canBuildOrUpgrade ? definition.tint : .secondary
    }
}

struct HomesteadTierPips: View {
    let currentTier: Int
    let maxTier: Int
    let tint: Color
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1 ... maxTier, id: \.self) { tier in
                Capsule(style: .continuous)
                    .fill(fillColor(for: tier))
                    .frame(width: tier <= currentTier ? 26 : 18, height: 6)
                    .animation(.snappy, value: currentTier)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentTier == 0 ? "Unbuilt" : "Tier \(currentTier) of \(maxTier)")
    }

    private func fillColor(for tier: Int) -> Color {
        guard isUnlocked else { return .secondary.opacity(0.18) }
        return tier <= currentTier ? tint : .secondary.opacity(0.24)
    }
}

struct HomesteadCompactCostChips: View {
    let cost: [ResourceAmount]
    let status: HomesteadProjectStatus

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(cost) { amount in
                let balance = status.balance(for: amount)
                HStack(spacing: 5) {
                    Image(systemName: amount.resource.symbolName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(amount.resource.tint)

                    Text(amount.resource.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HomesteadRequirementCountText(
                        balance: balance,
                        required: amount.quantity,
                        font: .caption.monospacedDigit().weight(.semibold)
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(status.hasEnough(amount) ? amount.resource.tint.opacity(0.12) : Color(.tertiarySystemBackground))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(amount.resource.displayName), \(status.balance(for: amount)) available, \(amount.quantity) required")
            }
        }
    }
}

struct HomesteadRequirementCountText: View {
    let balance: Int
    let required: Int
    let font: Font

    private var hasEnough: Bool {
        balance >= required
    }

    var body: some View {
        if hasEnough {
            Text("\(balance)/\(required)")
                .font(font)
                .foregroundStyle(TrinketDesign.Colors.success)
                .contentTransition(.numericText())
        } else {
            HStack(spacing: 0) {
                Text("\(balance)")
                    .foregroundStyle(TrinketDesign.Colors.destructive)
                Text("/\(required)")
                    .foregroundStyle(.secondary)
            }
            .font(font)
            .contentTransition(.numericText())
        }
    }
}

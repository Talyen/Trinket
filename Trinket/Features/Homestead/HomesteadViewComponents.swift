import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

enum HomesteadProgression {
    static func recommendedProject(
        definitions: [HomesteadNodeDefinition],
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState
    ) -> HomesteadNodeDefinition? {
        let statuses = definitions.map {
            HomesteadProjectStatus(definition: $0, homestead: homestead, roster: roster)
        }

        return statuses.first(where: \.canBuildOrUpgrade)?.definition
            ?? statuses.first(where: { $0.isUnlocked && !$0.isComplete })?.definition
            ?? statuses.first(where: { !$0.isUnlocked })?.definition
            ?? statuses.first?.definition
    }

    static func visibleDefinitions(
        in category: HomesteadNodeCategory,
        all definitions: [HomesteadNodeDefinition],
        homestead: PlayerHomesteadState
    ) -> [HomesteadNodeDefinition] {
        let categoryDefinitions = definitions.filter { $0.category == category }
        let visible = categoryDefinitions.filter { definition in
            homestead.tier(for: definition.id) > 0 || homestead.isUnlocked(definition)
        }

        guard let nextLocked = categoryDefinitions.first(where: { definition in
            !visible.contains(definition) && shouldRevealLocked(definition, homestead: homestead)
        }) else {
            return visible
        }

        return visible + [nextLocked]
    }

    static func walletResources(
        for featured: HomesteadNodeDefinition?,
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState
    ) -> [HomesteadResource] {
        var resources = HomesteadResource.allCases.filter { homestead.balance(for: $0, roster: roster) > 0 }
        if let featured,
           let nextTier = homestead.nextTier(for: featured) {
            for amount in nextTier.cost where !resources.contains(amount.resource) {
                resources.append(amount.resource)
            }
        }
        return resources.isEmpty ? [.wood, .stone, .gold] : resources
    }

    private static func shouldRevealLocked(
        _ definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadState
    ) -> Bool {
        guard !definition.prerequisites.isEmpty else { return true }
        return definition.prerequisites.allSatisfy { requirement in
            guard let prerequisite = GameContent.homesteadNode(matching: requirement.nodeID) else {
                return false
            }
            return homestead.tier(for: requirement.nodeID) > 0 || homestead.isUnlocked(prerequisite)
        }
    }
}

struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let resources: [HomesteadResource]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(resources) { resource in
                    HomesteadResourcePill(
                        resource: resource,
                        balance: homestead.balance(for: resource, roster: roster)
                    )
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

struct HomesteadResourcePill: View {
    let resource: HomesteadResource
    let balance: Int

    var body: some View {
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

            Text("\(balance)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // UIStyleCheck: allow - Resource wallet is compact glass chrome, not a content card.
        .background(.thinMaterial, in: Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resource.displayName), \(balance)")
    }
}

struct HomesteadFeaturedProjectCard: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                HomesteadNodeDetailView(definition: definition)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HomesteadBuildingArtwork(definition: definition)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .saturation(status.isUnlocked ? 1 : 0.16)
                        .opacity(status.isUnlocked ? 1 : 0.62)
                        .overlay(alignment: .topLeading) {
                            HomesteadStatusBadge(status: status)
                                .padding(12)
                        }

                    VStack(alignment: .leading, spacing: 7) {
                        Text(featuredTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(definition.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Spacer(minLength: 0)

                            Text("Tier \(status.currentTier)/\(definition.maxTier)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        if let bonus = status.nextBonus ?? definition.tier(status.currentTier)?.bonus {
                            Text(bonus.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HomesteadTierPips(
                            currentTier: status.currentTier,
                            maxTier: definition.maxTier,
                            tint: definition.tint,
                            isUnlocked: status.isUnlocked
                        )
                    }
                }
                .contentShape(Rectangle())
            }
            // UIStyleCheck: allow - Art-forward project cards should navigate without button chrome.
            .buttonStyle(.plain)

            if status.canBuildOrUpgrade {
                Button(action: onBuild) {
                    Label(status.actionTitle, systemImage: "hammer.fill")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
            } else if status.isComplete {
                Label("Complete", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                HomesteadMissingSummary(status: status)
            }
        }
        .padding(14)
        .trinketCardSurface()
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(definition.title) Featured Homestead Node")
    }

    private var featuredTitle: String {
        if status.canBuildOrUpgrade { return status.nextTier?.tier == 1 ? "Ready to Build" : "Ready to Upgrade" }
        if !status.isUnlocked { return "Next Unlock" }
        return "Gather Materials"
    }
}

struct HomesteadProjectSection: View {
    let category: HomesteadNodeCategory
    let definitions: [HomesteadNodeDefinition]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let recentUpgradeID: HomesteadNodeID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue)
                .font(.headline)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

            VStack(spacing: 10) {
                ForEach(definitions) { definition in
                    HomesteadProjectRow(
                        definition: definition,
                        status: HomesteadProjectStatus(
                            definition: definition,
                            homestead: homestead,
                            roster: roster
                        ),
                        isRecentlyUpgraded: recentUpgradeID == definition.id
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
    }
}

struct HomesteadProjectRow: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let isRecentlyUpgraded: Bool

    var body: some View {
        NavigationLink {
            HomesteadNodeDetailView(definition: definition)
        } label: {
            HStack(spacing: 12) {
                HomesteadBuildingArtwork(definition: definition)
                    .frame(width: 78, height: 78)
                    .saturation(status.isUnlocked ? 1 : 0.12)
                    .opacity(status.isUnlocked ? 1 : 0.58)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(definition.title)
                            .font(.headline)
                            .foregroundStyle(status.isUnlocked ? .primary : .secondary)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        Text("Tier \(status.currentTier)/\(definition.maxTier)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let bonus = status.nextBonus ?? definition.tier(status.currentTier)?.bonus {
                        Text(bonus.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HomesteadTierPips(
                        currentTier: status.currentTier,
                        maxTier: definition.maxTier,
                        tint: definition.tint,
                        isUnlocked: status.isUnlocked
                    )

                    HomesteadStatusBadge(status: status)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: TrinketDesign.cardShape)
            .overlay {
                if isRecentlyUpgraded {
                    TrinketDesign.cardShape
                        .stroke(TrinketDesign.Colors.success.opacity(0.72), lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        // UIStyleCheck: allow - Project rows use the whole row as the native navigation affordance.
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }
}

struct HomesteadStatusBadge: View {
    let status: HomesteadProjectStatus

    var body: some View {
        Label(status.statusTitle, systemImage: status.statusSymbolName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.statusColor)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            // UIStyleCheck: allow - Status badges intentionally float as native glass chips.
            .background(.regularMaterial, in: Capsule(style: .continuous))
            .accessibilityLabel(status.statusTitle)
    }
}

struct HomesteadMissingSummary: View {
    let status: HomesteadProjectStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.statusSymbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status.statusColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(status.statusTitle)
                    .font(.subheadline.weight(.semibold))

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        if !status.isUnlocked {
            return "Complete the prerequisite project to reveal this upgrade."
        }
        if status.missingResources.isEmpty {
            return "This project is not ready yet."
        }
        return status.missingResources
            .map { "\($0.quantity) \($0.resource.displayName)" }
            .joined(separator: ", ")
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

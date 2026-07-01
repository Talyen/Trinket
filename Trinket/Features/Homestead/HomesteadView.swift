import SwiftUI

struct HomesteadView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var upgradeEventCount = 0
    @State private var recentUpgradeID: HomesteadNodeID?

    private var homesteadState: PlayerHomesteadState {
        appState.homestead.current
    }

    private var rosterState: PlayerRosterState {
        appState.roster.current
    }

    private var nextProject: HomesteadNodeDefinition? {
        GameContent.homesteadNodes.first { definition in
            homesteadState.isUnlocked(definition) &&
                !homesteadState.isComplete(definition) &&
                homesteadState.nextTier(for: definition) != nil
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    HomesteadResourceWallet(
                        homestead: homesteadState,
                        roster: rosterState
                    )

                    if let nextProject {
                        HomesteadNextProjectPanel(
                            definition: nextProject,
                            homestead: homesteadState,
                            roster: rosterState,
                            onBuild: { buildOrUpgrade(nextProject, proxy: proxy) }
                        )
                        .padding(.horizontal, 20)
                    }

                    HomesteadPathView(
                        definitions: GameContent.homesteadNodes,
                        homestead: homesteadState,
                        roster: rosterState,
                        recentUpgradeID: recentUpgradeID
                    )
                }
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(TrinketDesign.Colors.appBackground)
            .navigationTitle("Homestead")
            .navigationBarTitleDisplayMode(.large)
            .sensoryFeedback(.success, trigger: upgradeEventCount)
        }
    }

    private func buildOrUpgrade(_ definition: HomesteadNodeDefinition, proxy: ScrollViewProxy) {
        guard appState.homestead.buildOrUpgrade(definition, roster: appState.roster) else { return }
        recentUpgradeID = definition.id
        upgradeEventCount += 1

        guard !reduceMotion else { return }
        withAnimation(.snappy) {
            proxy.scrollTo(definition.id, anchor: .center)
        }
    }
}

private struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(HomesteadResource.allCases) { resource in
                HStack(spacing: 7) {
                    Image(systemName: resource.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(resource.tint)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(resource.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(homestead.balance(for: resource, roster: roster))")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(resource.displayName), \(homestead.balance(for: resource, roster: roster))")
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct HomesteadNextProjectPanel: View {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let onBuild: () -> Void

    private var nextTier: HomesteadNodeTier? {
        homestead.nextTier(for: definition)
    }

    private var isAffordable: Bool {
        nextTier.map { homestead.canAfford($0, roster: roster) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                HomesteadBuildingArtwork(definition: definition)
                    .frame(width: 94, height: 94)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Project")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(definition.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(definition.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let nextTier {
                HomesteadRequirementList(
                    cost: nextTier.cost,
                    homestead: homestead,
                    roster: roster
                )

                Button(action: onBuild) {
                    Label(actionTitle(for: nextTier), systemImage: isAffordable ? "hammer.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .disabled(!isAffordable)
            }
        }
        .padding(16)
        .trinketCardSurface()
        .accessibilityIdentifier("Homestead Next Project")
    }

    private func actionTitle(for tier: HomesteadNodeTier) -> String {
        if !isAffordable {
            return "Gather Materials"
        }
        return tier.tier == 1 ? "Construct" : "Upgrade to Tier \(tier.tier)"
    }
}

private struct HomesteadPathView: View {
    let definitions: [HomesteadNodeDefinition]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let recentUpgradeID: HomesteadNodeID?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(definitions) { definition in
                VStack(spacing: 0) {
                    if definition.id != definitions.first?.id {
                        HomesteadPathConnector()
                    }

                    NavigationLink {
                        HomesteadNodeDetailView(definition: definition)
                    } label: {
                        HomesteadNodeCard(
                            definition: definition,
                            homestead: homestead,
                            roster: roster,
                            isRecentlyUpgraded: recentUpgradeID == definition.id
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!homestead.isUnlocked(definition))
                    .id(definition.id)
                    .accessibilityIdentifier("\(definition.title) Homestead Node")
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct HomesteadPathConnector: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.24))
            .frame(width: 2, height: 26)
            .accessibilityHidden(true)
    }
}

private struct HomesteadNodeCard: View {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let isRecentlyUpgraded: Bool

    private var currentTier: Int {
        homestead.tier(for: definition.id)
    }

    private var nextTier: HomesteadNodeTier? {
        homestead.nextTier(for: definition)
    }

    private var isUnlocked: Bool {
        homestead.isUnlocked(definition)
    }

    private var isAffordable: Bool {
        nextTier.map { homestead.canAfford($0, roster: roster) } ?? false
    }

    var body: some View {
        HStack(spacing: 14) {
            HomesteadBuildingArtwork(definition: definition)
                .frame(width: 112, height: 112)
                .saturation(isUnlocked ? 1 : 0.1)
                .opacity(isUnlocked ? 1 : 0.55)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(definition.title)
                        .font(.headline)
                        .foregroundStyle(isUnlocked ? .primary : .secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Image(systemName: trailingSymbolName)
                        .foregroundStyle(trailingSymbolColor)
                }

                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .trinketCardSurface()
        .overlay {
            if isRecentlyUpgraded {
                TrinketDesign.cardShape
                    .stroke(TrinketDesign.Colors.success.opacity(0.65), lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title), \(statusText). \(detailText)")
    }

    private var trailingSymbolName: String {
        if !isUnlocked { return "lock.fill" }
        if homestead.isComplete(definition) { return "checkmark.seal.fill" }
        return isAffordable ? "hammer.circle.fill" : "circle.dashed"
    }

    private var trailingSymbolColor: Color {
        if !isUnlocked { return .secondary }
        if homestead.isComplete(definition) { return TrinketDesign.Colors.success }
        return isAffordable ? definition.tint : .secondary
    }

    private var statusText: String {
        if !isUnlocked { return "Locked" }
        if currentTier == 0 { return "Ready to Construct" }
        return "Tier \(currentTier) / \(definition.maxTier)"
    }

    private var statusColor: Color {
        if !isUnlocked { return .secondary }
        if isAffordable && !homestead.isComplete(definition) { return definition.tint }
        return .primary
    }

    private var detailText: String {
        if !isUnlocked {
            return lockedRequirementsText
        }
        if homestead.isComplete(definition),
           let current = definition.tier(currentTier) {
            return current.bonus.description
        }
        if let nextTier {
            return nextTier.bonus.description
        }
        return definition.summary
    }

    private var lockedRequirementsText: String {
        let pieces = definition.prerequisites.compactMap { requirement -> String? in
            guard let dependency = GameContent.homesteadNode(matching: requirement.nodeID) else { return nil }
            return "\(dependency.title) Tier \(requirement.minimumTier)"
        }
        return "Requires " + pieces.joined(separator: ", ")
    }
}

private struct HomesteadNodeDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var upgradeEventCount = 0

    let definition: HomesteadNodeDefinition

    private var homestead: PlayerHomesteadState {
        appState.homestead.current
    }

    private var roster: PlayerRosterState {
        appState.roster.current
    }

    private var currentTier: Int {
        homestead.tier(for: definition.id)
    }

    private var nextTier: HomesteadNodeTier? {
        homestead.nextTier(for: definition)
    }

    private var isAffordable: Bool {
        nextTier.map { homestead.canAfford($0, roster: roster) } ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadBuildingArtwork(definition: definition)
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .trinketCardSurface()

                VStack(alignment: .leading, spacing: 8) {
                    Text(tierText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(definition.tint)
                    Text(definition.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HomesteadBonusSection(
                    title: "Current Bonus",
                    bonus: currentBonus
                )

                if let nextTier {
                    HomesteadBonusSection(
                        title: nextTier.tier == 1 ? "Construction Bonus" : "Next Bonus",
                        bonus: nextTier.bonus
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Requirements")
                            .font(.headline)
                        HomesteadRequirementList(
                            cost: nextTier.cost,
                            homestead: homestead,
                            roster: roster
                        )
                    }

                    Button(action: buildOrUpgrade) {
                        Label(actionTitle(for: nextTier), systemImage: isAffordable ? "hammer.fill" : "lock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .disabled(!isAffordable)
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(definition.title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: upgradeEventCount)
    }

    private var tierText: String {
        currentTier == 0 ? "Not Constructed" : "Tier \(currentTier) / \(definition.maxTier)"
    }

    private var currentBonus: HomesteadBonus {
        if let tier = definition.tier(currentTier) {
            return tier.bonus
        }
        return HomesteadBonus(
            title: "Dormant Site",
            description: "Construct this node to bring its first Homestead bonus online."
        )
    }

    private func actionTitle(for tier: HomesteadNodeTier) -> String {
        guard isAffordable else { return "Gather Materials" }
        return tier.tier == 1 ? "Construct" : "Upgrade to Tier \(tier.tier)"
    }

    private func buildOrUpgrade() {
        guard appState.homestead.buildOrUpgrade(definition, roster: appState.roster) else { return }
        upgradeEventCount += 1
        guard !reduceMotion else { return }
        withAnimation(.snappy) {}
    }
}

private struct HomesteadBonusSection: View {
    let title: String
    let bonus: HomesteadBonus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(bonus.title)
                    .font(.subheadline.weight(.semibold))
                Text(bonus.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
        }
    }
}

private struct HomesteadRequirementList: View {
    let cost: [ResourceAmount]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(cost) { amount in
                let balance = homestead.balance(for: amount.resource, roster: roster)
                HStack(spacing: 10) {
                    Image(systemName: amount.resource.symbolName)
                        .foregroundStyle(amount.resource.tint)
                        .frame(width: 22)
                    Text(amount.resource.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(min(balance, amount.quantity)) / \(amount.quantity)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(balance >= amount.quantity ? TrinketDesign.Colors.success : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(amount.resource.displayName), \(min(balance, amount.quantity)) of \(amount.quantity)")
            }
        }
    }
}

private struct HomesteadBuildingArtwork: View {
    let definition: HomesteadNodeDefinition

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            definition.tint.opacity(0.18),
                            Color(.secondarySystemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: definition.symbolName)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(definition.tint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("\(definition.title) artwork")
    }
}

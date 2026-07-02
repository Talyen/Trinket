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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadResourceWallet(
                    homestead: homesteadState,
                    roster: rosterState
                )

                ForEach(HomesteadNodeCategory.allCases) { category in
                    let definitions = definitions(in: category)
                    if !definitions.isEmpty {
                        HomesteadProjectShelf(
                            category: category,
                            definitions: definitions,
                            homestead: homesteadState,
                            roster: rosterState,
                            recentUpgradeID: recentUpgradeID,
                            onBuild: buildOrUpgrade
                        )
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Homestead")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
        .sensoryFeedback(.success, trigger: upgradeEventCount)
    }

    private func buildOrUpgrade(_ definition: HomesteadNodeDefinition) {
        guard appState.homestead.buildOrUpgrade(definition, roster: appState.roster) else { return }
        recentUpgradeID = definition.id
        upgradeEventCount += 1

        guard !reduceMotion else { return }
        withAnimation(.snappy) {
            recentUpgradeID = definition.id
        }
    }

    private func definitions(in category: HomesteadNodeCategory) -> [HomesteadNodeDefinition] {
        GameContent.homesteadNodes.filter { $0.category == category }
    }
}

private struct HomesteadProjectStatus {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    var currentTier: Int {
        homestead.tier(for: definition.id)
    }

    var nextTier: HomesteadNodeTier? {
        homestead.nextTier(for: definition)
    }

    var isUnlocked: Bool {
        homestead.isUnlocked(definition)
    }

    var isComplete: Bool {
        homestead.isComplete(definition)
    }

    var isAffordable: Bool {
        nextTier.map { homestead.canAfford($0, roster: roster) } ?? false
    }

    var canBuildOrUpgrade: Bool {
        isUnlocked && isAffordable && !isComplete
    }

    var actionTitle: String {
        guard let nextTier else { return "Complete" }
        return nextTier.tier == 1 ? "Build" : "Upgrade"
    }

    func balance(for amount: ResourceAmount) -> Int {
        homestead.balance(for: amount.resource, roster: roster)
    }

    func hasEnough(_ amount: ResourceAmount) -> Bool {
        balance(for: amount) >= amount.quantity
    }
}

private struct HomesteadResourceWallet: View {
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
        .padding(.horizontal, 20)
    }
}

private struct HomesteadProjectShelf: View {
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
                .padding(.horizontal, 20)

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
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

private struct HomesteadProjectCard: View {
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

private struct HomesteadTierPips: View {
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

private struct HomesteadCompactCostChips: View {
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

private struct HomesteadRequirementCountText: View {
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

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(
            definition: definition,
            homestead: homestead,
            roster: roster
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomesteadBuildingArtwork(definition: definition)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .saturation(status.isUnlocked ? 1 : 0.1)
                    .opacity(status.isUnlocked ? 1 : 0.56)
                    .trinketCardSurface()

                VStack(alignment: .leading, spacing: 10) {
                    HomesteadTierPips(
                        currentTier: status.currentTier,
                        maxTier: definition.maxTier,
                        tint: definition.tint,
                        isUnlocked: status.isUnlocked
                    )
                    Text(definition.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !status.isUnlocked {
                    HomesteadPrerequisiteSection(definition: definition, homestead: homestead)
                }

                HomesteadBonusSection(
                    title: status.currentTier == 0 ? "Dormant" : "Current",
                    bonus: currentBonus
                )

                if let nextTier = status.nextTier {
                    HomesteadBonusSection(
                        title: nextTier.tier == 1 ? "Build" : "Upgrade",
                        bonus: nextTier.bonus
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Materials")
                            .font(.headline)
                        HomesteadRequirementList(
                            cost: nextTier.cost,
                            status: status
                        )
                    }

                    Button(action: buildOrUpgrade) {
                        Label(status.actionTitle, systemImage: status.canBuildOrUpgrade ? "hammer.fill" : "lock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .disabled(!status.canBuildOrUpgrade)
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(definition.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.Homestead.nodeDetail(title: definition.title))
        .sensoryFeedback(.success, trigger: upgradeEventCount)
    }

    private var currentBonus: HomesteadBonus {
        if let tier = definition.tier(status.currentTier) {
            return tier.bonus
        }
        return HomesteadBonus(
            title: "Unbuilt",
            description: "Build this project to bring its first Homestead bonus online."
        )
    }

    private func buildOrUpgrade() {
        guard appState.homestead.buildOrUpgrade(definition, roster: appState.roster) else { return }
        upgradeEventCount += 1
        guard !reduceMotion else { return }
        withAnimation(.snappy) {}
    }
}

private struct HomesteadPrerequisiteSection: View {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Path")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(definition.prerequisites, id: \.nodeID) { requirement in
                    HStack(spacing: 10) {
                        Image(systemName: isMet(requirement) ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(isMet(requirement) ? TrinketDesign.Colors.success : .secondary)
                            .frame(width: 22)
                        Text(title(for: requirement.nodeID))
                            .font(.subheadline)
                        Spacer()
                        Text("\(homestead.tier(for: requirement.nodeID)) / \(requirement.minimumTier)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isMet(requirement) ? TrinketDesign.Colors.success : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(title(for: requirement.nodeID)), \(homestead.tier(for: requirement.nodeID)) of \(requirement.minimumTier)")
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
        }
    }

    private func isMet(_ requirement: HomesteadNodeRequirement) -> Bool {
        homestead.tier(for: requirement.nodeID) >= requirement.minimumTier
    }

    private func title(for id: HomesteadNodeID) -> String {
        GameContent.homesteadNode(matching: id)?.title ?? id.rawValue
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
    let status: HomesteadProjectStatus

    var body: some View {
        VStack(spacing: 8) {
            ForEach(cost) { amount in
                let balance = status.balance(for: amount)
                HStack(spacing: 10) {
                    Image(systemName: amount.resource.symbolName)
                        .foregroundStyle(amount.resource.tint)
                        .frame(width: 22)
                    Text(amount.resource.displayName)
                        .font(.subheadline)
                    Spacer()
                    HomesteadRequirementCountText(
                        balance: balance,
                        required: amount.quantity,
                        font: .subheadline.monospacedDigit().weight(.semibold)
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(amount.resource.displayName), \(balance) available, \(amount.quantity) required")
            }
        }
    }
}

private struct HomesteadBuildingArtwork: View {
    let definition: HomesteadNodeDefinition

    var body: some View {
        ZStack {
            if let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] {
                Image(art.imageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
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
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("\(definition.title) artwork")
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(for: subviews, proposal: proposal)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let rows = rows(for: subviews, proposal: ProposedViewSize(width: bounds.width, height: proposal.height))
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, proposal: ProposedViewSize) -> [FlowRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [FlowRow] = []
        var current = FlowRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.elements.isEmpty ? size.width : current.width + spacing + size.width

            if nextWidth > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = FlowRow()
            }

            current.elements.append(FlowElement(index: index, size: size))
            current.width = current.elements.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.elements.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct FlowRow {
        var elements: [FlowElement] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private struct FlowElement {
        let index: Int
        let size: CGSize
    }
}

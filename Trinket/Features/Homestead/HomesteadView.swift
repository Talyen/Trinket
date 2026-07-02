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

                HomesteadUnlockMap(
                    definitions: GameContent.homesteadNodes,
                    homestead: homesteadState,
                    roster: rosterState,
                    recentUpgradeID: recentUpgradeID
                )
                .padding(.horizontal, 20)

                HomesteadProjectShelf(
                    definitions: GameContent.homesteadNodes,
                    homestead: homesteadState,
                    roster: rosterState,
                    recentUpgradeID: recentUpgradeID,
                    onBuild: buildOrUpgrade
                )
            }
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Homestead")
        .navigationBarTitleDisplayMode(.large)
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

    func shortfall(for amount: ResourceAmount) -> Int {
        max(0, amount.quantity - balance(for: amount))
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

private struct HomesteadUnlockMap: View {
    let definitions: [HomesteadNodeDefinition]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let recentUpgradeID: HomesteadNodeID?

    private let nodeSize: CGFloat = 54

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(edgePairs, id: \.id) { edge in
                    if let start = mapPosition(for: edge.from),
                       let end = mapPosition(for: edge.to) {
                        HomesteadMapConnector(
                            start: point(for: start, in: geometry.size),
                            end: point(for: end, in: geometry.size),
                            isActive: homestead.tier(for: edge.from) > 0 && homestead.isUnlocked(definition(for: edge.to))
                        )
                    }
                }

                ForEach(definitions) { definition in
                    if let position = mapPosition(for: definition.id) {
                        NavigationLink {
                            HomesteadNodeDetailView(definition: definition)
                        } label: {
                            HomesteadMapNode(
                                definition: definition,
                                status: HomesteadProjectStatus(
                                    definition: definition,
                                    homestead: homestead,
                                    roster: roster
                                ),
                                isRecentlyUpgraded: recentUpgradeID == definition.id
                            )
                        }
                        // UIStyleCheck: allow - Map nodes are icon-like navigation controls, not textual buttons.
                        .buttonStyle(.plain)
                        .frame(width: nodeSize, height: nodeSize)
                        .position(point(for: position, in: geometry.size))
                        .accessibilityIdentifier("\(definition.title) Homestead Map Node")
                    }
                }
            }
        }
        .frame(height: 278)
        .trinketCardSurface()
        .accessibilityElement(children: .contain)
    }

    private var edgePairs: [HomesteadMapEdge] {
        definitions.flatMap { definition in
            definition.prerequisites.map {
                HomesteadMapEdge(from: $0.nodeID, to: definition.id)
            }
        }
    }

    private func definition(for id: HomesteadNodeID) -> HomesteadNodeDefinition {
        definitions.first { $0.id == id } ?? definitions[0]
    }

    private func point(for position: HomesteadMapPosition, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * position.x,
            y: size.height * position.y
        )
    }

    private func mapPosition(for id: HomesteadNodeID) -> HomesteadMapPosition? {
        switch id {
        case .wheatField:
            return HomesteadMapPosition(x: 0.50, y: 0.10)
        case .herbGarden:
            return HomesteadMapPosition(x: 0.20, y: 0.28)
        case .chickenCoop:
            return HomesteadMapPosition(x: 0.80, y: 0.28)
        case .alchemyLab:
            return HomesteadMapPosition(x: 0.20, y: 0.48)
        case .blacksmithForge:
            return HomesteadMapPosition(x: 0.50, y: 0.48)
        case .pasture:
            return HomesteadMapPosition(x: 0.80, y: 0.48)
        case .crystalGarden:
            return HomesteadMapPosition(x: 0.28, y: 0.69)
        case .runesmithWorkshop:
            return HomesteadMapPosition(x: 0.72, y: 0.69)
        case .wishingWell:
            return HomesteadMapPosition(x: 0.50, y: 0.90)
        }
    }
}

private struct HomesteadMapPosition {
    let x: CGFloat
    let y: CGFloat
}

private struct HomesteadMapEdge: Hashable, Identifiable {
    let from: HomesteadNodeID
    let to: HomesteadNodeID

    var id: String {
        "\(from.rawValue)-\(to.rawValue)"
    }
}

private struct HomesteadMapConnector: View {
    let start: CGPoint
    let end: CGPoint
    let isActive: Bool

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            isActive ? AnyShapeStyle(TrinketDesign.Colors.success.opacity(0.58)) : AnyShapeStyle(Color.secondary.opacity(0.22)),
            style: StrokeStyle(lineWidth: isActive ? 3 : 2, lineCap: .round)
        )
        .animation(.snappy, value: isActive)
        .accessibilityHidden(true)
    }
}

private struct HomesteadMapNode: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let isRecentlyUpgraded: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] {
                    Image(art.imageName)
                        .resizable()
                        .scaledToFill()
                        .saturation(status.isUnlocked ? 1 : 0.08)
                        .opacity(status.isUnlocked ? 0.92 : 0.42)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(backgroundStyle)
                    Image(systemName: symbolName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(symbolColor)
                }
            }
            .overlay {
                Circle()
                    .fill(status.isUnlocked ? definition.tint.opacity(0.10) : Color(.systemBackground).opacity(0.42))
            }
            .overlay {
                Circle()
                    .stroke(borderColor, lineWidth: isRecentlyUpgraded ? 3 : 1)
            }

            if status.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .background(Circle().fill(Color(.systemBackground)))
            } else if !status.isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(Circle().fill(Color(.systemBackground)))
            }
        }
        .scaleEffect(isRecentlyUpgraded ? 1.08 : 1)
        .animation(.snappy, value: isRecentlyUpgraded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title), \(accessibilityStatus)")
    }

    private var backgroundStyle: AnyShapeStyle {
        if !status.isUnlocked {
            return AnyShapeStyle(Color(.tertiarySystemBackground))
        }
        if status.currentTier > 0 {
            return AnyShapeStyle(definition.tint.opacity(0.18))
        }
        return AnyShapeStyle(Color(.secondarySystemBackground))
    }

    private var borderColor: Color {
        if isRecentlyUpgraded { return TrinketDesign.Colors.success }
        if status.isComplete { return TrinketDesign.Colors.success.opacity(0.65) }
        if status.canBuildOrUpgrade { return definition.tint }
        return .secondary.opacity(0.24)
    }

    private var symbolName: String {
        status.isUnlocked ? definition.symbolName : "lock.fill"
    }

    private var symbolColor: Color {
        if !status.isUnlocked { return .secondary }
        if status.currentTier == 0 { return definition.tint.opacity(0.76) }
        return definition.tint
    }

    private var accessibilityStatus: String {
        if !status.isUnlocked { return "locked" }
        if status.isComplete { return "complete" }
        if status.currentTier == 0 { return "unbuilt" }
        return "tier \(status.currentTier) of \(definition.maxTier)"
    }
}

private struct HomesteadProjectShelf: View {
    let definitions: [HomesteadNodeDefinition]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let recentUpgradeID: HomesteadNodeID?
    let onBuild: (HomesteadNodeDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
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

                    HomesteadBuildingArtwork(definition: definition)
                        .aspectRatio(4.0 / 3.0, contentMode: .fit)
                        .saturation(status.isUnlocked ? 1 : 0.1)
                        .opacity(status.isUnlocked ? 1 : 0.56)

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
        .accessibilityIdentifier("\(definition.title) Homestead Node")
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
            ForEach(1...maxTier, id: \.self) { tier in
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
                let enough = status.hasEnough(amount)
                HStack(spacing: 5) {
                    Image(systemName: amount.resource.symbolName)
                        .font(.caption2.weight(.semibold))
                    Text("\(amount.quantity)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                    if enough {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                    }
                }
                .foregroundStyle(enough ? amount.resource.tint : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(enough ? amount.resource.tint.opacity(0.12) : Color(.tertiarySystemBackground))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(amount.resource.displayName), \(status.balance(for: amount)) available, \(amount.quantity) required")
            }
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
                let shortfall = status.shortfall(for: amount)
                HStack(spacing: 10) {
                    Image(systemName: amount.resource.symbolName)
                        .foregroundStyle(amount.resource.tint)
                        .frame(width: 22)
                    Text(amount.resource.displayName)
                        .font(.subheadline)
                    Spacer()
                    if shortfall == 0 {
                        Label("\(amount.quantity)", systemImage: "checkmark")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(TrinketDesign.Colors.success)
                    } else {
                        Text("\(balance) / \(amount.quantity)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, proposal: proposal)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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

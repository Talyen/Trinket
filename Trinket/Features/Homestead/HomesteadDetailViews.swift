import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadNodeDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var build = HomesteadBuildControl()
    @State private var highlightedTier: Int?
    @State private var viewportSize: CGSize = .zero
    @State private var walletHeight: CGFloat = 0

    let definition: HomesteadNodeDefinition

    private let bodyTopPadding: CGFloat = 10
    private let bodyStackSpacing: CGFloat = 18

    private var homestead: PlayerHomesteadState {
        appState.homestead.current
    }

    private var roster: PlayerRosterState {
        appState.roster.current
    }

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster)
    }

    /// Leftover band under the cinematic hero for the tier path (wallet + padding excluded).
    private var tierPathMinHeight: CGFloat {
        guard viewportSize.height > 0 else { return 0 }
        let heroHeight = HeroHeaderLayout.HeightPolicy.cinematicLandscape
            .height(forWidth: max(viewportSize.width, 1))
        let reserved = heroHeight
            + walletHeight
            + bodyTopPadding
            + TrinketDesign.Metrics.extraLargeSpacing
            + bodyStackSpacing
        return max(viewportSize.height - reserved, 0)
    }

    var body: some View {
        DetailHeroScrollShell(
            title: definition.title,
            backgroundMode: .homestead,
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            HomesteadDetailHero(
                definition: definition,
                status: status,
                baseHeight: baseHeight,
                overscroll: overscroll
            )
        } bodyContent: {
            VStack(alignment: .leading, spacing: bodyStackSpacing) {
                HomesteadResourceWallet(homestead: homestead, roster: roster)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { _, height in
                        walletHeight = height
                    }

                HomesteadTierPath(
                    definition: definition,
                    status: status,
                    highlightedTier: highlightedTier,
                    minHeight: tierPathMinHeight,
                    isBuilding: build.isBuilding,
                    onBuild: buildOrUpgrade
                )
            }
            .padding(.top, bodyTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.extraLargeSpacing)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { _, size in
            viewportSize = size
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.nodeDetail(title: definition.title))
        .trinketSensoryFeedback(
            .success,
            trigger: build.upgradeEventCount,
            enabled: appState.options.hapticsEnabled
        )
        .homesteadBuildErrorAlert(build: $build)
    }

    private func buildOrUpgrade() {
        let completedTier = status.nextTier?.tier
        build.perform(
            definition,
            saveStore: appState.playerSave
        ) { _ in
            guard let completedTier else { return }
            if reduceMotion {
                highlightedTier = completedTier
            } else {
                withAnimation(TrinketMotion.Homestead.tierCompletion) {
                    highlightedTier = completedTier
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(TrinketMotion.Homestead.reduceMotion) {
                    highlightedTier = nil
                }
            }
        }
    }
}

struct HomesteadDetailHero: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let baseHeight: CGFloat
    let overscroll: CGFloat

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .bottomLeading
        ) {
            HomesteadBuildingArtwork(definition: definition, variant: .full)
                .saturation(status.isUnlocked ? 1 : 0)
                .opacity(status.isUnlocked ? 1 : 0.66)
        } overlay: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, Color(red: 0.055, green: 0.038, blue: 0.02).opacity(0.9)],
                    startPoint: .init(x: 0.5, y: 0.42),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                Text(definition.title)
                    .trinketTypography(.screenDisplay)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.95), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.48), radius: 5, y: 2)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .padding(.bottom, 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(definition.title), tier \(status.currentTier) of \(definition.maxTier), \(status.statusTitle)"
        )
    }
}

struct HomesteadTierPath: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let highlightedTier: Int?
    var minHeight: CGFloat = 0
    var isBuilding = false
    var onBuild: (() -> Void)?

    private let nodeSize: CGFloat = 56
    private let minConnectorLength: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(definition.tiers.enumerated()), id: \.element.tier) { index, tier in
                HomesteadTierNode(
                    definition: definition,
                    tier: tier,
                    state: status.tierPathState(for: tier),
                    status: status,
                    isHighlighted: highlightedTier == tier.tier,
                    nodeSize: nodeSize,
                    isBuilding: isBuilding,
                    onBuild: onBuild
                )

                if index < definition.tiers.count - 1 {
                    HomesteadTierConnector(
                        color: connectorColor(after: tier),
                        nodeColumnWidth: nodeSize,
                        minLength: minConnectorLength
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .accessibilityIdentifier(AccessibilityID.Homestead.tierPath)
        .animation(TrinketMotion.Homestead.tierCompletion, value: status.currentTier)
    }

    private func connectorColor(after tier: HomesteadNodeTier) -> Color {
        switch status.tierPathState(for: tier) {
        case .completed: definition.tint.opacity(0.7)
        case .next, .future, .locked: Color.secondary.opacity(0.28)
        }
    }
}

/// Flexible vertical gap between tier rows; expands to fill leftover viewport height.
private struct HomesteadTierConnector: View {
    let color: Color
    let nodeColumnWidth: CGFloat
    let minLength: CGFloat

    var body: some View {
        Spacer(minLength: minLength)
            .overlay {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(color)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .frame(width: nodeColumnWidth)
                    Spacer(minLength: 0)
                }
            }
            .accessibilityHidden(true)
    }
}

struct HomesteadTierNode: View {
    let definition: HomesteadNodeDefinition
    let tier: HomesteadNodeTier
    let state: HomesteadTierPathState
    let status: HomesteadProjectStatus
    let isHighlighted: Bool
    var nodeSize: CGFloat = 56
    var isBuilding = false
    var onBuild: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPulse = false

    private var isActionable: Bool {
        if case .next(affordable: true) = state {
            return status.canBuildOrUpgrade
        }
        return false
    }

    private var showsCost: Bool {
        if case .next = state {
            return true
        }
        return false
    }

    private var actionTitle: String {
        tier.tier == 1 ? "Build" : "Upgrade"
    }

    private var actionSymbolName: String {
        tier.tier == 1 ? "hammer.fill" : "arrow.up.circle.fill"
    }

    var body: some View {
        Group {
            if isActionable, let onBuild {
                Button(action: onBuild) {
                    rowContent
                }
                .buttonStyle(.plain)
                .disabled(isBuilding)
                .accessibilityLabel(accessibilityLabelText)
                .accessibilityHint("Double-tap to \(actionTitle.lowercased()) this project.")
            } else {
                rowContent
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabelText)
            }
        }
        .accessibilityIdentifier(tierNodeAccessibilityID)
        .onAppear {
            guard isActionable, !reduceMotion else { return }
            glowPulse = true
        }
        .onChange(of: isActionable) { _, actionable in
            glowPulse = actionable && !reduceMotion
        }
    }

    private var tierNodeAccessibilityID: String {
        AccessibilityID.Homestead.tierNode(title: definition.title, tier: tier.tier)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                // Fixed-geometry glow ring: fill masks inward bloom. Pulse opacity only —
                // never radius/scale, which reads as the node bobbing.
                if isActionable {
                    Circle()
                        .strokeBorder(definition.tint, lineWidth: 2.5)
                        .shadow(color: definition.tint.opacity(0.85), radius: 3)
                        .shadow(color: definition.tint.opacity(0.4), radius: 6)
                        .opacity(actionableGlowOpacity)
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: glowPulse
                        )
                        .allowsHitTesting(false)
                }

                Circle()
                    .fill(nodeFill)

                Circle()
                    .strokeBorder(nodeStroke, lineWidth: nodeStrokeWidth)
                    .shadow(
                        color: completionGlowColor,
                        radius: isHighlighted ? 8 : 0
                    )

                nodeGlyph
            }
            .frame(width: nodeSize, height: nodeSize)

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(tier.bonus.title)
                    .trinketTypography(.sectionDisplay)
                    .foregroundStyle(nodeForeground)

                Text(tier.bonus.description)
                    .font(.subheadline)
                    .foregroundStyle(nodeSecondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if showsCost {
                    HomesteadTierCostLabel(cost: tier.cost, status: status)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var nodeGlyph: some View {
        switch glyphKind {
        case .action:
            Image(systemName: actionSymbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(definition.tint)
                .symbolRenderingMode(.hierarchical)
        case .completed:
            Image(systemName: "checkmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(definition.tint)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        case .theme:
            Image(systemName: definition.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(nodeForeground)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private enum GlyphKind {
        case action
        case completed
        case locked
        case theme
    }

    private var glyphKind: GlyphKind {
        if isActionable {
            return .action
        }
        switch state {
        case .completed: return .completed
        case .future, .locked: return .locked
        case .next: return .theme
        }
    }

    private var completionGlowColor: Color {
        isHighlighted && !reduceMotion ? definition.tint.opacity(0.32) : .clear
    }

    private var actionableGlowOpacity: Double {
        if reduceMotion {
            return 0.85
        }
        return glowPulse ? 1 : 0.4
    }

    private var nodeForeground: Color {
        switch state {
        case .completed: definition.tint
        case let .next(affordable): affordable ? definition.tint : .primary
        case .future, .locked: .secondary
        }
    }

    private var nodeSecondaryForeground: Color {
        switch state {
        case .completed, .next: .secondary
        case .future, .locked: Color.secondary.opacity(0.65)
        }
    }

    private var nodeFill: Color {
        switch state {
        case .completed: definition.tint.opacity(0.18)
        case let .next(affordable): definition.tint.opacity(affordable ? 0.2 : 0.08)
        case .future, .locked: Color.secondary.opacity(0.1)
        }
    }

    private var nodeStroke: Color {
        switch state {
        case .completed: definition.tint.opacity(0.48)
        case let .next(affordable):
            affordable ? definition.tint : definition.tint.opacity(0.55)
        case .future, .locked: Color.secondary.opacity(0.2)
        }
    }

    private var nodeStrokeWidth: CGFloat {
        if isActionable {
            return 2.5
        }
        if case .next = state {
            return 1.5
        }
        return 1
    }

    private var accessibilityLabelText: String {
        var parts = [
            "Tier \(tier.tier)",
            tier.bonus.title,
            tier.bonus.description,
            accessibilityState
        ]
        if showsCost {
            let costs = tier.cost.map { "\($0.quantity) \($0.resource.displayName)" }
                .joined(separator: ", ")
            parts.append("Costs \(costs)")
        }
        if isActionable {
            parts.append("Double-tap to \(actionTitle.lowercased())")
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityState: String {
        switch state {
        case .completed: "Completed"
        case let .next(affordable):
            affordable ? "Ready to \(actionTitle.lowercased())" : "Next tier, resources needed"
        case .future: "Locked until earlier tiers are complete"
        case .locked: "Locked by prerequisites"
        }
    }
}

struct HomesteadTierCostLabel: View {
    let cost: [ResourceAmount]
    let status: HomesteadProjectStatus

    var body: some View {
        HStack(spacing: 8) {
            ForEach(cost) { amount in
                HStack(spacing: 3) {
                    HomesteadResourceArtwork(resource: amount.resource)
                        .frame(width: 20, height: 20)
                    Text("\(amount.quantity)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(
                            status.hasEnough(amount)
                                ? Color.primary
                                : TrinketDesign.Colors.destructive
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

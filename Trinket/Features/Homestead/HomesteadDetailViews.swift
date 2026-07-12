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

                HomesteadTierPath(
                    definition: definition,
                    status: status,
                    highlightedTier: highlightedTier,
                    isBuilding: build.isBuilding,
                    onBuild: buildOrUpgrade
                )
            }
            .padding(.top, bodyTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.extraLargeSpacing)
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
    var isBuilding = false
    var onBuild: (() -> Void)?

    private let nodeSize: CGFloat = 56
    private let railWidth: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(definition.tiers.enumerated()), id: \.element.tier) { index, tier in
                HomesteadTierNode(
                    definition: definition,
                    tier: tier,
                    state: status.tierPathState(for: tier),
                    status: status,
                    isHighlighted: highlightedTier == tier.tier,
                    connectors: status.tierPathConnectors(for: index),
                    nodeSize: nodeSize,
                    railWidth: railWidth,
                    isBuilding: isBuilding,
                    onBuild: onBuild
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .accessibilityIdentifier(AccessibilityID.Homestead.tierPath)
    }
}

struct HomesteadTierNode: View {
    let definition: HomesteadNodeDefinition
    let tier: HomesteadNodeTier
    let state: HomesteadTierPathState
    let status: HomesteadProjectStatus
    let isHighlighted: Bool
    let connectors: (before: PathConnectorState?, after: PathConnectorState?)
    var nodeSize: CGFloat = 56
    var railWidth: CGFloat = 56
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
        "hammer.fill"
    }

    private var connectorStyle: PathConnectorStyle {
        PathConnectorStyle(
            progressedColor: definition.tint.opacity(0.7),
            futureColor: Color.secondary.opacity(0.28),
            progressedWidth: 2.5,
            futureWidth: 2
        )
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
        HStack(alignment: .center, spacing: 14) {
            VerticalPathRail(
                nodeSize: nodeSize,
                minHeight: 72,
                connectorBefore: connectors.before,
                connectorAfter: connectors.after,
                style: connectorStyle
            ) {
                tierNodeChrome
            }
            .frame(width: railWidth)

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(tier.bonus.title)
                    .trinketTypography(.sectionDisplay)
                    .foregroundStyle(nodeForeground)

                Text(tier.bonus.description)
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(nodeSecondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if showsCost {
                    HomesteadTierCostLabel(cost: tier.cost, status: status)
                }
            }
            .padding(.vertical, 10)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    /// Node chrome with an outward attention ring. Opacity only — no shadow,
    /// scale, or compositing group (those clipped the bloom inward and made the
    /// soft edge bob vertically as opacity pulsed).
    private var tierNodeChrome: some View {
        PathNodeChrome(
            size: nodeSize,
            fill: nodeFill,
            stroke: nodeStroke,
            strokeWidth: nodeStrokeWidth
        ) {
            nodeGlyph
        }
        .frame(width: nodeSize, height: nodeSize)
        .background {
            if isActionable {
                Circle()
                    .strokeBorder(definition.tint.opacity(0.55), lineWidth: 2)
                    .frame(width: nodeSize + 12, height: nodeSize + 12)
                    .opacity(actionableHaloOpacity)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: glowPulse
                    )
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            // Fixed-size completion bloom; opacity only.
            Circle()
                .strokeBorder(definition.tint.opacity(0.7), lineWidth: 2)
                .frame(width: nodeSize + 8, height: nodeSize + 8)
                .opacity(completionGlowOpacity)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var nodeGlyph: some View {
        switch glyphKind {
        case .action:
            Image(systemName: actionSymbolName)
                // ~2× default `.title3` so the ready-to-act hammer reads clearly.
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(definition.tint)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(
                    .pulse,
                    options: .repeating.speed(0.7),
                    isActive: !reduceMotion
                )
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

    private var completionGlowOpacity: Double {
        isHighlighted && !reduceMotion ? 1 : 0
    }

    private var actionableHaloOpacity: Double {
        if reduceMotion {
            return 0.9
        }
        return glowPulse ? 1 : 0.35
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
                        .trinketTypography(.badge)
                        .monospacedDigit()
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

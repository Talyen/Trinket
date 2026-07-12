import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadNodeDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var build = HomesteadBuildControl()

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
        build.perform(definition, saveStore: appState.playerSave)
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
                TrinketHeroScrim.gradient(
                    for: .homesteadDetail,
                    startPoint: .init(x: 0.5, y: 0.42),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                Text(definition.title)
                    .trinketTypography(.screenDisplay)
                    .lineLimit(2)
                    .trinketOnArtText(.title)
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
    var isBuilding = false
    var onBuild: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(definition.tiers.enumerated()), id: \.element.tier) { index, tier in
                HomesteadTierNode(
                    definition: definition,
                    tier: tier,
                    state: status.tierPathState(for: tier),
                    status: status,
                    connectors: status.tierPathConnectors(for: index),
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
    let connectors: (before: PathConnectorState?, after: PathConnectorState?)
    var isBuilding = false
    var onBuild: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        "arrowshape.up.fill"
    }

    private var tierTitle: String {
        HomesteadTierCopy.title(for: tier.tier, nodeTitle: definition.title)
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
    }

    private var tierNodeAccessibilityID: String {
        AccessibilityID.Homestead.tierNode(title: definition.title, tier: tier.tier)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 14) {
            VerticalPathRail(
                minHeight: 72,
                connectorBefore: connectors.before,
                connectorAfter: connectors.after,
                style: connectorStyle
            ) {
                tierNodeChrome
            }
            .frame(width: PathNodeMetrics.railWidth)

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(tierTitle)
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

    private var tierNodeChrome: some View {
        PathNodeChrome(
            stroke: nodeStroke,
            emphasized: isActionable
        ) {
            nodeGlyph
        }
    }

    @ViewBuilder
    private var nodeGlyph: some View {
        let glyphFont = PathNodeMetrics.glyphFont(emphasized: isActionable)
        switch glyphKind {
        case .action:
            Image(systemName: actionSymbolName)
                .font(glyphFont)
                .foregroundStyle(definition.tint)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(
                    .bounce.up,
                    options: .repeating.speed(TrinketMotion.Homestead.purchaseCueSpeed),
                    isActive: isActionable && !reduceMotion
                )
        case .completed:
            Image(systemName: "checkmark")
                .font(glyphFont)
                .foregroundStyle(definition.tint)
        case .locked:
            Image(systemName: "lock.fill")
                .font(glyphFont)
                .foregroundStyle(.secondary)
        case .theme:
            Image(systemName: definition.symbolName)
                .font(glyphFont)
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

    private var nodeStroke: Color {
        switch state {
        case .completed: definition.tint.opacity(0.48)
        case let .next(affordable):
            affordable ? definition.tint : definition.tint.opacity(0.55)
        case .future, .locked: Color.secondary.opacity(0.2)
        }
    }

    private var accessibilityLabelText: String {
        var parts = [
            tierTitle,
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

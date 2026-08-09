import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadNodeDetailView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @State private var build = HomesteadBuildControl()

    let definition: HomesteadNodeDefinition

    private var homestead: PlayerHomesteadState {
        playerSave.homestead
    }

    private var roster: PlayerRosterState {
        playerSave.roster
    }

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster)
    }

    var body: some View {
        HomesteadHeroScreen(
            title: definition.title,
            homestead: homestead,
            roster: roster,
            bottomPadding: TrinketDesign.Metrics.extraLargeSpacing
        ) {
            HomesteadBuildingArtwork(definition: definition, variant: .full)
                .saturation(status.isUnlocked ? 1 : 0)
                .opacity(status.isUnlocked ? 1 : 0.66)
        } bodyContent: {
            HomesteadTierPath(
                definition: definition,
                status: status,
                isBuilding: build.isBuilding,
                onBuild: buildOrUpgrade
            )
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.nodeDetail(title: definition.title))
        .appFramePacingSignpost(
            AppFramePacingSignposts.Name.navigationPush,
            isActive: true
        )
        .onAppear {
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.navigationPush,
                detail: "homestead=\(definition.id)"
            )
        }
        .trinketSensoryFeedback(
            .success,
            trigger: build.upgradeEventCount,
            enabled: options.hapticsEnabled
        )
        .homesteadBuildErrorAlert(build: $build)
    }

    private func buildOrUpgrade() {
        build.perform(definition, saveStore: playerSave)
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

    private var tierTitle: String {
        HomesteadTierCopy.title(for: tier.tier, nodeTitle: definition.title)
    }

    private var connectorStyle: PathConnectorStyle {
        PathConnectorStyle(
            progressedColor: TrinketDesign.Colors.accent.opacity(0.7),
            completedColor: TrinketDesign.Colors.success.opacity(0.7),
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
                .trinketQuietTapButtonStyle()
                .disabled(isBuilding)

            } else {
                rowContent
            }
        }
        .accessibilityIdentifier(tierNodeAccessibilityID)
    }

    private var tierNodeAccessibilityID: String {
        AccessibilityID.Homestead.tierNode(title: definition.title, tier: tier.tier)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Metrics.snugSpacing) {
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
            .padding(.vertical, TrinketDesign.Metrics.sectionHeaderSpacing)

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
            Image(systemName: "arrowshape.up.fill")
                .font(glyphFont)
                .foregroundStyle(TrinketDesign.Colors.accent)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(
                    .bounce.up,
                    options: .repeating.speed(TrinketMotion.Homestead.purchaseCueSpeed),
                    isActive: isActionable
                )
        case .completed:
            Image(systemName: "checkmark")
                .font(glyphFont)
                .foregroundStyle(TrinketDesign.Colors.success)
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
        case .completed: .primary
        case let .next(affordable): affordable ? TrinketDesign.Colors.accent : .primary
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
        case .completed: TrinketDesign.Colors.success.opacity(0.48)
        case let .next(affordable):
            affordable ? TrinketDesign.Colors.accent : TrinketDesign.Colors.subtleStroke
        case .future, .locked: Color.secondary.opacity(0.2)
        }
    }
}

struct HomesteadTierCostLabel: View {
    let cost: [ResourceAmount]
    let status: HomesteadProjectStatus

    var body: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            ForEach(cost) { amount in
                HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    HomesteadResourceArtwork(resource: amount.resource)
                        .frame(
                            width: TrinketDesign.Metrics.walletResourceArtworkSize,
                            height: TrinketDesign.Metrics.walletResourceArtworkSize
                        )
                    Text("\(amount.quantity)")
                        .trinketTypography(.statValue)
                        .monospacedDigit()
                        .foregroundStyle(
                            status.hasEnough(amount)
                                ? Color.primary
                                : TrinketDesign.Colors.destructive
                        )
                }
            }
        }
    }
}

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                .animation(
                    reduceMotion ? nil : TrinketMotion.Homestead.nodeSettle,
                    value: status.isUnlocked
                )
        } bodyContent: {
            HomesteadTierPath(
                definition: definition,
                status: status,
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    var onBuild: (() -> Void)?

    @State private var sessionReveal: Set<Int>?
    @State private var fillingTier: Int?
    @State private var upperFill: CGFloat = 1
    @State private var lowerFill: CGFloat = 1
    @State private var settlingTier: Int?
    @State private var settleScale: CGFloat = 1

    private var revealedCompletedTiers: Set<Int> {
        sessionReveal ?? completedTiers(through: status.currentTier)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(definition.tiers.enumerated()), id: \.element.tier) { index, tier in
                HomesteadTierNode(
                    definition: definition,
                    tier: tier,
                    state: status.tierPathState(for: tier),
                    chromeState: chromeState(for: tier),
                    status: status,
                    connectors: connectors(for: index),
                    connectorBeforeFill: beforeFill(for: index),
                    connectorAfterFill: afterFill(for: index),
                    settleScale: settlingTier == tier.tier ? settleScale : 1,
                    onBuild: onBuild
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .accessibilityIdentifier(AccessibilityID.Homestead.tierPath)
        .onAppear {
            seedRevealIfNeeded(through: status.currentTier)
        }
        .onChange(of: status.currentTier) { oldValue, newValue in
            handleTierIncrease(from: oldValue, to: newValue)
        }
    }

    private func completedTiers(through tier: Int) -> Set<Int> {
        guard tier > 0 else { return [] }
        return Set(1 ... tier)
    }

    private func seedRevealIfNeeded(through tier: Int) {
        guard sessionReveal == nil else { return }
        sessionReveal = completedTiers(through: tier)
    }

    private func mutateReveal(_ body: (inout Set<Int>) -> Void) {
        var next = revealedCompletedTiers
        body(&next)
        sessionReveal = next
    }

    private func chromeState(for tier: HomesteadNodeTier) -> HomesteadTierPathState {
        if revealedCompletedTiers.contains(tier.tier) {
            return .completed
        }
        let live = status.tierPathState(for: tier)
        if case .completed = live {
            return .next(affordable: true)
        }
        return live
    }

    private func connectors(for index: Int) -> (before: PathConnectorState?, after: PathConnectorState?) {
        var pair = status.tierPathConnectors(for: index)
        if let fillingTier {
            let completingIndex = fillingTier - 1
            if index == completingIndex, pair.after != nil {
                pair.after = .future
            }
        }
        return pair
    }

    private func beforeFill(for index: Int) -> CGFloat? {
        guard fillingTier == definition.tiers[index].tier else { return nil }
        return lowerFill
    }

    private func afterFill(for index: Int) -> CGFloat? {
        guard let fillingTier, definition.tiers[index].tier == fillingTier - 1 else { return nil }
        return upperFill
    }

    private func handleTierIncrease(from oldValue: Int, to newValue: Int) {
        guard newValue > oldValue else { return }
        seedRevealIfNeeded(through: oldValue)

        if let fillingTier {
            mutateReveal { $0.insert(fillingTier) }
        }
        settlingTier = nil
        settleScale = 1

        if reduceMotion {
            mutateReveal { $0.formUnion(completedTiers(through: newValue)) }
            fillingTier = nil
            return
        }

        let completedTier = newValue
        fillingTier = completedTier
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            upperFill = 0
            lowerFill = 0
        }

        if completedTier == 1 {
            fillingTier = nil
            revealNode(completedTier, delay: 0)
            return
        }

        withAnimation(TrinketMotion.Homestead.connectorFill) {
            upperFill = 1
        }
        withAnimation(
            TrinketMotion.Homestead.connectorFill.delay(TrinketMotion.Homestead.connectorFillStagger)
        ) {
            lowerFill = 1
        }
        let completingTier = completedTier
        let fillCompleteDelay = TrinketMotion.Homestead.connectorFillDuration
            + TrinketMotion.Homestead.connectorFillStagger
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(fillCompleteDelay))
            guard fillingTier == completingTier else { return }
            fillingTier = nil
        }
        revealNode(completedTier, delay: TrinketMotion.Homestead.nodeSettleDelay)
    }

    private func revealNode(_ tier: Int, delay: TimeInterval) {
        withAnimation(TrinketMotion.Homestead.nodeSettle.delay(delay)) {
            mutateReveal { $0.insert(tier) }
            settlingTier = tier
            settleScale = TrinketMotion.Homestead.nodeSettlePeakScale
        }
        withAnimation(TrinketMotion.Homestead.nodeSettle.delay(delay + 0.08)) {
            settleScale = 1
        }
    }
}

struct HomesteadTierNode: View {
    let definition: HomesteadNodeDefinition
    let tier: HomesteadNodeTier
    let state: HomesteadTierPathState
    let chromeState: HomesteadTierPathState
    let status: HomesteadProjectStatus
    let connectors: (before: PathConnectorState?, after: PathConnectorState?)
    var connectorBeforeFill: CGFloat?
    var connectorAfterFill: CGFloat?
    var settleScale: CGFloat = 1
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
                style: connectorStyle,
                connectorBeforeFill: connectorBeforeFill,
                connectorAfterFill: connectorAfterFill
            ) {
                tierNodeChrome
                    .scaleEffect(settleScale)
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
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(
                    .bounce.up,
                    options: .repeating.speed(TrinketMotion.Homestead.purchaseCueSpeed),
                    isActive: isActionable
                )
        case .completed:
            Image(systemName: "checkmark")
                .font(glyphFont)
                .foregroundStyle(TrinketDesign.Colors.success)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: chromeState)
        case .locked:
            Image(systemName: "lock.fill")
                .font(glyphFont)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
        case .theme:
            Image(systemName: definition.symbolName)
                .font(glyphFont)
                .foregroundStyle(nodeForeground)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
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
        switch chromeState {
        case .completed: return .completed
        case .future, .locked: return .locked
        case .next: return .theme
        }
    }

    private var nodeForeground: Color {
        switch chromeState {
        case .completed: .primary
        case let .next(affordable): affordable ? TrinketDesign.Colors.accent : .primary
        case .future, .locked: .secondary
        }
    }

    private var nodeSecondaryForeground: Color {
        switch chromeState {
        case .completed, .next: .secondary
        case .future, .locked: Color.secondary.opacity(0.65)
        }
    }

    private var nodeStroke: Color {
        switch chromeState {
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

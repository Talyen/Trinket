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
            VStack(alignment: .leading, spacing: 18) {
                HomesteadResourceWallet(homestead: homestead, roster: roster)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                if !status.isUnlocked {
                    HomesteadPrerequisiteSection(definition: definition, homestead: homestead)
                }

                HomesteadTierPath(
                    definition: definition,
                    status: status,
                    highlightedTier: highlightedTier
                )
            }
            .padding(.top, 10)
            .padding(.bottom, TrinketDesign.Metrics.extraLargeSpacing)
        }
        .safeAreaInset(edge: .bottom) {
            HomesteadProjectActionFooter(
                status: status,
                isBuilding: build.isBuilding,
                onBuild: buildOrUpgrade
            )
            .trinketMaterial(.homesteadFooter)
            .overlay {
                TrinketDesign.cardShape
                    .stroke(HomesteadPalette.accent.opacity(0.42), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

struct HomesteadPrerequisiteSection: View {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text("Prerequisites")
                .trinketTypography(.sectionDisplay)

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(definition.prerequisites, id: \.nodeID) { requirement in
                    HStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                        Image(systemName: isMet(requirement) ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(isMet(requirement) ? TrinketDesign.Colors.success : .secondary)
                            .frame(width: 22)

                        Text(title(for: requirement.nodeID))
                            .trinketTypography(.secondaryBody)

                        Spacer(minLength: 0)

                        Text("Tier \(homestead.tier(for: requirement.nodeID))/\(requirement.minimumTier)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isMet(requirement) ? TrinketDesign.Colors.success : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(title(for: requirement.nodeID)), tier \(homestead.tier(for: requirement.nodeID)) of \(requirement.minimumTier)"
                    )
                }
            }
            .trinketSurface(.secondary)
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.prerequisiteCallout)
    }

    private func isMet(_ requirement: HomesteadNodeRequirement) -> Bool {
        homestead.tier(for: requirement.nodeID) >= requirement.minimumTier
    }

    private func title(for id: HomesteadNodeID) -> String {
        GameContent.homesteadNode(matching: id)?.title ?? id.rawValue
    }
}

struct HomesteadTierPath: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let highlightedTier: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text("Progression")
                .trinketTypography(.sectionDisplay)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(definition.tiers.enumerated()), id: \.element.tier) { index, tier in
                    HomesteadTierNode(
                        definition: definition,
                        tier: tier,
                        state: status.tierPathState(for: tier),
                        isHighlighted: highlightedTier == tier.tier
                    )

                    if index < definition.tiers.count - 1 {
                        Rectangle()
                            .fill(connectorColor(after: tier))
                            .frame(width: 2, height: 14)
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .accessibilityIdentifier(AccessibilityID.Homestead.tierPath)
        .animation(TrinketMotion.Homestead.tierCompletion, value: status.currentTier)
    }

    private func connectorColor(after tier: HomesteadNodeTier) -> Color {
        switch status.tierPathState(for: tier) {
        case .completed: return definition.tint.opacity(0.7)
        case .next, .future, .locked: return Color.secondary.opacity(0.28)
        }
    }
}

struct HomesteadTierNode: View {
    let definition: HomesteadNodeDefinition
    let tier: HomesteadNodeTier
    let state: HomesteadTierPathState
    let isHighlighted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(nodeFill)
                    Circle()
                        .strokeBorder(nodeStroke, lineWidth: nodeStrokeWidth)
                    Image(systemName: definition.symbolName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(nodeForeground)
                        .symbolRenderingMode(.hierarchical)
                }

                if showsLockBadge {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(.thickMaterial, in: Circle())
                }
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(tier.bonus.title)
                    .trinketTypography(.rowDisplay)
                    .foregroundStyle(nodeForeground)

                Text(tier.bonus.description)
                    .font(.caption)
                    .foregroundStyle(nodeSecondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .shadow(
            color: isHighlighted && !reduceMotion ? definition.tint.opacity(0.32) : .clear,
            radius: isHighlighted ? 12 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Tier \(tier.tier), \(tier.bonus.title), \(tier.bonus.description), \(accessibilityState)"
        )
        .accessibilityIdentifier(AccessibilityID.Homestead.tierNode(title: definition.title, tier: tier.tier))
    }

    private var showsLockBadge: Bool {
        switch state {
        case .completed, .next: return false
        case .future, .locked: return true
        }
    }

    private var nodeForeground: Color {
        switch state {
        case .completed: return definition.tint
        case let .next(affordable): return affordable ? definition.tint : .primary
        case .future, .locked: return .secondary
        }
    }

    private var nodeSecondaryForeground: Color {
        switch state {
        case .completed, .next: return .secondary
        case .future, .locked: return Color.secondary.opacity(0.65)
        }
    }

    private var nodeFill: Color {
        switch state {
        case .completed: return definition.tint.opacity(0.18)
        case let .next(affordable): return definition.tint.opacity(affordable ? 0.2 : 0.08)
        case .future, .locked: return Color.secondary.opacity(0.1)
        }
    }

    private var nodeStroke: Color {
        switch state {
        case .completed: return definition.tint.opacity(0.48)
        case let .next(affordable): return affordable ? definition.tint : definition.tint.opacity(0.65)
        case .future, .locked: return Color.secondary.opacity(0.2)
        }
    }

    private var nodeStrokeWidth: CGFloat {
        if case .next = state { return 1.5 }
        return 1
    }

    private var accessibilityState: String {
        switch state {
        case .completed: return "Completed"
        case let .next(affordable): return affordable ? "Next tier, affordable" : "Next tier, resources needed"
        case .future: return "Locked until earlier tiers are complete"
        case .locked: return "Locked by prerequisites"
        }
    }
}

struct HomesteadBuildingArtwork: View {
    enum Variant: Equatable {
        case full
        case thumbnail
    }

    let definition: HomesteadNodeDefinition
    var variant: Variant = .full

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 36

    var body: some View {
        ZStack {
            if let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] {
                HomesteadFocalArtwork(
                    art: art,
                    imageName: variant == .full ? art.imageName : "\(art.imageName)_thumb"
                )
                .accessibilityLabel(art.accessibilityLabel)
            } else {
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.small, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [definition.tint.opacity(0.18), Color(.secondarySystemBackground)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: definition.symbolName)
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(definition.tint)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.small, style: .continuous))
        .accessibilityLabel("\(definition.title) artwork")
    }
}

struct HomesteadFocalArtwork: View {
    let art: BackgroundArtReference
    var imageName: String?

    private let sourceAspectRatio: CGFloat = 1200.0 / 896.0

    init(art: BackgroundArtReference, imageName: String? = nil) {
        self.art = art
        self.imageName = imageName
    }

    var body: some View {
        GeometryReader { geometry in
            let container = geometry.size
            let scale = max(container.width / sourceAspectRatio, container.height)
            let renderedWidth = sourceAspectRatio * scale
            let renderedHeight = scale
            let overflowX = max(renderedWidth - container.width, 0)
            let overflowY = max(renderedHeight - container.height, 0)
            let offsetX = (0.5 - art.focalPoint.x) * overflowX
            let offsetY = (0.5 - art.focalPoint.y) * overflowY

            Image(imageName ?? art.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: container.width, height: container.height)
                .offset(x: offsetX, y: offsetY)
        }
        .clipped()
    }
}

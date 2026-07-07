import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadProjectCard: View {
    enum Style {
        case featured(onBuild: () -> Void)
        case compact(isRecentlyUpgraded: Bool)
    }

    private struct ProjectSummaryMetrics {
        let spacing: CGFloat
        let titleFont: Font
        let tierFont: Font
        let bonusFont: Font
        var titleForeground: Color = .primary
        var bonusLineLimit: Int?
        var showsFeaturedLabel = false
        var showsInlineStatusBadge = false

        static let featured = ProjectSummaryMetrics(
            spacing: 7,
            titleFont: .title2.weight(.bold),
            tierFont: .subheadline.monospacedDigit().weight(.semibold),
            bonusFont: .subheadline,
            showsFeaturedLabel: true
        )

        static func compact(isUnlocked: Bool) -> ProjectSummaryMetrics {
            ProjectSummaryMetrics(
                spacing: 6,
                titleFont: .headline,
                tierFont: .caption.monospacedDigit().weight(.semibold),
                bonusFont: .caption,
                titleForeground: isUnlocked ? .primary : .secondary,
                bonusLineLimit: 2,
                showsInlineStatusBadge: true
            )
        }
    }

    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    let style: Style

    var body: some View {
        switch style {
        case let .featured(onBuild):
            VStack(alignment: .leading, spacing: 14) {
                projectNavigationLink(isFeatured: true, isRecentlyUpgraded: false)
                HomesteadProjectActionFooter(status: status, onBuild: onBuild)
            }
            .padding(14)
            .trinketCardSurface()
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(definition.title) Featured Homestead Node")
        case let .compact(isRecentlyUpgraded):
            projectNavigationLink(isFeatured: false, isRecentlyUpgraded: isRecentlyUpgraded)
        }
    }

    private func projectNavigationLink(isFeatured: Bool, isRecentlyUpgraded: Bool) -> some View {
        NavigationLink {
            HomesteadNodeDetailView(definition: definition)
        } label: {
            if isFeatured {
                featuredLinkContent
            } else {
                compactLinkContent(isRecentlyUpgraded: isRecentlyUpgraded)
            }
        }
        // UIStyleCheck: allow - Art-forward project cards should navigate without button chrome.
        .buttonStyle(.plain)
    }

    private var featuredLinkContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomesteadBuildingArtwork(definition: definition)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .trinketLockedCardEffect(isLocked: !status.isUnlocked, text: status.isUnlocked ? nil : status.statusTitle)
                .overlay(alignment: .topLeading) {
                    HomesteadStatusBadge(status: status)
                        .padding(12)
                }

            projectSummary(.featured)
        }
        .contentShape(Rectangle())
    }

    private func compactLinkContent(isRecentlyUpgraded: Bool) -> some View {
        HStack(spacing: 12) {
            HomesteadBuildingArtwork(definition: definition)
                .frame(width: 78, height: 78)
                .trinketLockedCardEffect(isLocked: !status.isUnlocked, text: status.isUnlocked ? nil : status.statusTitle)

            projectSummary(.compact(isUnlocked: status.isUnlocked))

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .trinketSurface(.denseRow)
        .overlay {
            if isRecentlyUpgraded {
                TrinketDesign.cardShape
                    .stroke(TrinketDesign.Colors.success.opacity(0.72), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    private func projectSummary(_ metrics: ProjectSummaryMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.spacing) {
            if metrics.showsFeaturedLabel {
                Text(featuredTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            projectTitleRow(
                titleFont: metrics.titleFont,
                tierFont: metrics.tierFont,
                titleForeground: metrics.titleForeground
            )

            if let bonusLineLimit = metrics.bonusLineLimit {
                bonusDescription(font: metrics.bonusFont)
                    .lineLimit(bonusLineLimit)
            } else {
                bonusDescription(font: metrics.bonusFont)
            }

            tierPips

            if metrics.showsInlineStatusBadge {
                HomesteadStatusBadge(status: status)
            }
        }
    }

    private func projectTitleRow(
        titleFont: Font,
        tierFont: Font,
        titleForeground: Color = .primary
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(definition.title)
                .font(titleFont)
                .foregroundStyle(titleForeground)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text("Tier \(status.currentTier)/\(definition.maxTier)")
                .font(tierFont)
                .foregroundStyle(.secondary)
        }
    }

    private var tierPips: some View {
        HomesteadTierPips(
            currentTier: status.currentTier,
            maxTier: definition.maxTier,
            tint: definition.tint,
            isUnlocked: status.isUnlocked
        )
    }

    @ViewBuilder
    private func bonusDescription(font: Font) -> some View {
        if let bonus = status.nextBonus ?? definition.tier(status.currentTier)?.bonus {
            HomesteadBonusCopy(bonus: bonus, descriptionFont: font, showsTitle: false)
        }
    }

    private var featuredTitle: String {
        if !status.isUnlocked { return "Next Unlock" }
        if status.canBuildOrUpgrade || status.isComplete { return status.statusTitle }
        return "Gather Materials"
    }
}

struct HomesteadBonusCopy: View {
    let bonus: HomesteadBonus
    var titleFont: Font = .subheadline.weight(.semibold)
    var descriptionFont: Font = .subheadline
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text(bonus.title)
                    .font(titleFont)
            }
            Text(bonus.description)
                .font(descriptionFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HomesteadTierSummary: View {
    let currentTier: Int
    let maxTier: Int
    let tint: Color
    let isUnlocked: Bool
    var labelFont: Font = .subheadline.monospacedDigit().weight(.semibold)
    var labelColor: Color = .secondary

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HomesteadTierPips(
                currentTier: currentTier,
                maxTier: maxTier,
                tint: tint,
                isUnlocked: isUnlocked
            )

            Text("Tier \(currentTier)/\(maxTier)")
                .font(labelFont)
                .foregroundStyle(labelColor)
        }
    }
}

struct HomesteadProjectActionFooter: View {
    let status: HomesteadProjectStatus
    var isBuilding: Bool = false
    var buildButtonAccessibilityID: String?
    let onBuild: (() -> Void)?

    var body: some View {
        if status.canBuildOrUpgrade, let onBuild {
            buildButton(action: onBuild)
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

    @ViewBuilder
    private func buildButton(action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Label(status.actionTitle, systemImage: "hammer.fill")
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton()
        .disabled(isBuilding)

        if let buildButtonAccessibilityID {
            button.accessibilityIdentifier(buildButtonAccessibilityID)
        } else {
            button
        }
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
                    HomesteadProjectCard(
                        definition: definition,
                        status: HomesteadProjectStatus(
                            definition: definition,
                            homestead: homestead,
                            roster: roster
                        ),
                        style: .compact(isRecentlyUpgraded: recentUpgradeID == definition.id)
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
    }
}

struct HomesteadStatusBadge: View {
    let status: HomesteadProjectStatus

    var body: some View {
        Group {
            if status.isUnlocked {
                Label(status.statusTitle, systemImage: status.statusSymbolName)
            } else {
                Text(status.statusTitle)
            }
        }
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
        .trinketSurface(.secondary)
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

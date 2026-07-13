import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

private enum HomesteadProjectRowMetrics {
    /// 4:3 project art beside title + effect; height sits with two caption lines.
    static let artworkAspectRatio: CGFloat = 4.0 / 3.0
    static let artworkHeight: CGFloat = 92
    static var artworkWidth: CGFloat {
        artworkHeight * artworkAspectRatio
    }

    static let artworkTextSpacing: CGFloat = 12
    static var dividerLeadingInset: CGFloat {
        artworkWidth + artworkTextSpacing
    }
}

struct HomesteadProjectRow: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus

    private var isLocked: Bool {
        if case .prerequisiteLocked = status.rowState {
            return true
        }
        return false
    }

    private var showsInlineNavigationChevron: Bool {
        status.statusSymbolName == "chevron.right"
    }

    var body: some View {
        Group {
            if isLocked {
                rowContent
            } else {
                NavigationLink(value: definition) {
                    rowContent
                }
                .buttonStyle(.plain)
                .trinketNavigationRowButtonStyle()
            }
        }

        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: HomesteadProjectRowMetrics.artworkTextSpacing) {
            HomesteadBuildingArtwork(definition: definition, variant: .thumbnail)
                .frame(
                    width: HomesteadProjectRowMetrics.artworkWidth,
                    height: HomesteadProjectRowMetrics.artworkHeight
                )
                .saturation(isLocked ? 0.42 : 1)
                .opacity(isLocked ? 0.72 : 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(definition.title)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(isLocked ? .secondary : .primary)
                        .lineLimit(2)

                    if showsInlineNavigationChevron {
                        Image(systemName: "chevron.right")
                            .font(statusAffordanceFont)
                            .foregroundStyle(status.statusColor)
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                Text(effectLine)
                    .trinketTypography(.caption)
                    .foregroundStyle(isLocked ? .tertiary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if !showsInlineNavigationChevron {
                Image(systemName: status.statusSymbolName)
                    .font(statusAffordanceFont)
                    .foregroundStyle(status.statusColor)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(
                        .bounce.up,
                        options: .repeating.speed(TrinketMotion.Homestead.purchaseCueSpeed),
                        isActive: status.canBuildOrUpgrade
                    )
                    .frame(width: statusAffordanceSize, height: statusAffordanceSize)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusAffordanceFont: Font {
        .body.weight(.semibold)
    }

    private var statusAffordanceSize: CGFloat {
        22
    }

    private var effectLine: String {
        guard let effect = status.overviewEffect else { return definition.summary }
        return effect.description
    }
}

struct HomesteadProjectSection: View {
    let category: HomesteadNodeCategory
    let definitions: [HomesteadNodeDefinition]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            Text(category.rawValue)
                .trinketTypography(.sectionTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .accessibilityIdentifier(AccessibilityID.Homestead.category(category.rawValue))

            LazyVStack(spacing: 0) {
                ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                    HomesteadProjectRow(
                        definition: definition,
                        status: HomesteadProjectStatus(
                            definition: definition,
                            homestead: homestead,
                            roster: roster
                        )
                    )

                    if index < definitions.count - 1 {
                        Rectangle()
                            .fill(TrinketDesign.Colors.subtleStroke.opacity(0.55))
                            .frame(height: 0.5)
                            .padding(.leading, HomesteadProjectRowMetrics.dividerLeadingInset)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
    }
}

struct HomesteadBonusCopy: View {
    let bonus: HomesteadBonus
    var titleRole: TypographyRole = .badge
    var descriptionRole: TypographyRole = .secondaryBody
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            if showsTitle {
                Text(bonus.title)
                    .trinketTypography(titleRole)
            }
            Text(bonus.description)
                .trinketTypography(descriptionRole)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HomesteadRequirementCountText: View {
    let balance: Int
    let required: Int
    let role: TypographyRole

    var body: some View {
        if balance >= required {
            Text("\(balance)/\(required)")
                .trinketTypography(role)
                .foregroundStyle(TrinketDesign.Colors.success)
                .contentTransition(.numericText())
        } else {
            HStack(spacing: 0) {
                Text("\(balance)")
                    .foregroundStyle(TrinketDesign.Colors.destructive)
                Text("/\(required)")
                    .foregroundStyle(.secondary)
            }
            .trinketTypography(role)
            .contentTransition(.numericText())
        }
    }
}

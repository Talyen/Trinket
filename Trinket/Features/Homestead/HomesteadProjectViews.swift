import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

private enum HomesteadProjectRowMetrics {
    static let artworkAspectRatio: CGFloat = 4.0 / 3.0
    static let artworkHeight: CGFloat = 92
    static var artworkWidth: CGFloat {
        artworkHeight * artworkAspectRatio
    }

    static let artworkTextSpacing = TrinketDesign.Spacing.medium
    static var dividerLeadingInset: CGFloat {
        artworkWidth + artworkTextSpacing
    }
}

struct HomesteadProjectRow: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    var zoomNamespace: Namespace.ID

    private var isLocked: Bool {
        if case .prerequisiteLocked = status.rowState {
            return true
        }
        return false
    }

    private var showsNavigationChevron: Bool {
        status.statusSymbolName == "chevron.right"
    }

    var body: some View {
        NavigationLink(value: HomesteadRoute.node(definition.id)) {
            rowContent
                .matchedTransitionSource(id: definition.id, in: zoomNamespace)
        }
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 0) {
            HomesteadBuildingArtwork(definition: definition, variant: .thumbnail)
                .frame(
                    width: HomesteadProjectRowMetrics.artworkWidth,
                    height: HomesteadProjectRowMetrics.artworkHeight,
                )
                .saturation(isLocked ? 0.42 : 1)
                .opacity(isLocked ? 0.72 : 1)
                .padding(.trailing, HomesteadProjectRowMetrics.artworkTextSpacing)

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                Text(balanced: definition.title)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .trinketFittedText()

                Text(balanced: effectLine)
                    .trinketTypography(.caption)
                    .foregroundStyle(isLocked ? .tertiary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsNavigationChevron {
                Image(systemName: "chevron.right")
                    .trinketTypography(.footnote)
                    .foregroundStyle(status.statusColor)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                    .padding(.leading, TrinketDesign.Spacing.tight)
            } else {
                Image(systemName: status.statusSymbolName)
                    .trinketTypography(.button)
                    .foregroundStyle(status.statusColor)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                    .symbolEffect(
                        .bounce.up,
                        value: status.canBuildOrUpgrade,
                    )
                    .frame(width: 22, height: 22)
                    .padding(.leading, TrinketDesign.Spacing.tight)
            }
        }
        .padding(.vertical, TrinketDesign.Spacing.small)
    }

    private var effectLine: String {
        status.overviewCaption
    }
}

struct HomesteadProjectSection: View {
    let category: HomesteadNodeCategory
    let definitions: [HomesteadNodeDefinition]
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    var zoomNamespace: Namespace.ID
    var showsCategoryHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
            if showsCategoryHeader {
                Text(category.rawValue)
                    .trinketTypography(.sectionTitle)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                    .accessibilityIdentifier(AccessibilityID.Homestead.category(category.rawValue))
            }

            VStack(spacing: 0) {
                ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                    HomesteadProjectRow(
                        definition: definition,
                        status: HomesteadProjectStatus(
                            definition: definition,
                            homestead: homestead,
                            roster: roster,
                        ),
                        zoomNamespace: zoomNamespace,
                    )

                    if index < definitions.count - 1 {
                        Rectangle()
                            .fill(TrinketDesign.Colors.subtleStroke.opacity(0.55))
                            .frame(height: 0.5)
                            .padding(.leading, HomesteadProjectRowMetrics.dividerLeadingInset)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        }
    }
}

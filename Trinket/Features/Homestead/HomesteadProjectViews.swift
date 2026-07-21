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

    static let artworkTextSpacing = TrinketDesign.Metrics.mediumSpacing
    static var dividerLeadingInset: CGFloat {
        artworkWidth + artworkTextSpacing
    }
}

struct HomesteadProjectRow: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    var zoomNamespace: Namespace.ID?

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
        // Locked rows stay tappable so players can inspect prerequisites and the tier path.
        NavigationLink(value: definition) {
            rowContent
                .optionalHomesteadZoomSource(id: definition.id, in: zoomNamespace)
        }
        .trinketQuietTapButtonStyle()
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

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                Text(definition.title)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)

                Text(effectLine)
                    .trinketTypography(.caption)
                    .foregroundStyle(isLocked ? .tertiary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if showsNavigationChevron {
                Image(systemName: "chevron.right")
                    .trinketTypography(.footnote)
                    .foregroundStyle(status.statusColor)
                    .symbolRenderingMode(.hierarchical)
            } else {
                Image(systemName: status.statusSymbolName)
                    .trinketTypography(.button)
                    .foregroundStyle(status.statusColor)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(
                        .bounce.up,
                        options: .repeating.speed(TrinketMotion.Homestead.purchaseCueSpeed),
                        isActive: status.canBuildOrUpgrade
                    )
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.vertical, TrinketDesign.Metrics.denseSpacing)
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
    var zoomNamespace: Namespace.ID?
    /// When false, only the project rows render (category title lives on the hero).
    var showsCategoryHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            if showsCategoryHeader {
                Text(category.rawValue)
                    .trinketTypography(.sectionTitle)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .accessibilityIdentifier(AccessibilityID.Homestead.category(category.rawValue))
            }

            LazyVStack(spacing: 0) {
                ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                    HomesteadProjectRow(
                        definition: definition,
                        status: HomesteadProjectStatus(
                            definition: definition,
                            homestead: homestead,
                            roster: roster
                        ),
                        zoomNamespace: zoomNamespace
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

private extension View {
    @ViewBuilder
    func optionalHomesteadZoomSource<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

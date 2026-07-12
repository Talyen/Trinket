import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadProjectRow: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus

    private var isLocked: Bool {
        if case .prerequisiteLocked = status.rowState {
            return true
        }
        return false
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title), \(status.statusTitle). \(effectLine)")
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 10) {
            HomesteadBuildingArtwork(definition: definition, variant: .thumbnail)
                .frame(width: 118, height: 58)
                .saturation(isLocked ? 0.42 : 1)
                .opacity(isLocked ? 0.72 : 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(definition.title)
                    .trinketTypography(.rowDisplay)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)

                Text(effectLine)
                    .trinketTypography(.caption)
                    .foregroundStyle(isLocked ? .tertiary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: status.statusSymbolName)
                .font(statusAffordanceFont)
                .foregroundStyle(status.statusColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: statusAffordanceSize, height: statusAffordanceSize)
                .accessibilityLabel(status.statusTitle)
        }
        .padding(.vertical, 4)
    }

    /// Ready-to-act hammers read at 2× the compact chevron/lock affordance.
    private var showsActionHammer: Bool {
        switch status.rowState {
        case .upgradeReady, .unbuilt(affordable: true): true
        default: false
        }
    }

    private var statusAffordanceFont: Font {
        showsActionHammer ? .system(size: 34, weight: .semibold) : .body.weight(.semibold)
    }

    private var statusAffordanceSize: CGFloat {
        showsActionHammer ? 44 : 22
    }

    private var effectLine: String {
        guard let effect = status.overviewEffect else { return definition.summary }
        return "\(effect.title): \(effect.description)"
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
                .accessibilityAddTraits(.isHeader)
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
                            .fill(HomesteadPalette.accent.opacity(0.18))
                            .frame(height: 0.5)
                            .padding(.leading, 128)
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

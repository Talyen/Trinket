import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadProjectRow: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus

    private var isLocked: Bool {
        if case .prerequisiteLocked = status.rowState { return true }
        return false
    }

    var body: some View {
        NavigationLink(value: definition) {
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
                        .font(.caption)
                        .foregroundStyle(isLocked ? .tertiary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: status.statusSymbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(status.statusColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 22, height: 22)
                    .accessibilityLabel(status.statusTitle)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .trinketNavigationRowButtonStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.title), \(status.statusTitle). \(effectLine)")
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
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
        VStack(alignment: .leading, spacing: 6) {
            Text(category.rawValue)
                .trinketTypography(.sectionDisplay)
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

struct HomesteadProjectActionFooter: View {
    let status: HomesteadProjectStatus
    var isBuilding = false
    let onBuild: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    costContent
                    actionContent
                }
            } else {
                HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                    costContent

                    Divider()
                        .frame(height: 34)

                    actionContent
                }
            }
        }
        .padding(8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.actionFooter)
        .animation(TrinketMotion.Homestead.tierCompletion, value: status.currentTier)
    }

    @ViewBuilder
    private var costContent: some View {
        if let nextTier = status.nextTier {
            HomesteadFooterCostGrid(cost: nextTier.cost, status: status)
        } else {
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var actionContent: some View {
        switch status.footerState {
        case let .action(title, enabled, reason):
            Button(action: onBuild) {
                Label(title, systemImage: title == "Build" ? "hammer.fill" : "arrow.up.circle.fill")
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
            }
            .trinketHomesteadActionButton()
            .disabled(!enabled || isBuilding)
            .accessibilityIdentifier(status.detailBuildButtonAccessibilityID)
            .accessibilityValue(reason ?? "Ready")
            .accessibilityHint(reason.map { "Unavailable. \($0)." } ?? "Double-tap to \(title.lowercased()) this project.")
        case .complete:
            Label("Complete", systemImage: "checkmark.seal.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(HomesteadPalette.success)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
                .padding(.vertical, 10)
                .accessibilityLabel("Complete")
                .accessibilityValue("This project is at its maximum tier.")
        }
    }
}

struct HomesteadFooterCostGrid: View {
    let cost: [ResourceAmount]
    let status: HomesteadProjectStatus

    var body: some View {
        HStack(spacing: 10) {
            ForEach(cost) { amount in
                let balance = status.balance(for: amount)
                HStack(spacing: 4) {
                    HomesteadResourceArtwork(resource: amount.resource)
                        .frame(width: 22, height: 22)
                    Text("\(amount.quantity)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(status.hasEnough(amount) ? .primary : TrinketDesign.Colors.destructive)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(AccessibilityID.Homestead.footerCost(resource: amount.resource.rawValue))
                .accessibilityLabel(
                    "\(amount.resource.displayName), \(balance) available of \(amount.quantity) required"
                )
            }
        }
    }
}

struct HomesteadBonusCopy: View {
    let bonus: HomesteadBonus
    var titleFont: Font = .subheadline.weight(.semibold)
    var descriptionFont: Font = .subheadline
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
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

struct HomesteadRequirementCountText: View {
    let balance: Int
    let required: Int
    let font: Font

    var body: some View {
        if balance >= required {
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

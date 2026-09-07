import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

private enum HomesteadSheetDestination: Hashable {
    case history
}

struct HomesteadDetailSheetView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss
    @State private var expanded = false
    @State private var path: [HomesteadSheetDestination] = []
    @State private var detent: PresentationDetent = .large

    let definition: HomesteadNodeDefinition
    let kind: HomesteadDetailSheet
    @Binding var build: HomesteadBuildControl
    let purchaseCommitted: Bool
    var onPurchase: (Int) -> Void

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: playerSave.homestead, roster: playerSave.roster)
    }

    private var offeredTier: HomesteadNodeTier? {
        guard case let .improvement(tier) = kind else { return nil }
        return definition.tier(tier)
    }

    private var compactDetent: PresentationDetent {
        .height(purchaseCommitted || (status.isUnlocked && status.isAffordable) ? 340 : 440)
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { closeControl }
                .navigationDestination(for: HomesteadSheetDestination.self) { _ in
                    HomesteadTierHistory(definition: definition, currentTier: status.currentTier)
                        .toolbar { closeControl }
                }
        }
        .presentationDetents(kind.isImprovement ? [compactDetent, .height(540), .large] : [.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(TrinketDesign.Colors.surface)
        .homesteadBuildErrorAlert(build: $build)
        .onAppear { detent = kind.isImprovement ? compactDetent : .medium }
        .onChange(of: expanded) { _, _ in updateDetent() }
        .onChange(of: path) { _, _ in updateDetent() }
    }

    @ToolbarContentBuilder
    private var closeControl: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { dismiss() } label: {
                Label("Close", systemImage: "xmark")
            }
            .accessibilityIdentifier(AccessibilityID.Homestead.closeSheetButton)
        }
    }

    @ViewBuilder
    private var root: some View {
        switch kind {
        case .improvement:
            if let tier = offeredTier {
                improvement(tier)
            }
        case .benefits:
            currentBenefits
        case .wallet:
            ScrollView {
                HomesteadResourceWallet(homestead: playerSave.homestead, roster: playerSave.roster)
                    .padding(TrinketDesign.Layout.contentMargin)
            }
            .navigationTitle("Resources")
        }
    }

    private func improvement(_ tier: HomesteadNodeTier) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                Text(tier.stageName)
                    .trinketTypography(.sectionDisplay)
                    .foregroundStyle(.primary)
                Button {
                    withAnimation(TrinketMotion.Interaction.stateChange) { expanded.toggle() }
                } label: {
                    HStack {
                        KeywordDescriptionText(text: tier.bonus.title)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: TrinketDesign.Spacing.small)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .accessibilityHidden(true)
                    }
                    .trinketTypography(.body)
                    .foregroundStyle(.primary)
                    .padding(.vertical, TrinketDesign.Spacing.small)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityIdentifier(AccessibilityID.Homestead.effectDisclosure)

                if expanded {
                    HomesteadEffectDescription(tier: tier, previousTier: definition.tier(tier.tier - 1))
                    historyLink
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.bottom, TrinketDesign.Spacing.medium)
        }
        .safeAreaInset(edge: .bottom) { purchaseControls(tier) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.upgradeSheet)
    }

    private func purchaseControls(_ tier: HomesteadNodeTier) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            if !status.missingPrerequisites.isEmpty {
                ForEach(status.missingPrerequisites, id: \.nodeID) { requirement in
                    if let project = GameContent.homesteadNode(matching: requirement.nodeID) {
                        Text("Requires \(project.title), Tier \(requirement.minimumTier)")
                            .trinketTypography(.secondaryBody)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if !status.materialShortfalls.isEmpty {
                Text("More materials needed")
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading) {
                ForEach(tier.cost) { amount in
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                        HomesteadMaterialChip(
                            resource: amount.resource,
                            value: amount.quantity.formatted(),
                            isShort: !status.hasEnough(amount),
                        )
                        if !status.hasEnough(amount) {
                            Text("Have \(status.balance(for: amount))")
                                .trinketTypography(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button { onPurchase(tier.tier) } label: {
                Text(tier.tier == 1 ? "Build" : "Upgrade")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!status.canBuildOrUpgrade || status.nextTier?.tier != tier.tier || purchaseCommitted)
            .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.upgradeButton)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .background(TrinketDesign.Colors.surface)
    }

    private var currentBenefits: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                if let tier = status.currentStage {
                    Text(tier.stageName)
                        .trinketTypography(.sectionDisplay)
                        .accessibilityIdentifier(AccessibilityID.Homestead.tierNode(title: definition.title, tier: tier.tier))
                    HomesteadEffectDescription(tier: tier)
                } else {
                    KeywordDescriptionText(text: definition.summary)
                        .trinketTypography(.body)
                }
                historyLink
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .navigationTitle(definition.title)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.benefitsSheet)
    }

    private var historyLink: some View {
        NavigationLink(value: HomesteadSheetDestination.history) {
            HStack {
                Text("All tiers")
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }
            .trinketTypography(.body)
            .foregroundStyle(.primary)
            .padding(.vertical, TrinketDesign.Spacing.small)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Homestead.allTiersButton)
    }

    private func updateDetent() {
        withAnimation(TrinketMotion.Interaction.stateChange) {
            if !path.isEmpty {
                detent = .large
            } else if kind.isImprovement {
                detent = expanded ? .height(540) : compactDetent
            } else {
                detent = .medium
            }
        }
    }
}

private struct HomesteadTierHistory: View {
    let definition: HomesteadNodeDefinition
    let currentTier: Int

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraLarge) {
                ForEach(definition.tiers, id: \.tier) { tier in
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(tier.stageName)
                                .trinketTypography(.sectionDisplay)
                            Spacer()
                            Text("\(tier.tier)")
                                .trinketTypography(.statValue)
                        }
                        .foregroundStyle(tier.tier == currentTier ? TrinketDesign.Colors.accent : .primary)
                        HomesteadEffectDescription(tier: tier)
                    }
                    .accessibilityIdentifier(AccessibilityID.Homestead.tierNode(title: definition.title, tier: tier.tier))
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .navigationTitle("All tiers")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.tierHistory)
    }
}

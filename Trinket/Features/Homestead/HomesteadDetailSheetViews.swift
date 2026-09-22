import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadDetailSheetView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

    @State private var benefitsHeight: CGFloat = 0
    @State private var controlsHeight: CGFloat = 0

    let definition: HomesteadNodeDefinition
    let kind: HomesteadDetailSheet
    @Binding var build: HomesteadBuildControl
    let purchaseCommitted: Bool
    var onPurchase: (Int) -> Void

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: playerSave.homestead, roster: playerSave.roster)
    }

    var body: some View {
        // Chrome lives with each sheet kind: improvement configures its own
        // measured detents + surface below, while HomesteadWalletSheet owns
        // its fixed detents and chrome internally. A single trigger is not
        // possible: the detail flow presents wallet through its purchase
        // orchestration sheet, while the gallery presents it standalone.
        root
            .trinketFailureAlert("Build Failed", message: $build.error)
    }

    @MainActor
    @ViewBuilder
    private var root: some View {
        switch kind {
        case let .improvement(number):
            if let tier = definition.tier(number) {
                improvement(tier)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(TrinketDesign.Colors.surface)
                    .interactiveDismissDisabled(build.isPending || purchaseCommitted)
            }
        case .wallet:
            HomesteadWalletSheet()
        }
    }

    private func improvement(_ tier: HomesteadNodeTier) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
                Text("\(tier.tier == 1 ? "Build" : "Upgrade") \(definition.title)")
                    .trinketTypography(.sectionDisplay)
                HomesteadBenefitsView(
                    nodeID: definition.id,
                    tier: tier,
                    effectsIdentifier: AccessibilityID.Homestead.upgradeEffects,
                    previousTier: status.currentStage,
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.top, TrinketDesign.Spacing.extraLarge)
            .padding(.bottom, TrinketDesign.Spacing.small)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { benefitsHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            purchaseControls(tier)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlsHeight = $0 }
        }
        .presentationDetents(benefitsHeight > 0 && controlsHeight > 0
            ? [.height(benefitsHeight + controlsHeight), .large]
            : [.medium, .large])
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.upgradeSheet)
    }

    private func purchaseControls(_ tier: HomesteadNodeTier) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            Text(tier.tier == 1 ? "Build cost" : "Upgrade cost")
                .trinketTypography(.cardTitle)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading) {
                ForEach(tier.cost) { amount in
                    HomesteadMaterialValue(
                        resource: amount.resource,
                        value: amount.quantity.formatted(),
                        isInsufficient: !status.hasEnough(amount),
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Homestead.upgradeCost)

            ForEach(status.missingPrerequisites, id: \.nodeID) { requirement in
                if let project = GameContent.homesteadNode(matching: requirement.nodeID) {
                    Text("Requires \(project.title), \(project.tier(requirement.minimumTier)?.stageName ?? project.title)")
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button { onPurchase(tier.tier) } label: {
                Text(build.isPending ? "Finishing…" : (tier.tier == 1 ? "Build" : "Upgrade"))
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.upgradeButton)
            .disabled(!status.canBuildOrUpgrade || status.nextTier?.tier != tier.tier || purchaseCommitted || build.isPending)
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .background(TrinketDesign.Colors.surface)
    }
}

struct HomesteadWalletSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

    var onClose: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                HomesteadResourceWallet(homestead: playerSave.homestead, roster: playerSave.roster)
                    .padding(TrinketDesign.Layout.contentMargin)
            }
            .navigationTitle("Resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    } label: { Label("Close", systemImage: "xmark") }
                        .accessibilityIdentifier(AccessibilityID.Homestead.closeSheetButton)
                }
            }
        }
        .presentationDetents([.height(260), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(TrinketDesign.Colors.surface)
    }
}

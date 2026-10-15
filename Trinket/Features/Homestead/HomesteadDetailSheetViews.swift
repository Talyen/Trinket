import SwiftUI
import TrinketContent
import TrinketDesignSystem
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
        HomesteadProjectStatus(definition: definition, homestead: playerSave.homestead, gold: playerSave.roster.gold)
    }

    var body: some View {
        // Chrome lives with each sheet kind: improvement configures its own
        // measured detents + surface below, while HomesteadWalletSheet owns
        // its fixed detents and chrome internally. A single trigger is not
        // possible: the detail flow presents wallet through its purchase
        // orchestration sheet, while the gallery presents it standalone.
        root
    }

    @MainActor
    @ViewBuilder
    private var root: some View {
        switch kind {
        case let .improvement(number):
            if let tier = definition.tier(number) {
                improvement(tier)
                    .presentationDragIndicator(.visible)
                    .trinketSheetSurface()
                    .interactiveDismissDisabled(build.isPending || purchaseCommitted)
            }
        case .wallet:
            HomesteadWalletSheet()
        case .crafting:
            BlacksmithForgeView()
        }
    }

    private func improvement(_ tier: HomesteadNodeTier) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
                GameLabel(tier
                    .tier == 1 ? String(localized: L10n.ui_homesteaddetailsheetviews_build_1_08716("\(definition.title)")) : definition
                    .title)
                    .trinketTypography(.sectionDisplay)
                if tier.tier == 1 {
                    HomesteadBenefitsView(
                        nodeID: definition.id,
                        tier: tier,
                        effectsIdentifier: AccessibilityID.Homestead.upgradeEffects,
                    )
                }
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
            Text(tier
                .tier == 1 ? String(localized: L10n.ui_homesteaddetailsheetviews_build_cost_98758) :
                String(localized: L10n.ui_homesteaddetailsheetviews_upgrade_cost_359f4))
                .trinketTypography(.cardTitle)
                .trinketFittedText()

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

            Button { onPurchase(tier.tier) } label: {
                HStack {
                    if build.isPending {
                        ProgressView()
                    }
                    Text(tier
                        .tier == 1 ? String(localized: L10n.ui_homesteaddetailsheetviews_build_bdd25) :
                        String(localized: L10n.ui_homesteaddetailsheetviews_upgrade_7ec02))
                }
                .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.upgradeButton)
            .disabled(!status.canBuildOrUpgrade || status.nextTier?.tier != tier.tier || purchaseCommitted || build.isPending)
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .background(TrinketDesign.Colors.sheet)
    }
}

struct HomesteadWalletSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

    var onClose: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                HomesteadResourceWallet(homestead: playerSave.homestead, gold: playerSave.roster.gold)
                    .padding(TrinketDesign.Layout.contentMargin)
            }
            .navigationTitle(Text(L10n.ui_homesteaddetailsheetviews_resources_e89b3))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    } label: { Label(String(localized: L10n.ui_homesteaddetailsheetviews_close_7d9eb), systemImage: "xmark") }
                        .accessibilityIdentifier(AccessibilityID.Homestead.closeSheetButton)
                }
            }
        }
        .presentationDetents([.height(260), .large])
        .presentationDragIndicator(.visible)
        .trinketSheetSurface()
    }
}

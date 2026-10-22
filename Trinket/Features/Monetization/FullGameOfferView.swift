import StoreKit
import SwiftUI
import TrinketAppState
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct FullGameOfferView: View {
    @Environment(\.locale) private var locale
    @Environment(FullGameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let artwork: FullGameOfferArtwork?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                offerHeading
                    .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                    .padding(.top, TrinketDesign.Spacing.extraLarge)
                    .padding(.bottom, TrinketDesign.Spacing.extraLarge * 2)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .bottom)
                    .background(alignment: .top) {
                        artwork
                            .frame(height: geometry.size.height * 0.72)
                            .trinketBottomArtworkBlend(fadeFraction: 0.12)
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .trinketScreenBackground()
        .ignoresSafeArea(edges: .top)
        .trinketSoftTopScrollEdge(isHidden: true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { purchaseArea }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.FullGame.offer)
        .task { await store.loadProduct() }
        .onChange(of: store.ownership) { _, ownership in
            if ownership.access.hasFullGame {
                dismiss()
            }
        }
    }

    private var offerHeading: some View {
        VStack(spacing: TrinketDesign.Spacing.medium) {
            VStack(spacing: TrinketDesign.Spacing.small) {
                Text(L10n.ui_fullgameofferview_full_game_497de)
                    .trinketTypography(.eyebrow)
                    .tracking(3)
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .trinketSingleLineFittedText()
                Text(L10n.ui_fullgameofferview_keep_exploring_2c443)
                    .trinketTypography(.offerDisplay)
                    .foregroundStyle(TrinketDesign.Colors.offerTitle)
                    .trinketSingleLineFittedText()
                    .accessibilityIdentifier(AccessibilityID.FullGame.hero)
            }
            Text(L10n.ui_fullgameofferview_all_content_yours_forever)
                .trinketTypography(.body)
                .foregroundStyle(.primary)
                .trinketSingleLineFittedText()
        }
    }

    private var purchaseArea: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            if store.ownership.access.hasFullGame {
                Button { dismiss() } label: {
                    Text(L10n.ui_fullgameofferview_full_game_purchased_51dc5)
                        .padding(.vertical, TrinketDesign.Spacing.extraSmall)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
            } else if let product = store.product {
                ProductView(product)
                    .productViewStyle(FullGameProductStyle(isPurchasing: store.isPurchasing, locale: locale))
                    .disabled(store.isRestoring || store.ownership == .checking)
                    .onInAppPurchaseStart { _ in store.purchaseStarted() }
                    .onInAppPurchaseCompletion { _, result in await store.purchaseCompleted(result) }
            } else if store.isLoading {
                ProgressView()
                    .trinketTypography(.body)
                    .frame(maxWidth: .infinity)
            } else {
                Button { Task { await store.loadProduct() } } label: {
                    Text(L10n.ui_fullgameofferview_retry_94208)
                        .padding(.vertical, TrinketDesign.Spacing.extraSmall)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.FullGame.retry)
            }

            FullGameOutcomeMessage(outcome: store.outcome)
            purchaseSupport
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .trinketScreenBackground()
    }

    private var purchaseSupport: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TrinketDesign.Spacing.small) {
                    restoreButton
                    Text("·").accessibilityHidden(true)
                    privacyLink
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(spacing: TrinketDesign.Spacing.small) {
                    restoreButton
                    privacyLink
                }
            }
            Label(String(localized: L10n.ui_fullgameofferview_family_sharing_ba974), systemImage: "person.2")
                .trinketSingleLineFittedText()
        }
        .trinketTypography(.caption)
        .foregroundStyle(.secondary)
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restore() }
        } label: {
            HStack {
                if store.isRestoring {
                    ProgressView()
                }
                Text(L10n.ui_fullgameofferview_restore_purchases_16351)
                    .trinketSingleLineFittedText()
            }
            .frame(minHeight: footerControlMinHeight)
            .contentShape(.rect)
        }
        .disabled(store.isRestoring || store.isPurchasing)
        .accessibilityIdentifier(AccessibilityID.FullGame.restore)
    }

    private var privacyLink: some View {
        Link(destination: TrinketPublicPages.privacy) {
            Text(L10n.ui_fullgameofferview_privacy_54a57)
                .trinketSingleLineFittedText()
                .frame(minWidth: footerControlMinHeight, minHeight: footerControlMinHeight)
                .contentShape(.rect)
        }
        .accessibilityIdentifier(AccessibilityID.FullGame.privacy)
    }

    private var footerControlMinHeight: CGFloat? {
        if #available(iOS 26.0, *) {
            return nil
        }
        return 44
    }
}

private struct FullGameProductStyle: ProductViewStyle {
    let isPurchasing: Bool
    let locale: Locale

    func makeBody(configuration: Configuration) -> some View {
        if let product = configuration.product {
            Button {
                configuration.purchase()
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                    }
                    Text(verbatim: LocalizedGameText(
                        L10n.ui_fullgameofferview_unlock_full_game_1_b6d50(product.displayPrice),
                        locale: locale,
                    ).text)
                        .trinketTypography(.button)
                        .trinketSingleLineFittedText()
                }
                .padding(.vertical, TrinketDesign.Spacing.extraSmall)
                .frame(maxWidth: .infinity)
            }
            .disabled(isPurchasing || !AppStore.canMakePayments)
            .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.FullGame.purchase)
        }
    }
}

enum TrinketPublicPages {
    static let privacy = URL(string: "https://talyen.github.io/Trinket/privacy.html")!
    static let support = URL(string: "https://talyen.github.io/Trinket/")!
}

struct FullGameOutcomeMessage: View {
    let outcome: FullGameStore.Outcome?

    var body: some View {
        if let outcome {
            Text(message(for: outcome))
                .accessibilityIdentifier(AccessibilityID.FullGame.outcome)
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func message(for outcome: FullGameStore.Outcome) -> String {
        switch outcome {
        case .pricingUnavailable:
            String(localized: L10n.ui_fullgameofferview_pricing_is_unavailable_try_again_cf1d2)
        case .pendingApproval:
            String(localized: L10n.ui_fullgameofferview_waiting_for_approval_full_game_will_unlock_wh_6334b)
        case .restoreFailed:
            String(localized: L10n.ui_fullgameofferview_couldn_t_restore_purchases_please_try_again_7c988)
        case .noPurchaseFound:
            String(localized: L10n.ui_fullgameofferview_no_full_game_purchase_was_found_for_your_appl_bdc23)
        case .purchaseUnverified:
            String(localized: L10n.ui_fullgameofferview_couldn_t_verify_full_game_ownership_please_tr_87254)
        }
    }
}

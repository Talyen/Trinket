import StoreKit
import SwiftUI
import TrinketAppState
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct FullGameOfferView: View {
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(FullGameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .title2) private var benefitIconSize: CGFloat = 24

    @ScaledMetric(relativeTo: .largeTitle) private var minimumHeroHeight: CGFloat = 220

    private let contentWidth: CGFloat = 520
    let artwork: FullGameOfferArtwork?

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView {
                    FullGameOfferContentLayout(
                        viewportHeight: geometry.size.height,
                        minimumHeroHeight: minimumHeroHeight,
                    ) {
                        GeometryReader { hero in
                            DetailHeroHeader(
                                eyebrow: String(localized: L10n.ui_fullgameofferview_full_game_497de),
                                title: String(localized: L10n.ui_fullgameofferview_keep_exploring_2c443),
                                titleAccessibilityIdentifier: AccessibilityID.FullGame.hero,
                                baseHeight: hero.size.height,
                                horizontalPadding: max(0, (hero.size.width - contentWidth) / 2) + TrinketDesign.Layout.contentMargin,
                                titleScale: 40.0 / 34,
                                eyebrowScale: 15.0 / 12,
                            ) {
                                artwork
                            }
                        }
                        benefits(roomy: geometry.size.width >= 390)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .clipped()
            }
            purchaseArea
        }
        .trinketScreenBackground()
        .ignoresSafeArea(edges: .top)
        .trinketSoftTopScrollEdge(isHidden: true)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.FullGame.offer)
        .task { await store.loadProduct() }
        .onChange(of: store.ownership) { _, ownership in
            if ownership.access.hasFullGame {
                dismiss()
            }
        }
    }

    private func benefits(roomy: Bool) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            benefit(Text(L10n.ui_fullgameofferview_all_chapters_modes_bbd59), icon: .system("map.fill"), roomy: roomy)
            benefit(Text(L10n.ui_fullgameofferview_every_hero_companion_4d884), icon: .system("person.2.fill"), roomy: roomy)
            benefit(Text(L10n.ui_fullgameofferview_includes_all_future_content_7311b), icon: .system("sparkles"), roomy: roomy)
        }
        .padding(TrinketDesign.Layout.contentMargin)
        .frame(maxWidth: contentWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private func benefit(_ title: Text, icon: GameIcon, roomy: Bool) -> some View {
        HStack(spacing: TrinketDesign.Spacing.medium) {
            GameIconImage(icon)
                .trinketTypography(.sectionTitle, scale: roomy ? 26.0 / 22 : 24.0 / 22)
                .imageScale(.small)
                .foregroundStyle(TrinketDesign.Colors.accent)
                .frame(width: benefitIconSize * (roomy ? 26.0 / 24 : 1), height: benefitIconSize * (roomy ? 26.0 / 24 : 1))
                .accessibilityHidden(true)
            title
                .trinketTypography(.sectionTitle, scale: roomy ? 26.0 / 22 : 24.0 / 22)
                .fontWeight(.regular)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var purchaseArea: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            if store.ownership.access.hasFullGame {
                Button(String(localized: L10n.ui_fullgameofferview_full_game_purchased_51dc5)) { dismiss() }
                    .frame(maxWidth: .infinity)
                    .trinketPrimaryActionButton()
            } else if let product = store.product {
                ProductView(product)
                    .productViewStyle(FullGameProductStyle(
                        isPurchasing: store.isPurchasing,
                        locale: locale,
                        beginPurchase: store.purchaseStarted,
                    ))
                    .disabled(store.isRestoring || store.ownership == .checking)
                    .onInAppPurchaseCompletion { _, result in await store.purchaseCompleted(result) }
            } else if store.isLoading {
                ProgressView()
                    .trinketTypography(.body)
                    .frame(maxWidth: .infinity)
            } else {
                Button(String(localized: L10n.ui_fullgameofferview_retry_94208)) { Task { await store.loadProduct() } }
                    .frame(maxWidth: .infinity)
                    .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.FullGame.retry)
            }

            FullGameOutcomeMessage(outcome: store.outcome)
            purchaseSupport
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .frame(maxWidth: contentWidth)
        .frame(maxWidth: .infinity)
        .trinketScreenBackground()
    }

    private var purchaseSupport: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            FullGameSupportLayout(layoutDirection: layoutDirection) {
                restoreButton
                privacyLink
            }
            Label(String(localized: L10n.ui_fullgameofferview_family_sharing_ba974), systemImage: "person.2")
                .trinketTypography(.secondaryBody)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                    .trinketTypography(.secondaryBody)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .disabled(store.isRestoring || store.isPurchasing)
        .accessibilityIdentifier(AccessibilityID.FullGame.restore)
    }

    private var privacyLink: some View {
        Link(destination: TrinketPublicPages.privacy) {
            Text(L10n.ui_fullgameofferview_privacy_54a57)
                .trinketTypography(.secondaryBody)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityIdentifier(AccessibilityID.FullGame.privacy)
    }
}

private struct FullGameSupportLayout: Layout {
    let layoutDirection: LayoutDirection

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = sizes.reduce(0) { $0 + $1.width } + TrinketDesign.Spacing.medium
        let width = proposal.width ?? rowWidth
        if rowWidth <= width {
            return CGSize(width: rowWidth, height: sizes.map(\.height).max() ?? 0)
        }
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: heights.reduce(0, +) + TrinketDesign.Spacing.small)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = sizes.reduce(0) { $0 + $1.width } + TrinketDesign.Spacing.medium
        if rowWidth <= bounds.width {
            var x = bounds.midX - rowWidth / 2
            let indices = layoutDirection == .rightToLeft ? Array(subviews.indices.reversed()) : Array(subviews.indices)
            for index in indices {
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.midY),
                    anchor: .leading,
                    proposal: ProposedViewSize(sizes[index]),
                )
                x += sizes[index].width + TrinketDesign.Spacing.medium
            }
        } else {
            var y = bounds.minY
            for subview in subviews {
                let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subview.place(
                    at: CGPoint(x: bounds.midX, y: y),
                    anchor: .top,
                    proposal: ProposedViewSize(width: bounds.width, height: size.height),
                )
                y += size.height + TrinketDesign.Spacing.small
            }
        }
    }
}

private struct FullGameOfferContentLayout: Layout {
    let viewportHeight: CGFloat
    let minimumHeroHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let benefits = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: max(viewportHeight, minimumHeroHeight + benefits.height))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let benefits = subviews[1].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        let heroHeight = bounds.height - benefits.height
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: heroHeight))
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + heroHeight),
            proposal: ProposedViewSize(width: bounds.width, height: benefits.height),
        )
    }
}

private struct FullGameProductStyle: ProductViewStyle {
    let isPurchasing: Bool
    let locale: Locale
    let beginPurchase: () -> Bool

    func makeBody(configuration: Configuration) -> some View {
        if let product = configuration.product {
            Button {
                guard beginPurchase() else { return }
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
                        .trinketTypography(.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        case .purchaseFailed:
            String(localized: L10n.ui_fullgameofferview_purchase_failed)
        case .purchaseUnverified:
            String(localized: L10n.ui_fullgameofferview_couldn_t_verify_full_game_ownership_please_tr_87254)
        }
    }
}

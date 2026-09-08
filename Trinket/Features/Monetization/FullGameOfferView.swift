import StoreKit
import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

struct FullGameOfferView: View {
    @Environment(FullGameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let artworkName: String?

    var body: some View {
        DetailHeroScrollShell(title: "Full Game", heroHeightPolicy: .square) { height in
            DetailHeroHeader(
                eyebrow: "FULL GAME",
                title: "Keep Exploring",
                titleAccessibilityIdentifier: AccessibilityID.FullGame.hero,
                baseHeight: height,
            ) {
                if let artworkName {
                    Image.preparedAsset(named: artworkName)
                        .resizable()
                        .scaledToFill()
                        .decorativePreparedArtwork()
                }
            } footer: {
                EmptyView()
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                benefit("All Chapters and Game Modes", symbol: "map")
                benefit("Every Hero and Companion", symbol: "person.2")
                benefit("All future content included", symbol: "sparkles")
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { purchaseArea }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier(AccessibilityID.FullGame.close)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.FullGame.offer)
        .task { await store.loadProduct() }
        .onChange(of: store.ownership) { _, ownership in
            if ownership.access.hasFullGame {
                dismiss()
            }
        }
    }

    private func benefit(_ title: String, symbol: String) -> some View {
        Label {
            Text(title)
                .trinketTypography(.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .trinketTypography(.sectionTitle)
                .foregroundStyle(TrinketDesign.Colors.accent)
                .frame(width: TrinketDesign.Spacing.extraLarge)
                .accessibilityHidden(true)
        }
    }

    private var purchaseArea: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            if store.ownership.access.hasFullGame {
                Button("Full Game Purchased") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .trinketPrimaryActionButton()
            } else if let product = store.product {
                ProductView(product)
                    .productViewStyle(FullGameProductStyle(isPurchasing: store.isPurchasing))
                    .disabled(store.isRestoring || store.ownership == .checking)
                    .onInAppPurchaseStart { _ in store.purchaseStarted() }
                    .onInAppPurchaseCompletion { _, result in await store.purchaseCompleted(result) }
            } else if store.isLoading {
                ProgressView("Loading purchase…")
                    .trinketTypography(.body)
                    .frame(maxWidth: .infinity)
            } else {
                Button("Retry") { Task { await store.loadProduct() } }
                    .frame(maxWidth: .infinity)
                    .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.FullGame.retry)
            }

            if !AppStore.canMakePayments {
                Text("Purchases are disabled on this device.")
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = store.message {
                Text(message)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.FullGame.status)
            }

            HStack(spacing: TrinketDesign.Spacing.small) {
                Button(store.isRestoring ? "Restoring…" : "Restore Purchases") {
                    Task { await store.restore() }
                }
                .disabled(store.isRestoring || store.isPurchasing)
                .accessibilityIdentifier(AccessibilityID.FullGame.restore)
                Text("·")
                Link("Privacy", destination: TrinketPublicPages.privacy)
                    .accessibilityIdentifier(AccessibilityID.FullGame.privacy)
            }
            .trinketTypography(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, TrinketDesign.Spacing.small)

            Label("Family Sharing", systemImage: "person.2")
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .trinketScreenBackground()
    }
}

private struct FullGameProductStyle: ProductViewStyle {
    let isPurchasing: Bool

    func makeBody(configuration: Configuration) -> some View {
        if let product = configuration.product {
            Button {
                configuration.purchase()
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                    }
                    Text("Purchase \(product.displayPrice)")
                        .trinketTypography(.button)
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

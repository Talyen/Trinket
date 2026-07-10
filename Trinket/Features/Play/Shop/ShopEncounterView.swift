import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct ShopEncounterView: View {
    @Environment(AppState.self) private var appState
    @Bindable var session: ShopEncounterSession

    @State private var selectedOffer: ShopOffer?
    @State private var artAppeared = false
    @State private var contentAppeared = false
    @State private var offersAppeared = false
    @State private var purchaseFeedbackTrigger = 0
    @State private var purchaseErrorFeedbackTrigger = 0

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var reduceMotion: Bool {
        accessibilityReduceMotion
    }

    private let columns = TrinketDesign.Metrics.collectionGridItems

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                    merchantArtwork
                        .opacity(artAppeared ? 1 : 0)
                        .scaleEffect(artAppeared ? 1 : (reduceMotion ? 1 : 0.94))

                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                        Text(session.stage.encounterSubjectName)
                            .font(.title.bold())
                            .accessibilityIdentifier(AccessibilityID.Shop.encounterTitle)

                        Text(session.greeting)
                            .trinketTypography(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(AccessibilityID.Shop.encounterGreeting)

                        if let purchasedName = session.lastPurchasedItemName {
                            Text("Purchased \(purchasedName)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Keyword.gold.visualStyle.color)
                                .accessibilityIdentifier(AccessibilityID.Shop.purchaseConfirmation)
                                .transition(.opacity)
                        }

                        if let errorMessage = session.lastPurchaseError {
                            Text(errorMessage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier(AccessibilityID.Shop.purchaseError)
                                .transition(.opacity)
                        }
                    }
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared || reduceMotion ? 0 : 8)

                    offerGrid
                        .opacity(offersAppeared ? 1 : 0)
                        .offset(y: offersAppeared || reduceMotion ? 0 : 10)

                    Button {
                        appState.finishActiveShopEncounter()
                    } label: {
                        Text("Leave Shop")
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .tint(TrinketDesign.Colors.encounterShop)
                    .accessibilityIdentifier(AccessibilityID.Shop.leaveButton)
                    .padding(.top, 4)
                }
                .padding(TrinketDesign.Metrics.extraLargeSpacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketScreenBackground(.modal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    goldWallet
                        .accessibilityIdentifier(AccessibilityID.Shop.goldBalance)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .interactiveDismissDisabled()
        .sheet(item: $selectedOffer) { offer in
            NavigationStack {
                ItemDetailView(
                    item: offer.item,
                    purchasePrice: offer.price,
                    canAfford: appState.roster.gold >= offer.price,
                    isPurchaseDisabled: session.isPurchasing || session.isSoldOut(offer.id),
                    purchaseButtonTitleOverride: session.isSoldOut(offer.id) ? "Sold Out" : nil,
                    onPurchase: {
                        attemptPurchase(offerID: offer.id, dismissDetail: true)
                    }
                )
            }
            .trinketDetailSheet()
        }
        .onAppear {
            presentEntrance()
        }
        .trinketSensoryFeedback(
            .success,
            trigger: purchaseFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
        .trinketSensoryFeedback(
            .error,
            trigger: purchaseErrorFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private var merchantArtwork: some View {
        EncounterArtwork(stage: session.stage)
            .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
            .frame(maxWidth: .infinity)
            .accessibilityLabel(session.stage.encounterSubjectName)
            .accessibilityIdentifier(AccessibilityID.Shop.encounterArt)
    }

    private var goldWallet: some View {
        HStack(spacing: 6) {
            Image(systemName: Keyword.gold.visualStyle.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Keyword.gold.visualStyle.color)

            Text("\(appState.roster.gold)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
        }
        .trinketWalletPill()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gold, \(appState.roster.gold)")
    }

    private var offerGrid: some View {
        LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.largeSpacing) {
            ForEach(session.offers) { offer in
                let soldOut = session.isSoldOut(offer.id)
                let canAfford = appState.roster.gold >= offer.price
                let canBuy = canAfford && !soldOut
                VStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    Button {
                        selectedOffer = offer
                    } label: {
                        ItemCard(
                            item: offer.item,
                            showsAffixCount: false,
                            showsName: false,
                            appliesCardSurface: false
                        )
                    }
                    // UIStyleCheck: allow - Offer card opens item detail without button chrome.
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Shop.offerCard(offerID: offer.id))
                    .accessibilityHint("Shows item details")

                    Button {
                        attemptPurchase(offerID: offer.id, dismissDetail: false)
                    } label: {
                        buyButtonLabel(offer: offer, soldOut: soldOut, canBuy: canBuy)
                    }
                    // UIStyleCheck: allow - Compact price chip buy control without full primary chrome.
                    .buttonStyle(.plain)
                    .disabled(!canBuy || session.isPurchasing)
                    .accessibilityIdentifier(AccessibilityID.Shop.buyButton(offerID: offer.id))
                    .accessibilityLabel(
                        soldOut
                            ? "\(offer.item.displayName) sold out"
                            : "Buy \(offer.item.displayName) for \(offer.price) gold"
                    )
                }
                .opacity(soldOut ? 0.55 : (canAfford ? 1 : 0.72))
            }
        }
    }

    private func buyButtonLabel(offer: ShopOffer, soldOut: Bool, canBuy: Bool) -> some View {
        HStack(spacing: 5) {
            if soldOut {
                Text("Sold")
            } else {
                Text("Buy")
                Image(systemName: Keyword.gold.visualStyle.symbolName)
                Text("\(offer.price)")
                    .monospacedDigit()
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(canBuy ? Keyword.gold.visualStyle.color : .secondary)
        .trinketGlassChip(.emphasis)
    }

    private func attemptPurchase(offerID: String, dismissDetail: Bool) {
        if appState.purchaseActiveShopOffer(offerID: offerID) {
            purchaseFeedbackTrigger += 1
            if dismissDetail {
                selectedOffer = nil
            }
        } else {
            purchaseErrorFeedbackTrigger += 1
        }
    }

    private func presentEntrance() {
        guard !reduceMotion else {
            artAppeared = true
            contentAppeared = true
            offersAppeared = true
            return
        }
        withAnimation(.easeOut(duration: 0.35)) {
            artAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.08)) {
            contentAppeared = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.16)) {
            offersAppeared = true
        }
    }
}

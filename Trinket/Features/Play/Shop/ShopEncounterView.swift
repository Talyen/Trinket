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

    private let columns = TrinketDesign.Metrics.collectionGridItems

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                    merchantArtwork
                        .opacity(artAppeared ? 1 : 0)
                        .scaleEffect(artAppeared ? 1 : 0.94)

                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                        Text(session.stage.encounterSubjectName)
                            .trinketTypography(.screenTitle)
                            .accessibilityIdentifier(AccessibilityID.Shop.encounterTitle)

                        Text(session.greeting)
                            .trinketTypography(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(AccessibilityID.Shop.encounterGreeting)

                        if let errorMessage = session.lastPurchaseError {
                            Text(errorMessage)
                                .trinketTypography(.badge)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier(AccessibilityID.Shop.purchaseError)
                                .transition(.opacity)
                        }

                        if let leaveFailure = session.leaveFailureMessage {
                            Text(leaveFailure)
                                .trinketTypography(.badge)
                                .foregroundStyle(TrinketDesign.Colors.warning)
                                .accessibilityIdentifier(AccessibilityID.Shop.leaveFailure)
                                .transition(.opacity)
                        }
                    }
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 8)

                    offerGrid
                        .opacity(offersAppeared ? 1 : 0)
                        .offset(y: offersAppeared ? 0 : 10)

                    Button {
                        appState.finishActiveShopEncounter()
                    } label: {
                        Text("Leave Shop")
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .tint(TrinketDesign.Colors.encounterShop)
                    .accessibilityIdentifier(AccessibilityID.Shop.leaveButton)
                    .padding(.top, TrinketDesign.Metrics.extraSmallSpacing)
                }
                .padding(TrinketDesign.Metrics.extraLargeSpacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketScreenBackground()
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
            .trinketArtworkBlend(.perimeter(into: .canvas))
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier(AccessibilityID.Shop.encounterArt)
    }

    private var goldWallet: some View {
        HStack(spacing: TrinketDesign.Metrics.denseSpacing) {
            Image(systemName: Keyword.gold.visualStyle.symbolName)
                .trinketTypography(.badge)
                .foregroundStyle(Keyword.gold.visualStyle.color)

            Text("\(appState.roster.gold)")
                .trinketTypography(.statValue)
                .contentTransition(.numericText())
        }
        .trinketWalletPill()
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
                            appliesCardSurface: false,
                            artworkBlend: .perimeter(into: .canvas)
                        )
                    }
                    // UIStyleCheck: allow - Offer card opens item detail without button chrome.
                    .trinketQuietTapButtonStyle()
                    .accessibilityIdentifier(AccessibilityID.Shop.offerCard(offerID: offer.id))

                    Button {
                        attemptPurchase(offerID: offer.id, dismissDetail: false)
                    } label: {
                        buyButtonLabel(offer: offer, soldOut: soldOut, canBuy: canBuy)
                    }
                    // UIStyleCheck: allow - Compact price chip buy control without full primary chrome.
                    .trinketQuietTapButtonStyle()
                    .disabled(!canBuy || session.isPurchasing)
                    .accessibilityIdentifier(AccessibilityID.Shop.buyButton(offerID: offer.id))
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
        .trinketTypography(.button)
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

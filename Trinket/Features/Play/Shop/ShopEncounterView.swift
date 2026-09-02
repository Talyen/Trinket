import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct ShopEncounterView: View {
    @Environment(EncounterPlayMode.self) private var encounters
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @Bindable var session: ShopEncounterSession
    let onLeave: () -> Bool

    @State private var selectedOffer: ShopOffer?
    @State private var artAppeared = false
    @State private var contentAppeared = false
    @State private var offersAppeared = false
    @State private var purchaseFeedbackTrigger = 0
    @State private var purchaseErrorFeedbackTrigger = 0
    @State private var leaveErrorTrigger = 0

    private let columns = TrinketDesign.Layout.collectionGridItems

    var body: some View {
        NavigationStack {
            EncounterReadingShell(
                artVisible: artAppeared,
                copyVisible: contentAppeared,
                artwork: { merchantArtwork },
                copy: {
                    VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
                        Text(session.stage.encounterSubjectName(worldSeed: playerSave.worldSeed))
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

                        if let persistFailure = session.persistFailureMessage {
                            Text(persistFailure)
                                .trinketTypography(.badge)
                                .foregroundStyle(TrinketDesign.Colors.warning)
                                .accessibilityIdentifier(AccessibilityID.Shop.leaveFailure)
                                .transition(.opacity)
                        }
                    }
                },
                content: {
                    offerGrid
                        .opacity(offersAppeared ? 1 : 0)
                        .offset(y: offersAppeared ? 0 : 10)

                    Button {
                        if !onLeave() {
                            leaveErrorTrigger &+= 1
                        }
                    } label: {
                        Text("Leave Shop")
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .trinketCenteredPrimaryAction()
                    .tint(TrinketDesign.Colors.encounterShop)
                    .accessibilityIdentifier(AccessibilityID.Shop.leaveButton)
                    .padding(.top, TrinketDesign.Spacing.extraSmall)
                },
            )
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
                    canAfford: playerSave.roster.gold >= offer.price,
                    isPurchaseDisabled: session.isPurchasing || session.isSoldOut(offer.id),
                    purchaseButtonTitleOverride: session.isSoldOut(offer.id) ? "Sold Out" : nil,
                    onPurchase: {
                        attemptPurchase(offerID: offer.id, dismissDetail: true)
                    },
                )
            }
            .trinketDetailSheet()
        }
        .onAppear {
            EncounterReadingEntrance.present(
                artAppeared: $artAppeared,
                copyAppeared: $contentAppeared,
                trailingAppeared: $offersAppeared,
            )
        }
        .trinketSensoryFeedback(
            .success,
            trigger: purchaseFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .error,
            trigger: purchaseErrorFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .error,
            trigger: leaveErrorTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private var merchantArtwork: some View {
        EncounterArtwork(stage: session.stage)
            .aspectRatio(session.stage.encounter.artAspectRatio, contentMode: .fit)
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier(AccessibilityID.Shop.encounterArt)
    }

    private var goldWallet: some View {
        TrinketCompactResourceChip(
            amount: playerSave.roster.gold,
            tint: HomesteadResource.gold.tint,
            animationTrigger: purchaseFeedbackTrigger,
        ) {
            HomesteadResourceArtwork(resource: .gold)
        }
    }

    private var offerGrid: some View {
        LazyVGrid(columns: columns, spacing: TrinketDesign.Spacing.large) {
            ForEach(session.offers) { offer in
                let soldOut = session.isSoldOut(offer.id)
                let canAfford = playerSave.roster.gold >= offer.price
                let canBuy = canAfford && !soldOut
                VStack(spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
                    EncounterItemTile(
                        item: offer.item,
                        showsName: false,
                        accessibilityID: AccessibilityID.Shop.offerCard(offerID: offer.id),
                        onSelect: { selectedOffer = offer },
                    )

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
                .saturation(soldOut ? 0.55 : 1)
                .animation(TrinketMotion.Interaction.stateChange, value: soldOut)
            }
        }
    }

    private func buyButtonLabel(offer: ShopOffer, soldOut: Bool, canBuy: Bool) -> some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            if soldOut {
                Text("Sold")
            } else {
                Text("Buy")
                HomesteadResourceArtwork(resource: .gold)
                    .frame(
                        width: TrinketDesign.Metrics.compactResourceArtworkSize * 0.8,
                        height: TrinketDesign.Metrics.compactResourceArtworkSize * 0.8,
                    )
                Text("\(offer.price)")
                    .monospacedDigit()
            }
        }
        .trinketTypography(.button)
        .foregroundStyle(canBuy ? Keyword.gold.visualStyle.color : .secondary)
        .trinketGlassChip(.emphasis)
        .contentTransition(.opacity)
        .animation(TrinketMotion.Interaction.stateChange, value: soldOut)
    }

    private func attemptPurchase(offerID: String, dismissDetail: Bool) {
        if encounters.purchaseActiveShopOffer(offerID: offerID) {
            purchaseFeedbackTrigger += 1
            if dismissDetail {
                selectedOffer = nil
            }
        } else {
            purchaseErrorFeedbackTrigger += 1
        }
    }
}

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var session: ShopEncounterSession
    let onLeave: () -> Void

    @State private var selectedOffer: ShopOffer?
    @State private var artAppeared = false
    @State private var contentAppeared = false
    @State private var offersAppeared = false
    @State private var purchaseFeedbackTrigger = 0
    @State private var purchaseErrorFeedbackTrigger = 0

    private let columns = TrinketDesign.Metrics.collectionGridItems

    var body: some View {
        NavigationStack {
            EncounterReadingShell(
                artVisible: artAppeared,
                copyVisible: contentAppeared,
                artwork: { merchantArtwork },
                copy: {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
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

                        if let leaveFailure = session.leaveFailureMessage {
                            Text(leaveFailure)
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
                        onLeave()
                    } label: {
                        Text("Leave Shop")
                            .frame(maxWidth: .infinity)
                    }
                    .trinketPrimaryActionButton()
                    .trinketCenteredPrimaryAction()
                    .tint(TrinketDesign.Colors.encounterShop)
                    .accessibilityIdentifier(AccessibilityID.Shop.leaveButton)
                    .padding(.top, TrinketDesign.Metrics.extraSmallSpacing)
                }
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
                    }
                )
            }
            .trinketDetailSheet()
        }
        .onAppear {
            EncounterReadingEntrance.present(
                artAppeared: $artAppeared,
                copyAppeared: $contentAppeared,
                trailingAppeared: $offersAppeared
            )
        }
        .trinketSensoryFeedback(
            .success,
            trigger: purchaseFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
        .trinketSensoryFeedback(
            .error,
            trigger: purchaseErrorFeedbackTrigger,
            enabled: options.hapticsEnabled
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
        HStack(spacing: TrinketDesign.Metrics.denseSpacing) {
            Image(systemName: Keyword.gold.visualStyle.symbolName)
                .trinketTypography(.badge)
                .foregroundStyle(Keyword.gold.visualStyle.color)
                .keyframeAnimator(
                    initialValue: CGFloat(1),
                    trigger: reduceMotion ? 0 : purchaseFeedbackTrigger
                ) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.08, duration: 0.08)
                    SpringKeyframe(1, duration: 0.18, spring: .smooth)
                }

            Text("\(playerSave.roster.gold)")
                .trinketTypography(.statValue)
                .monospacedDigit()
                .frame(minWidth: 36, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .trinketWalletPill()
        .animation(TrinketMotion.Interaction.stateChange, value: playerSave.roster.gold)
    }

    private var offerGrid: some View {
        LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.largeSpacing) {
            ForEach(session.offers) { offer in
                let soldOut = session.isSoldOut(offer.id)
                let canAfford = playerSave.roster.gold >= offer.price
                let canBuy = canAfford && !soldOut
                VStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
                    EncounterItemTile(
                        item: offer.item,
                        showsName: false,
                        accessibilityID: AccessibilityID.Shop.offerCard(offerID: offer.id),
                        onSelect: { selectedOffer = offer }
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
        HStack(spacing: TrinketDesign.Metrics.denseSpacing) {
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

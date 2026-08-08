import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var collectionNamespace
    @State private var collection = HomesteadCollectionControl()
    @State private var depositEvent: HomesteadDepositEvent?
    @State private var isDepositLifted = false
    @State private var isCollectButtonDismissing = false

    private var homestead: PlayerHomesteadState {
        playerSave.homestead
    }

    private var roster: PlayerRosterState {
        playerSave.roster
    }

    var body: some View {
        HomesteadHeroScreen(
            title: "Homestead",
            homestead: homestead,
            roster: roster,
            walletAnimationNamespace: collectionNamespace
        ) {
            if let art = ArtCatalog.backgroundArtByID["homestead"]
                ?? ArtCatalog.backgroundArtByID["wheatField"] {
                HomesteadFocalArtwork(art: art)
            } else {
                TrinketDesign.Colors.surface
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                collectionSection

                LazyVGrid(
                    columns: TrinketDesign.Metrics.hubGridItems(for: horizontalSizeClass),
                    spacing: TrinketDesign.Metrics.largeSpacing
                ) {
                    ForEach(HomesteadNodeCategory.allCases) { category in
                        categoryCard(category)
                    }
                }
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            }
        }
        .navigationDestination(for: HomesteadNodeCategory.self) { category in
            HomesteadCategoryView(category: category)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
        .homesteadCollectionErrorAlert(collection: $collection)
    }

    private var collectionSection: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let pending = homestead.pendingProductionAmounts(at: context.date, roster: roster)
            Group {
                if !pending.isEmpty {
                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            collection.perform(saveStore: playerSave, at: context.date) { amounts in
                                showDeposit(amounts)
                            }
                        } label: {
                            collectButtonLabel(pending: pending)
                        }
                        .disabled(collection.isCollecting || playerSave.isCloudSyncEnabled)
                        .trinketPrimaryActionButton(
                            accessibilityIdentifier: AccessibilityID.Homestead.collectButton
                        )
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    if isCollectButtonDismissing, let depositEvent {
                        HStack {
                            Spacer(minLength: 0)
                            Button(action: {}, label: {
                                collectButtonLabel(pending: depositEvent.amounts, matchesWallet: false)
                            })
                            .disabled(true)
                            .trinketPrimaryActionButton()
                            .scaleEffect(isDepositLifted ? 0.96 : 1)
                            .opacity(isDepositLifted ? 0 : 1)
                            .animation(TrinketMotion.Homestead.tierCompletion, value: isDepositLifted)
                            .allowsHitTesting(false)
                            Spacer(minLength: 0)
                        }
                    }

                    if let depositEvent {
                        HStack {
                            Spacer(minLength: 0)
                            depositFlight(for: depositEvent)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private func collectButtonLabel(
        pending: [ResourceAmount],
        matchesWallet: Bool = true
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: TrinketDesign.Metrics.snugSpacing) {
                collectLabel
                collectAmounts(pending, matchesWallet: matchesWallet)
            }

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                collectLabel
                collectAmountsGrid(pending, matchesWallet: matchesWallet)
            }
        }
    }

    private var collectLabel: some View {
        Label {
            Text("Collect")
        } icon: {
            Image(systemName: "gift.fill")
                .imageScale(.large)
        }
        .trinketTypography(.button)
    }

    private func collectAmounts(
        _ amounts: [ResourceAmount],
        matchesWallet: Bool
    ) -> some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            if playerSave.isCloudSyncEnabled {
                Text("Unavailable with cloud sync")
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(amounts) { amount in
                    collectAmount(amount, matchesWallet: matchesWallet)
                }
            }
        }
    }

    private func collectAmountsGrid(
        _ amounts: [ResourceAmount],
        matchesWallet: Bool
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 84), alignment: .leading)],
            alignment: .leading,
            spacing: TrinketDesign.Metrics.smallSpacing
        ) {
            if playerSave.isCloudSyncEnabled {
                Text("Unavailable with cloud sync")
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(amounts) { amount in
                    collectAmount(amount, matchesWallet: matchesWallet)
                }
            }
        }
    }

    private func collectAmount(
        _ amount: ResourceAmount,
        matchesWallet: Bool
    ) -> some View {
        HStack(spacing: TrinketDesign.Metrics.tightSpacing) {
            if matchesWallet {
                HomesteadResourceArtwork(resource: amount.resource)
                    .matchedGeometryEffect(
                        id: amount.resource.walletAnimationID,
                        in: collectionNamespace,
                        isSource: true
                    )
                    .frame(
                        width: TrinketDesign.Metrics.walletResourceArtworkSize,
                        height: TrinketDesign.Metrics.walletResourceArtworkSize
                    )
            } else {
                HomesteadResourceArtwork(resource: amount.resource)
                    .frame(
                        width: TrinketDesign.Metrics.walletResourceArtworkSize,
                        height: TrinketDesign.Metrics.walletResourceArtworkSize
                    )
            }
            Text("\(amount.quantity)")
                .trinketTypography(.statValue)
                .monospacedDigit()
        }
    }

    private func depositFlight(for event: HomesteadDepositEvent) -> some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            ForEach(event.amounts) { amount in
                HStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                    HomesteadResourceArtwork(resource: amount.resource)
                        .matchedGeometryEffect(
                            id: amount.resource.walletAnimationID,
                            in: collectionNamespace,
                            isSource: true
                        )
                        .frame(
                            width: TrinketDesign.Metrics.walletResourceArtworkSize,
                            height: TrinketDesign.Metrics.walletResourceArtworkSize
                        )
                    Text("\(amount.quantity)")
                        .trinketTypography(.statValue)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.snugSpacing)
        .padding(.vertical, TrinketDesign.Metrics.smallSpacing)
        .trinketMaterial(.homesteadFooter)
        .opacity(isDepositLifted ? 0 : 1)
        .allowsHitTesting(false)
    }

    private func showDeposit(_ amounts: [ResourceAmount]) {
        let event = HomesteadDepositEvent(amounts: amounts)
        withAnimation(TrinketMotion.Homestead.tierCompletion) {
            depositEvent = event
            isCollectButtonDismissing = true
        }
        isDepositLifted = false

        Task { @MainActor in
            await Task.yield()
            withAnimation(TrinketMotion.Homestead.tierCompletion) {
                isDepositLifted = true
            }
            try? await Task.sleep(for: .seconds(0.7))
            guard depositEvent?.id == event.id else { return }
            withAnimation(TrinketMotion.Homestead.tierCompletion) {
                depositEvent = nil
                isDepositLifted = false
                isCollectButtonDismissing = false
            }
        }
    }

    private func categoryCard(_ category: HomesteadNodeCategory) -> some View {
        let progress = HomesteadCategoryProgress(category: category, homestead: homestead)
        return NavigationLink(value: category) {
            PlayModeArtworkCard(
                title: category.rawValue,
                subtitle: progress.subtitle,
                symbolName: "hammer.fill",
                artID: category.artID,
                fallbackArtID: category.artID
            )
        }
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Homestead.category(category.rawValue))
    }
}

private struct HomesteadDepositEvent: Identifiable {
    let id = UUID()
    let amounts: [ResourceAmount]
}

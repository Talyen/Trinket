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
    @Environment(OptionsStore.self) private var options
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var collection = HomesteadCollectionControl()
    @State private var depositEvent: HomesteadDepositEvent?
    @State private var isDepositLaunching = false
    @State private var isIconAttentionRaised = false
    @State private var depositDismissTask: Task<Void, Never>?
    @State private var collectionErrorTrigger = 0

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
        ) {
            if let art = ArtCatalog.backgroundArtByID["homestead"]
                ?? ArtCatalog.backgroundArtByID["wheatField"] {
                HomesteadFocalArtwork(art: art)
            } else {
                TrinketDesign.Colors.surface
            }
        } walletBottomContent: {
            collectionSection
        } bodyContent: {
            LazyVGrid(
                columns: TrinketDesign.Layout.hubGridItems(for: horizontalSizeClass),
                spacing: TrinketDesign.Spacing.large,
            ) {
                ForEach(HomesteadNodeCategory.allCases) { category in
                    categoryCard(category)
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
        .onDisappear {
            depositDismissTask?.cancel()
            depositDismissTask = nil
        }
        .homesteadCollectionErrorAlert(collection: $collection)
        .trinketSensoryFeedback(
            .success,
            trigger: collection.collectionEventCount,
            enabled: options.hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .error,
            trigger: collectionErrorTrigger,
            enabled: options.hapticsEnabled,
        )
        .onChange(of: collection.error) { _, newError in
            if newError == "Couldn't save collected materials. Try again." {
                collectionErrorTrigger &+= 1
            }
        }
    }

    private var collectionSection: some View {
        TimelineView(HomesteadProductionSchedule(homestead: homestead, roster: roster)) { context in
            let pending = homestead.pendingProductionAmounts(at: context.date, roster: roster)
            Group {
                if !pending.isEmpty {
                    HStack(spacing: TrinketDesign.Spacing.large) {
                        Spacer(minLength: 0)
                        if playerSave.isCloudSyncEnabled {
                            Text("Unavailable with cloud sync")
                                .trinketTypography(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            collectResourceIcons(pending, drawsAttention: true)
                        }
                        Button {
                            collectProduction(at: context.date)
                        } label: {
                            collectLabel
                        }
                        .disabled(
                            playerSave.isCloudSyncEnabled
                                || depositEvent != nil,
                        )
                        .trinketPrimaryActionButton(
                            accessibilityIdentifier: AccessibilityID.Homestead.collectButton,
                        )
                        .shadow(
                            color: HomesteadResource.gold.tint.opacity(
                                playerSave.isCloudSyncEnabled ? 0 : 0.22,
                            ),
                            radius: TrinketDesign.Spacing.medium,
                        )
                        Spacer(minLength: 0)
                    }
                } else if let depositEvent {
                    HStack(spacing: TrinketDesign.Spacing.large) {
                        Spacer(minLength: 0)
                        collectResourceIcons(depositEvent.amounts)
                            .offset(y: isDepositLaunching ? -depositTravelDistance : 0)
                            .scaleEffect(isDepositLaunching ? 0.82 : 1)
                            .opacity(isDepositLaunching ? 0 : 1)

                        Button(action: {}, label: {
                            collectLabel
                        })
                        .disabled(true)
                        .trinketPrimaryActionButton()
                        .scaleEffect(isDepositLaunching ? 0.98 : 1)
                        .opacity(isDepositLaunching ? 0 : 1)
                        .shadow(
                            color: HomesteadResource.gold.tint.opacity(
                                isDepositLaunching ? 0 : 0.22,
                            ),
                            radius: TrinketDesign.Spacing.medium,
                        )
                        .allowsHitTesting(false)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
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

    private var depositTravelDistance: CGFloat {
        TrinketDesign.Metrics.walletResourceArtworkSize + TrinketDesign.Spacing.extraLarge
    }

    private func collectResourceIcons(
        _ amounts: [ResourceAmount],
        drawsAttention: Bool = false,
    ) -> some View {
        HStack(spacing: -TrinketDesign.Spacing.large) {
            ForEach(Array(amounts.enumerated()), id: \.offset) { index, amount in
                HomesteadResourceArtwork(resource: amount.resource)
                    .frame(
                        width: TrinketDesign.Metrics.walletResourceArtworkSize,
                        height: TrinketDesign.Metrics.walletResourceArtworkSize,
                    )
                    .offset(y: drawsAttention && isIconAttentionRaised ? -2 : 0)
                    .scaleEffect(drawsAttention && isIconAttentionRaised ? 1.05 : 1)
                    .shadow(
                        color: HomesteadResource.gold.tint.opacity(
                            drawsAttention && isIconAttentionRaised ? 0.18 : 0,
                        ),
                        radius: TrinketDesign.Spacing.tight,
                    )
                    .animation(
                        HomesteadMotion.tierCompletion.delay(
                            Double(index) * TrinketMotion.Reward.resourceStagger,
                        ),
                        value: isIconAttentionRaised,
                    )
            }
        }
        .task(id: drawsAttention) {
            guard drawsAttention else { return }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(2.8))
                    isIconAttentionRaised = true
                    try await Task.sleep(for: .seconds(0.65))
                    isIconAttentionRaised = false
                }
            } catch {
                isIconAttentionRaised = false
            }
        }
    }

    private func collectProduction(at date: Date) {
        guard depositEvent == nil else { return }
        var granted: [ResourceAmount] = []
        collection.perform(saveStore: playerSave, at: date) { amounts in
            granted = amounts
        }
        guard !granted.isEmpty else { return }

        let event = HomesteadDepositEvent(amounts: granted)
        depositEvent = event
        isDepositLaunching = false
        depositDismissTask?.cancel()
        depositDismissTask = Task { @MainActor in
            await Task.yield()
            withAnimation(HomesteadMotion.tierCompletion) {
                isDepositLaunching = true
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled, depositEvent?.id == event.id else {
                if depositEvent?.id == event.id {
                    depositEvent = nil
                    isDepositLaunching = false
                    depositDismissTask = nil
                }
                return
            }
            withAnimation(TrinketMotion.Content.fade) {
                depositEvent = nil
            }
            isDepositLaunching = false
            depositDismissTask = nil
        }
    }

    private func categoryCard(_ category: HomesteadNodeCategory) -> some View {
        let progress = HomesteadCategoryProgress(category: category, homestead: homestead)
        return NavigationLink(value: HomesteadRoute.category(category)) {
            HubArtworkCard(
                title: category.rawValue,
                subtitle: progress.subtitle,
                symbolName: "hammer.fill",
                artID: category.artID,
                fallbackArtID: category.artID,
            )
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Homestead.category(category.rawValue))
    }
}

private struct HomesteadDepositEvent: Identifiable {
    let id = UUID()
    let amounts: [ResourceAmount]
}

private struct HomesteadProductionSchedule: TimelineSchedule {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(homestead: homestead, roster: roster, date: startDate, remaining: mode == .lowFrequency ? 2 : 32)
    }

    struct Entries: Sequence, IteratorProtocol {
        let homestead: PlayerHomesteadState
        let roster: PlayerRosterState
        var date: Date
        var remaining: Int

        mutating func next() -> Date? {
            guard remaining > 0 else { return nil }
            remaining -= 1
            let emitted = date
            let upcoming = homestead.nextCollectibleDate(after: emitted, roster: roster)
                ?? emitted.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
            date = upcoming > emitted ? upcoming : emitted.addingTimeInterval(1)
            return emitted
        }
    }
}

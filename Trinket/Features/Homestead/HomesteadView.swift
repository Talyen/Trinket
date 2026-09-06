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
    @Environment(\.scenePhase) private var scenePhase
    @State private var depositGeometry = HomesteadDepositGeometry()
    @State private var collectionSuccessTrigger = 0
    @State private var attentionTrigger = 0
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
            displayedBalances: displayedBalances,
            increaseAnimationDelays: Dictionary(uniqueKeysWithValues: HomesteadResource.allCases.map { ($0, 0) }),
            keepsWalletArtworkStationary: true,
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
        .modifier(HomesteadDepositOverlay(event: depositEvent, geometryChanged: updateDepositGeometry))
        .task(id: depositEvent?.id) {
            await launchDeposit()
        }
        .onDisappear { cancelDeposit() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelDeposit()
            }
        }
        .homesteadCollectionErrorAlert(collection: $collection)
        .trinketSensoryFeedback(
            .success,
            trigger: collectionSuccessTrigger,
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
            let amounts = depositEvent?.amounts ?? pending
            Group {
                if !amounts.isEmpty {
                    HStack(spacing: TrinketDesign.Spacing.large) {
                        Spacer(minLength: 0)
                        if playerSave.isCloudSyncEnabled {
                            Text("Unavailable with cloud sync")
                                .trinketTypography(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            collectResourceIcons(amounts)
                        }
                        Button {
                            collectProduction(at: context.date)
                        } label: {
                            collectLabel
                        }
                        .disabled(playerSave.isCloudSyncEnabled || depositEvent != nil)
                        .trinketPrimaryActionButton(
                            accessibilityIdentifier: AccessibilityID.Homestead.collectButton,
                        )
                        .shadow(
                            color: HomesteadResource.gold.tint.opacity(playerSave.isCloudSyncEnabled ? 0 : 0.22),
                            radius: TrinketDesign.Spacing.medium,
                        )
                        .opacity(depositEvent?.gathered == true ? 0 : 1)
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .onChange(of: !pending.isEmpty, initial: true) { _, isReady in
                if isReady, depositEvent == nil, !playerSave.isCloudSyncEnabled {
                    attentionTrigger &+= 1
                }
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

    private var displayedBalances: [HomesteadResource: Int] {
        guard let depositEvent else { return [:] }
        return Dictionary(uniqueKeysWithValues: depositEvent.amounts.map { amount in
            let held = depositEvent.landed.contains(amount.resource) ? 0 : amount.quantity
            return (amount.resource, max(0, homestead.balance(for: amount.resource, roster: roster) - held))
        })
    }

    private func collectResourceIcons(_ amounts: [ResourceAmount]) -> some View {
        HStack(spacing: -TrinketDesign.Spacing.large) {
            ForEach(amounts) { amount in
                HomesteadResourceArtwork(resource: amount.resource)
                    .frame(
                        width: TrinketDesign.Layout.walletResourceArtworkSize,
                        height: TrinketDesign.Layout.walletResourceArtworkSize,
                    )
                    .anchorPreference(key: HomesteadCollectionArtworkAnchors.self, value: .bounds) {
                        [amount.resource: $0]
                    }
                    .keyframeAnimator(initialValue: CGFloat(0), trigger: attentionTrigger) { content, lift in
                        content.offset(y: depositEvent == nil ? lift : 0)
                    } keyframes: { _ in
                        CubicKeyframe(-2, duration: 0.18)
                        SpringKeyframe(0, duration: 0.3, spring: .smooth)
                    }
                    .opacity(depositEvent == nil ? 1 : 0)
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
        guard depositGeometry.supports(granted) else {
            collectionSuccessTrigger &+= 1
            return
        }
        depositEvent = HomesteadDepositEvent(amounts: granted, geometry: depositGeometry)
    }

    private func launchDeposit() async {
        guard let event = depositEvent else { return }
        do {
            withAnimation(HomesteadMotion.depositGather) {
                depositEvent?.gathered = true
            }
            try await Task.sleep(for: .seconds(HomesteadMotion.depositGatherDuration))
            let ordered = HomesteadResource.allCases.compactMap { resource in
                event.amounts.first { $0.resource == resource }
            }
            for (index, amount) in ordered.enumerated() {
                try Task.checkCancellation()
                guard depositEvent?.id == event.id else { return }
                withAnimation(HomesteadMotion.depositFlight, completionCriteria: .logicallyComplete) {
                    depositEvent?.progress[amount.resource] = 1
                } completion: {
                    landDeposit(amount.resource, eventID: event.id)
                }
                if index < event.amounts.count - 1 {
                    try await Task.sleep(for: .seconds(HomesteadMotion.depositStagger))
                }
            }
        } catch {
            if depositEvent?.id == event.id {
                cancelDeposit()
            }
        }
    }

    private func landDeposit(_ resource: HomesteadResource, eventID: UUID) {
        guard let event = depositEvent, event.id == eventID,
              !event.landed.contains(resource) else { return }
        if event.landed.isEmpty {
            collectionSuccessTrigger &+= 1
        }
        depositEvent?.landed.insert(resource)
        if depositEvent?.landed.count == event.amounts.count {
            withAnimation(HomesteadMotion.depositSettle) {
                depositEvent = nil
            }
        }
    }

    private func updateDepositGeometry(
        _ frames: [HomesteadResource: CGRect],
        sources: Bool,
        viewport: CGRect,
    ) {
        if sources {
            depositGeometry.sources = frames
        } else {
            depositGeometry.destinations = frames
        }
        depositGeometry.viewport = viewport
        if let event = depositEvent, !event.geometry.hasSameDestinations(as: depositGeometry) {
            cancelDeposit()
        }
    }

    private func cancelDeposit() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { depositEvent = nil }
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

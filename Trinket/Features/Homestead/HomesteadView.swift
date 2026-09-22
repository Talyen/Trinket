import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadView: View {
    @Environment(ShellSession.self) private var shellSession
    @State private var requestedCategory: HomesteadNodeCategory?
    @State private var categoryArtworkLease: PreparedArtworkLease?
    @State private var showsCategoryProgress = false
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var collection = HomesteadCollectionControl()
    @State private var depositEvent: HomesteadDepositEvent?
    @Environment(\.scenePhase) private var scenePhase
    @State private var depositGeometry = HomesteadDepositGeometry()
    @State private var collectionSuccessTrigger = 0

    private static let immediateWalletDelays: [HomesteadResource: TimeInterval] =
        Dictionary(uniqueKeysWithValues: HomesteadResource.allCases.map { ($0, 0) })

    private var homestead: PlayerHomesteadState {
        playerSave.homestead
    }

    private var roster: PlayerRosterState {
        playerSave.roster
    }

    var body: some View {
        DetailHeroScrollShell(
            title: "Homestead",
            heroHeightPolicy: .cinematicLandscape,
        ) { baseHeight in
            DetailHeroHeader(
                title: "Homestead",
                baseHeight: baseHeight,
                horizontalPadding: TrinketDesign.Layout.contentMargin,
                bottomPadding: TrinketDesign.Spacing.large,
            ) {
                if let art = ArtCatalog.backgroundArtByID[EncounterArtIDs.homesteadHeroID]
                    ?? ArtCatalog.backgroundArtByID["wheatField"] {
                    FocalBackgroundArtwork(art: art)
                } else {
                    TrinketDesign.Colors.surface
                }
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                HomesteadResourceWallet(
                    homestead: homestead,
                    roster: roster,
                    displayedBalances: displayedBalances,
                    increaseAnimationDelays: Self.immediateWalletDelays,
                    keepsArtworkStationary: true,
                )
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)

                collectionSection

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
            .padding(.top, TrinketDesign.Layout.sectionHeaderSpacing)
            .padding(.bottom, TrinketDesign.Layout.tabBarContentClearance)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
        .modifier(HomesteadDepositOverlay(event: depositEvent, geometryChanged: updateDepositGeometry))
        .task(id: depositEvent?.id) {
            await launchDeposit()
        }
        .task(id: requestedCategory) {
            showsCategoryProgress = false
            guard let category = requestedCategory else { return }
            let progressTask = Task {
                try? await Task.sleep(for: .seconds(TrinketMotion.Interaction.pendingIndicatorDelay))
                guard !Task.isCancelled else { return }
                showsCategoryProgress = true
            }
            defer { progressTask.cancel() }

            let definitions = GameContent.homesteadNodes.filter { $0.category == category }
            let lease = await PreparedArtworkLease(
                names: HomesteadCategoryView.imminentHomesteadArtworkNames(for: definitions),
            )
            guard !Task.isCancelled, requestedCategory == category else { return }
            categoryArtworkLease = lease
            shellSession.homesteadPath.append(.category(category))
            requestedCategory = nil
            showsCategoryProgress = false
        }
        .onChange(of: shellSession.homesteadPath.isEmpty) { _, isEmpty in
            if isEmpty {
                categoryArtworkLease = nil
            }
        }
        .onDisappear {
            requestedCategory = nil
            cancelDeposit()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelDeposit()
            }
        }
        .trinketFailureAlert("Collection Failed", message: $collection.error)
        .trinketSensoryFeedback(
            .success,
            trigger: collectionSuccessTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private var collectionSection: some View {
        TimelineView(HomesteadProductionSchedule(homestead: homestead, roster: roster)) { context in
            let pending = homestead.pendingProductionAmounts(at: context.date, roster: roster)
            let amounts = depositEvent?.amounts ?? pending
            Group {
                if !amounts.isEmpty {
                    VStack(spacing: TrinketDesign.Spacing.small) {
                        HomesteadCollectionPreview(amounts: amounts, isCollecting: depositEvent != nil)
                        Button {
                            collectProduction(at: context.date)
                        } label: {
                            collectLabel
                        }
                        .disabled(collection.isPending || depositEvent != nil)
                        .trinketPrimaryActionButton(
                            accessibilityIdentifier: AccessibilityID.Homestead.collectButton,
                        )
                        .shadow(
                            color: HomesteadResource.gold.tint.opacity(0.22),
                            radius: TrinketDesign.Spacing.medium,
                        )
                        .trinketPresentationVisibility(depositEvent?.gathered != true)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        }
    }

    private var collectLabel: some View {
        Label {
            Text(collection.isPending ? "Collecting…" : "Collect")
        } icon: {
            GameIconImage(.system("gift.fill"))
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

    private func collectProduction(at date: Date) {
        guard depositEvent == nil, !collection.isPending else { return }
        collection.isPending = true
        Task {
            guard let result = await playerSave.retryingTransientOperation({
                await playerSave.collectProduction(at: date)
            }, while: {
                switch $0 {
                case .persistFailed, .cloudUnavailable: true
                default: false
                }
            }) else {
                collection.isPending = false
                return
            }
            collection.complete(result, onSuccess: presentCollection)
        }
    }

    private func presentCollection(_ granted: [ResourceAmount]) {
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
            try await Task.sleep(
                for: .seconds(HomesteadMotion.depositFlightDuration + HomesteadMotion.depositSettleDuration + 0.1),
            )
            if depositEvent?.id == event.id {
                withAnimation(HomesteadMotion.depositSettle) {
                    depositEvent = nil
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
        return Button {
            requestedCategory = category
        } label: {
            HubArtworkCard(
                title: category.rawValue,
                subtitle: progress.subtitle,
                icon: category.icon,
                artID: category.artID,
            )
            .overlay {
                if showsCategoryProgress, requestedCategory == category {
                    ProgressView()
                }
            }
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

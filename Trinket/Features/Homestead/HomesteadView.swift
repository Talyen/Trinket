import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadView: View {
    @Environment(ShellSession.self) private var shellSession
    @State private var requestedCategory: HomesteadNodeCategory?
    @State private var categoryArtworkLease: PreparedArtworkLease?
    @State private var showsCategoryProgress = false
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.playSFX) private var playSFX
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isCollecting = false
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
        GeometryReader { geometry in
            DetailHeroScrollShell(
                title: String(localized: L10n.ui_homesteadview_homestead_9af8e),
                heroHeightPolicy: .cinematicLandscape,
            ) { baseHeight in
                DetailHeroHeader(
                    title: String(localized: L10n.ui_homesteadview_homestead_9af8e),
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
                        gold: roster.gold,
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
                    .frame(maxWidth: HubArtworkLayout.width(in: geometry.size))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                }
                .padding(.top, TrinketDesign.Layout.sectionHeaderSpacing)
            }
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
        .trinketSensoryFeedback(
            .success,
            trigger: collectionSuccessTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private var collectionSection: some View {
        TimelineView(HomesteadProductionSchedule(homestead: homestead, gold: roster.gold)) { context in
            let pending = homestead.pendingProductionAmounts(at: context.date, gold: roster.gold)
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
                        .disabled(isCollecting || depositEvent != nil)
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
            HStack {
                if isCollecting {
                    ProgressView()
                }
                Text(L10n.ui_homesteadview_collect_08a0c)
            }
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
            return (amount.resource, max(0, homestead.balance(for: amount.resource, gold: roster.gold) - held))
        })
    }

    private func collectProduction(at date: Date) {
        guard depositEvent == nil, !isCollecting else { return }
        isCollecting = true
        Task {
            let result = await playerSave.collectProduction(at: date)
            isCollecting = false
            if case let .success(amounts) = result {
                presentCollection(amounts)
            }
        }
    }

    private func presentCollection(_ granted: [ResourceAmount]) {
        guard !granted.isEmpty else { return }
        guard shellSession.selectedTab == .homestead,
              shellSession.homesteadPath.isEmpty,
              scenePhase == .active else { return }
        guard depositGeometry.supports(granted) else {
            playSFX(SFXID.lootCollect, options.effectsVolume)
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
            playSFX(SFXID.lootCollect, options.effectsVolume)
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
    let gold: Int

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(homestead: homestead, gold: gold, date: startDate, remaining: mode == .lowFrequency ? 2 : 32)
    }

    struct Entries: Sequence, IteratorProtocol {
        let homestead: PlayerHomesteadState
        let gold: Int
        var date: Date
        var remaining: Int

        mutating func next() -> Date? {
            guard remaining > 0 else { return nil }
            remaining -= 1
            let emitted = date
            let upcoming = homestead.nextCollectibleDate(after: emitted, gold: gold)
                ?? emitted.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
            date = upcoming > emitted ? upcoming : emitted.addingTimeInterval(1)
            return emitted
        }
    }
}

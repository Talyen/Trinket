import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadBuildControl {
    var upgradeEventCount = 0
    var isPending = false
}

enum HomesteadDetailSheet: Hashable, Identifiable {
    case improvement(Int)
    case wallet
    case crafting
    case activity

    var id: Self {
        self
    }
}

struct HomesteadNodeDetailView: View {
    @Environment(ShellSession.self) private var shell
    @Environment(\.locale) private var locale
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.playSFX) private var playSFX
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var researchCompletionIDs: [String] = []
    @State private var isVisible = false
    @State private var build = HomesteadBuildControl()
    @State private var artworkPins = PreparedArtworkPinSet()
    @State private var sheet: HomesteadDetailSheet?
    @State private var transmutation = TransmutationSelection()
    @State private var requestedLibrary: HomesteadRoute?
    @State private var preparedLibrary: HomesteadRoute?
    @State private var requestedCraft: Bool?
    @State private var preparedCraft: Bool?
    @State private var purchaseCommitted = false
    @State private var pendingCelebration = false
    @State private var purchasePresentation: HomesteadPurchasePresentation?
    @State private var celebrationCount = 0
    @State private var celebrationGeneration = 0

    let definition: HomesteadNodeDefinition
    var initialRecipeID: String?

    private var displaysBuiltArtwork: Bool {
        (purchasePresentation?.displayedTierNumber ?? status.currentTier) > 0
    }

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: playerSave.homestead, gold: playerSave.roster.gold)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                portrait
                VStack(spacing: TrinketDesign.Spacing.large) {
                    buildingIdentity
                    Spacer(minLength: TrinketDesign.Spacing.large)
                    ScrollView {
                        VStack(spacing: TrinketDesign.Spacing.medium) {
                            if definition.id == .library {
                                libraryActivities
                            }
                            if [.blacksmithForge, .archeryRange, .woolTailoring].contains(definition.id) {
                                HomesteadCraftEntry(buildingID: definition.id, isBuilt: status.currentTier > 0) { requestedCraft = true }
                            }
                            if [.transmutationCrucible, .runesmithWorkshop, .wishingWell].contains(definition.id) {
                                HomesteadActivityEntry(nodeID: definition.id, isBuilt: status.currentTier > 0) { sheet = .activity }
                            }
                            upgradeSection
                            panelContent
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.bottom, for: .alignment)
                    .frame(
                        maxHeight: geometry.size.height * 0.65,
                        alignment: .bottom,
                    )
                    .padding(.bottom, TrinketDesign.Spacing.small)
                }
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.top, TrinketDesign.Spacing.small)
            }
        }
        .preparingArtwork(request: $requestedLibrary, presentation: $preparedLibrary) { LibraryArtworkNames.forRoute($0) }
        .onChange(of: preparedLibrary) { _, route in
            guard let route, status.currentTier > 0, playerSave.library.isReadable else { return }
            LibraryNavigation.open(route, in: shell)
        }
        .onChange(of: playerSave.sessionGeneration) { _, _ in
            requestedLibrary = nil
            preparedLibrary = nil
            researchCompletionIDs = []
        }
        .preparingArtwork(request: $requestedCraft, presentation: $preparedCraft) { _ in
            EquipmentRecipe.recipes(for: definition.id).compactMap { $0.forgeArtwork?.thumbnailImageName ?? $0.forgeArtwork?.imageName }
        }
        .onChange(of: preparedCraft) { _, prepared in
            guard prepared == true else { return }
            sheet = .crafting
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationControls }
        .tint(TrinketDesign.Colors.accent)
        .navigationBarBackButtonHidden()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.nodeDetail(title: definition.title))
        .appFramePacingSignpost(AppFramePacingSignposts.Name.navigationPush, isActive: true)
        .sheet(item: $sheet, onDismiss: finishSheetDismissal) { kind in
            HomesteadDetailSheetView(
                definition: definition,
                kind: kind,
                build: $build,
                transmutation: $transmutation,
                purchaseCommitted: purchaseCommitted,
                onPurchase: buildOrUpgrade,
                initialRecipeID: initialRecipeID,
            )
        }
        .trinketSensoryFeedback(.success, trigger: build.upgradeEventCount, enabled: options.hapticsEnabled)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelCelebration()
                researchCompletionIDs = []
            }
        }
        .onAppear {
            isVisible = true
            preparedCraft = nil
            preparedLibrary = nil
            if initialRecipeID != nil, status.currentTier > 0 {
                requestedCraft = true
            }
            AppFramePacingSignposts.event(AppFramePacingSignposts.Name.navigationPush, detail: "homestead=\(definition.id)")
        }
        .task(id: celebrationGeneration) { await celebratePurchase() }
        .task(id: definition.id) { await refreshArtworkPins() }
        .onDisappear {
            isVisible = false
            cancelCelebration()
            artworkPins.release()
        }
    }

    @MainActor
    @ViewBuilder
    private var portrait: some View {
        if let art = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue] {
            FocalBackgroundArtwork(art: art)
                .ignoresSafeArea()
                .saturation(displaysBuiltArtwork ? 1 : 0.35)
                .animation(HomesteadMotion.valueReveal, value: displaysBuiltArtwork)
        } else {
            TrinketDesign.Colors.canvas.ignoresSafeArea()
        }
    }

    @ToolbarContentBuilder
    private var navigationControls: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button { dismiss() } label: {
                Label(String(localized: L10n.ui_homesteaddetailviews_back_76900), systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier(AccessibilityID.Homestead.backButton)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { sheet = .wallet } label: {
                Label(String(localized: L10n.ui_homesteaddetailviews_resources_e89b3), systemImage: "bag")
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier(AccessibilityID.Homestead.walletButton)
        }
    }

    private var buildingIdentity: some View {
        GameLabel(definition.title, balanced: true)
            .trinketTypography(.screenDisplay)
            .multilineTextAlignment(.center)
            .trinketOnArtText()
    }

    private var libraryActivities: some View {
        VStack(spacing: 0) {
            libraryActivity(.bestiary, title: LibraryCopy.localized(L10n.library_bestiary, locale: locale), symbol: "book")
            Divider().padding(.leading, TrinketDesign.Spacing.large)
            libraryActivity(.research, title: LibraryCopy.localized(L10n.library_research, locale: locale), symbol: "magnifyingglass")
            if !researchCompletionIDs.isEmpty, purchasePresentation == nil, !pendingCelebration {
                Button { LibraryNavigation.open(.research, in: shell) } label: {
                    Text(L10n.library_completion_summary(researchCompletionIDs.count))
                        .trinketTypography(.eyebrow)
                        .padding(TrinketDesign.Spacing.medium)
                }.buttonStyle(.plain)
            }
        }
        .homesteadNodePanel()
    }

    private func libraryActivity(_ route: HomesteadRoute, title: String, symbol: String) -> some View {
        Button { requestedLibrary = route } label: {
            HStack(spacing: TrinketDesign.Spacing.medium) {
                Image(systemName: symbol).accessibilityHidden(true)
                Text(title)
                Spacer()
                if status.currentTier == 0 {
                    Text(L10n.library_build_required).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }
            .trinketTypography(.rowTitle)
            .padding(TrinketDesign.Spacing.large)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status.currentTier == 0 || !playerSave.library.isReadable)
        .accessibilityIdentifier(route == .bestiary ? AccessibilityID.Homestead.openBestiary : AccessibilityID.Homestead.openResearch)
    }

    @ViewBuilder
    private var upgradeSection: some View {
        if status.isComplete {
            tierProgress
                .frame(maxWidth: .infinity)
                .padding(TrinketDesign.Spacing.large)
                .homesteadNodePanel()
        } else {
            Button {
                guard let nextTier = status.nextTier else { return }
                cancelCelebration()
                purchaseCommitted = false
                sheet = .improvement(nextTier.tier)
            } label: {
                HStack(spacing: TrinketDesign.Spacing.small) {
                    GameIconImage(GameIcon(id: definition.iconID))
                        .trinketTypography(.sectionTitle)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                        Text(status
                            .currentTier == 0 ? String(localized: L10n.ui_homesteaddetailviews_build_bdd25) :
                            String(localized: L10n.ui_homesteaddetailviews_upgrade_7ec02))
                            .trinketTypography(.rowTitle)
                        tierProgress
                    }
                    Spacer()
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .trinketTypography(.rowTitle)
                .foregroundStyle(.primary)
                .padding(TrinketDesign.Spacing.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .homesteadNodePanel()
            .accessibilityIdentifier(AccessibilityID.Homestead.improveButton)
        }
    }

    private var tierProgress: some View {
        HomesteadTierProgress(
            currentTier: purchasePresentation?.displayedTierNumber ?? status.currentTier,
            totalTiers: definition.maxTier,
            celebrationCount: celebrationCount,
        )
        .frame(width: 132)
        .accessibilityIdentifier(AccessibilityID.Homestead.progress(tier: status.currentTier))
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            if let tier = purchasePresentation?.displayedTier ?? status.currentStage ?? status.nextTier {
                HomesteadBenefitsView(
                    nodeID: definition.id,
                    tier: tier,
                    effectsIdentifier: AccessibilityID.Homestead.currentEffects,
                    highlightedEffects: purchasePresentation?.highlightedEffects ?? [],
                    highlightsProduction: purchasePresentation?.highlightsProduction ?? false,
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TrinketDesign.Spacing.large)
        .homesteadNodePanel()
        .accessibilityElement(children: .contain)
    }

    private func refreshArtworkPins() async {
        let names = [ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue]?.imageName].compactMap(\.self)
        await artworkPins.prepare(names: names)
    }

    private func buildOrUpgrade(_ expectedTier: Int) {
        guard !purchaseCommitted, !build.isPending,
              let nextTier = status.nextTier, nextTier.tier == expectedTier else { return }
        let presentation = HomesteadPurchasePresentation(
            nodeID: definition.id,
            previousTier: status.currentStage,
            targetTier: nextTier,
        )
        let previousResearch = playerSave.library.progress.completedResearchIDs
        let generation = playerSave.sessionGeneration
        build.isPending = true
        Task {
            let result = await playerSave.buildOrUpgradeNode(definition.id, targetTier: expectedTier)
            build.isPending = false
            guard result == .success, generation == playerSave.sessionGeneration else { return }
            guard isVisible, scenePhase == .active else {
                purchaseCommitted = true
                sheet = nil
                return
            }
            researchCompletionIDs = playerSave.library.progress.completedResearchIDs.subtracting(previousResearch).sorted()
            build.upgradeEventCount += 1
            purchasePresentation = presentation
            purchaseCommitted = true
            pendingCelebration = true
            sheet = nil
        }
    }

    private func finishSheetDismissal() {
        preparedCraft = nil
        if pendingCelebration, scenePhase == .active {
            playSFX(SFXID.homesteadBuild, options.effectsVolume)
            purchasePresentation?.displayedTierNumber = status.currentTier
            celebrationCount &+= 1
            celebrationGeneration &+= 1
        }
        pendingCelebration = false
    }

    private func celebratePurchase() async {
        guard celebrationCount > 0, purchasePresentation != nil else { return }
        do {
            try await Task.sleep(for: .seconds(HomesteadMotion.segmentDuration))
            guard !Task.isCancelled, scenePhase == .active, purchasePresentation != nil else { return }
            withAnimation(HomesteadMotion.valueReveal) {
                purchasePresentation?.revealValues()
            }
            try await Task.sleep(for: .seconds(HomesteadMotion.valueHighlightDuration))
            guard !Task.isCancelled, purchasePresentation != nil else { return }
            withAnimation(HomesteadMotion.valueSettle) {
                purchasePresentation = nil
            }
        } catch {
            return
        }
    }

    private func cancelCelebration() {
        pendingCelebration = false
        purchasePresentation = nil
        celebrationGeneration &+= 1
    }
}

private struct HomesteadPurchasePresentation {
    let nodeID: HomesteadNodeID
    let previousTier: HomesteadNodeTier?
    let targetTier: HomesteadNodeTier
    var displayedTier: HomesteadNodeTier
    var displayedTierNumber: Int
    var highlightedEffects: Set<HomesteadEffectLine.Key> = []
    var highlightsProduction = false

    init(nodeID: HomesteadNodeID, previousTier: HomesteadNodeTier?, targetTier: HomesteadNodeTier) {
        self.nodeID = nodeID
        self.previousTier = previousTier
        self.targetTier = targetTier
        displayedTier = previousTier ?? targetTier
        displayedTierNumber = previousTier?.tier ?? 0
    }

    mutating func revealValues() {
        let previous = previousTier.map { HomesteadEffectLine.lines(for: $0, nodeID: nodeID) } ?? []
        highlightedEffects = Set(HomesteadEffectLine.lines(for: targetTier, nodeID: nodeID).filter { line in
            line.resource == nil && !previous.contains { $0.id == line.id && $0.value == line.value }
        }.map(\.id))
        highlightsProduction = targetTier.production.contains { output in
            output.quantity > (previousTier?.production.first { $0.resource == output.resource }?.quantity ?? 0)
        }
        displayedTier = targetTier
    }
}

private struct HomesteadNodePanel: ViewModifier {
    func body(content: Content) -> some View {
        content.trinketMaterial(.frostedPanel, cornerRadius: TrinketDesign.Corners.card)
    }
}

private extension View {
    func homesteadNodePanel() -> some View {
        modifier(HomesteadNodePanel())
    }
}

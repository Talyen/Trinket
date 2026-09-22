import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

enum HomesteadDetailSheet: Hashable, Identifiable {
    case improvement(Int)
    case wallet
    case crafting

    var id: Self {
        self
    }
}

struct HomesteadNodeDetailView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var build = HomesteadBuildControl()
    @State private var pinnedArtwork: [String] = []
    @State private var sheet: HomesteadDetailSheet?
    @State private var requestedCraft: Bool?
    @State private var preparedCraft: Bool?
    @State private var purchaseCommitted = false
    @State private var pendingCelebration = false
    @State private var purchasePresentation: HomesteadPurchasePresentation?
    @State private var celebrationCount = 0
    @State private var celebrationGeneration = 0

    let definition: HomesteadNodeDefinition

    private var displaysBuiltArtwork: Bool {
        (purchasePresentation?.displayedTierNumber ?? status.currentTier) > 0
    }

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: playerSave.homestead, roster: playerSave.roster)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                portrait
                VStack(spacing: TrinketDesign.Spacing.large) {
                    buildingIdentity
                    Spacer(minLength: TrinketDesign.Spacing.large)
                    VStack(spacing: TrinketDesign.Spacing.medium) {
                        if definition.id == .blacksmithForge, status.currentTier > 0 {
                            craftSection
                        }
                        upgradeSection
                        benefitsPanel
                    }
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
        .preparingArtwork(request: $requestedCraft, presentation: $preparedCraft) { _ in
            BlacksmithRecipe.all.compactMap { $0.forgeArtwork?.thumbnailImageName ?? $0.forgeArtwork?.imageName }
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
                purchaseCommitted: purchaseCommitted,
                onPurchase: buildOrUpgrade,
            )
        }
        .trinketSensoryFeedback(.success, trigger: build.upgradeEventCount, enabled: options.hapticsEnabled)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelCelebration()
            }
        }
        .onAppear {
            preparedCraft = nil
            AppFramePacingSignposts.event(AppFramePacingSignposts.Name.navigationPush, detail: "homestead=\(definition.id)")
        }
        .task(id: celebrationGeneration) { await celebratePurchase() }
        .task(id: artworkPinKey) { await refreshArtworkPins() }
        .onDisappear {
            cancelCelebration()
            PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
            pinnedArtwork = []
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
        ToolbarItem(placement: .topBarLeading) {
            Button { dismiss() } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier(AccessibilityID.Homestead.backButton)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { sheet = .wallet } label: {
                Label("Resources", systemImage: "bag")
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier(AccessibilityID.Homestead.walletButton)
        }
    }

    private var buildingIdentity: some View {
        Text(balanced: definition.title)
            .trinketTypography(.screenDisplay)
            .multilineTextAlignment(.center)
            .trinketOnArtText()
    }

    private var craftSection: some View {
        Button { requestedCraft = true } label: {
            HStack(spacing: TrinketDesign.Spacing.small) {
                BlacksmithAnvilIcon()
                    .fill(TrinketDesign.Colors.Overlay.paper)
                    .frame(width: 28, height: 24)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                Text("Craft")
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }
            .trinketTypography(.rowTitle)
            .padding(TrinketDesign.Spacing.large)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .homesteadNodePanel()
        .accessibilityIdentifier(AccessibilityID.Homestead.craftButton)
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
                        Text(status.currentTier == 0 ? "Build" : "Upgrade")
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

    private var benefitsPanel: some View {
        ViewThatFits(in: .vertical) {
            panelContent.fixedSize(horizontal: false, vertical: true)
            ScrollView { panelContent }
        }
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

    private var artworkPinKey: [String] {
        [ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue]?.imageName].compactMap(\.self)
    }

    private func refreshArtworkPins() async {
        pinnedArtwork = await ArtworkPinSet.refresh(next: artworkPinKey, current: pinnedArtwork)
    }

    private func buildOrUpgrade(_ expectedTier: Int) {
        guard !purchaseCommitted, !build.isPending,
              let nextTier = status.nextTier, nextTier.tier == expectedTier else { return }
        let presentation = HomesteadPurchasePresentation(previousTier: status.currentStage, targetTier: nextTier)
        build.isPending = true
        Task {
            guard let result = await playerSave.retryingTransientOperation({ () async -> HomesteadBuildResult in
                let result = await playerSave.buildOrUpgradeNode(definition, targetTier: expectedTier)
                if result == .notAvailable, status.currentTier >= expectedTier {
                    return .success
                }
                return result
            }, while: {
                switch $0 {
                case .persistFailed, .cloudUnavailable: true
                default: false
                }
            }) else {
                build.isPending = false
                return
            }
            build.complete(result) {
                purchasePresentation = presentation
                purchaseCommitted = true
                pendingCelebration = true
                sheet = nil
            }
        }
    }

    private func finishSheetDismissal() {
        preparedCraft = nil
        if pendingCelebration, scenePhase == .active {
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
    let previousTier: HomesteadNodeTier?
    let targetTier: HomesteadNodeTier
    var displayedTier: HomesteadNodeTier
    var displayedTierNumber: Int
    var highlightedEffects: Set<HomesteadEffectLine.Key> = []
    var highlightsProduction = false

    init(previousTier: HomesteadNodeTier?, targetTier: HomesteadNodeTier) {
        self.previousTier = previousTier
        self.targetTier = targetTier
        displayedTier = previousTier ?? targetTier
        displayedTierNumber = previousTier?.tier ?? 0
    }

    mutating func revealValues() {
        let previous = previousTier.map(HomesteadEffectLine.lines(for:)) ?? []
        highlightedEffects = Set(HomesteadEffectLine.lines(for: targetTier).filter { line in
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

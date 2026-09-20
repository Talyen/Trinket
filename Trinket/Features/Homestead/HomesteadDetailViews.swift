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
    @State private var purchaseCommitted = false
    @State private var pendingCelebration = false
    @State private var purchasePresentation: HomesteadPurchasePresentation?
    @State private var celebrationCount = 0
    @State private var celebrationGeneration = 0

    let definition: HomesteadNodeDefinition

    private var status: HomesteadProjectStatus {
        HomesteadProjectStatus(definition: definition, homestead: playerSave.homestead, roster: playerSave.roster)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                portrait
                LinearGradient(
                    colors: [
                        TrinketDesign.Colors.Overlay.ink.opacity(0.64),
                        .clear,
                        .clear,
                        TrinketDesign.Colors.Overlay.ink.opacity(0.38),
                    ],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: TrinketDesign.Spacing.large) {
                    buildingIdentity
                    Spacer(minLength: TrinketDesign.Spacing.large)
                    benefitsPanel
                        .frame(maxHeight: geometry.size.height * 0.43, alignment: .bottom)
                        .padding(.bottom, TrinketDesign.Spacing.small)
                }
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.top, TrinketDesign.Spacing.small)
            }
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
                .saturation(status.isUnlocked ? 1 : 0.35)
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
        VStack(spacing: TrinketDesign.Spacing.small) {
            Text(balanced: definition.title)
                .trinketTypography(.screenDisplay)
                .multilineTextAlignment(.center)
                .trinketOnArtText()
            HomesteadTierProgress(
                currentTier: purchasePresentation?.displayedTierNumber ?? status.currentTier,
                totalTiers: definition.maxTier,
                celebrationCount: celebrationCount,
            )
            .frame(width: 132)
            .accessibilityIdentifier(AccessibilityID.Homestead.progress(tier: status.currentTier))
            .padding(.vertical, TrinketDesign.Spacing.small)
        }
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
                    tier: tier,
                    effectsIdentifier: AccessibilityID.Homestead.currentEffects,
                    highlightedEffects: purchasePresentation?.highlightedEffects ?? [],
                    highlightsProduction: purchasePresentation?.highlightsProduction ?? false,
                )
            }
            if !status.isComplete {
                Button {
                    guard let nextTier = status.nextTier else { return }
                    cancelCelebration()
                    purchaseCommitted = false
                    sheet = .improvement(nextTier.tier)
                } label: {
                    Text(status.currentTier == 0 ? "Build" : "Improve")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.improveButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TrinketDesign.Spacing.large)
        .trinketMaterial(.bottomBar, cornerRadius: TrinketDesign.Corners.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.benefitsPanel)
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

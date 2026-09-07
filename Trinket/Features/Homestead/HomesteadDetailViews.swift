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
    @State private var celebrationCount = 0
    @State private var buildErrorTrigger = 0

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
                    navigationControls
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
        .toolbar(.hidden, for: .navigationBar, .tabBar)
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
        .trinketSensoryFeedback(.error, trigger: buildErrorTrigger, enabled: options.hapticsEnabled)
        .onChange(of: build.error) { _, error in
            if error == "Couldn't save homestead progress. Try again." {
                buildErrorTrigger &+= 1
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                pendingCelebration = false
            }
        }
        .onAppear {
            AppFramePacingSignposts.event(AppFramePacingSignposts.Name.navigationPush, detail: "homestead=\(definition.id)")
        }
        .task(id: artworkPinKey) { await refreshArtworkPins() }
        .onDisappear {
            pendingCelebration = false
            PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
            pinnedArtwork = []
        }
    }

    @ViewBuilder
    private var portrait: some View {
        if let art = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue] {
            HomesteadFocalArtwork(art: art)
                .ignoresSafeArea()
                .saturation(status.isUnlocked ? 1 : 0.35)
        } else {
            TrinketDesign.Colors.canvas.ignoresSafeArea()
        }
    }

    private var navigationControls: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .trinketIconButton(accessibilityIdentifier: AccessibilityID.Homestead.backButton)
            Spacer()
            Button { sheet = .wallet } label: {
                Label("Resources", systemImage: "bag")
                    .labelStyle(.iconOnly)
            }
            .trinketIconButton(accessibilityIdentifier: AccessibilityID.Homestead.walletButton)
        }
    }

    private var buildingIdentity: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            Text(balanced: definition.title)
                .trinketTypography(.screenDisplay)
                .multilineTextAlignment(.center)
                .trinketOnArtText()
            HomesteadTierProgress(
                currentTier: status.currentTier,
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
            if let tier = status.currentStage ?? status.nextTier {
                if status.currentStage == nil {
                    Text("Build benefits")
                        .trinketTypography(.caption)
                        .foregroundStyle(.secondary)
                }
                HomesteadBenefitsView(tier: tier, effectsIdentifier: AccessibilityID.Homestead.currentEffects)
            }
            if !status.isComplete {
                Button {
                    guard let nextTier = status.nextTier else { return }
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
        .background(TrinketDesign.Colors.surface, in: RoundedRectangle(cornerRadius: TrinketDesign.Corners.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.benefitsPanel)
    }

    private var artworkPinKey: [String] {
        let landscape = ArtCatalog.backgroundArtByID[definition.id.rawValue]
        let portrait = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue]
        return [portrait?.imageName, landscape?.imageName, landscape?.thumbnailImageName].compactMap(\.self)
    }

    private func refreshArtworkPins() async {
        let next = Array(Set(artworkPinKey)).sorted()
        let added = Set(next).subtracting(pinnedArtwork)
        if !added.isEmpty {
            await PreparedArtworkCache.shared.prepareAndPin(names: Array(added))
            guard !Task.isCancelled else {
                PreparedArtworkCache.shared.releasePins(names: Array(added))
                return
            }
        }
        guard !Task.isCancelled else { return }
        PreparedArtworkCache.shared.releasePins(names: Array(Set(pinnedArtwork).subtracting(next)))
        pinnedArtwork = next
    }

    private func buildOrUpgrade(_ expectedTier: Int) {
        guard !purchaseCommitted, status.nextTier?.tier == expectedTier else { return }
        build.perform(definition, saveStore: playerSave) { _ in
            purchaseCommitted = true
            pendingCelebration = true
            sheet = nil
        }
    }

    private func finishSheetDismissal() {
        if pendingCelebration, scenePhase == .active {
            celebrationCount &+= 1
        }
        pendingCelebration = false
    }
}

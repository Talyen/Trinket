import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

enum HomesteadDetailSheet: Hashable, Identifiable {
    case improvement(Int)
    case benefits
    case wallet

    var id: Self {
        self
    }

    var isImprovement: Bool {
        if case .improvement = self {
            return true
        }
        return false
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
        ZStack {
            portrait
            LinearGradient(
                colors: [TrinketDesign.Colors.Overlay.ink.opacity(0.64), .clear, .clear, TrinketDesign.Colors.Overlay.ink.opacity(0.38)],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: TrinketDesign.Spacing.large) {
                navigationControls
                buildingIdentity
                Spacer(minLength: TrinketDesign.Spacing.large)
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
                    .trinketCenteredPrimaryAction()
                    .padding(.bottom, TrinketDesign.Spacing.large)
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.top, TrinketDesign.Spacing.small)
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
            .trinketSecondaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.backButton)
            Spacer()
            Button { sheet = .wallet } label: {
                Label("Resources", systemImage: "bag")
                    .labelStyle(.iconOnly)
            }
            .trinketSecondaryActionButton(accessibilityIdentifier: AccessibilityID.Homestead.walletButton)
        }
    }

    private var buildingIdentity: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            Text(balanced: definition.title)
                .trinketTypography(.screenDisplay)
                .multilineTextAlignment(.center)
                .trinketOnArtText()
            Button { sheet = .benefits } label: {
                HStack(spacing: TrinketDesign.Spacing.small) {
                    Text("Tier \(status.currentTier)")
                        .contentTransition(.numericText())
                    Image(systemName: "info.circle")
                        .overlay {
                            if status.isComplete {
                                Circle().stroke(TrinketDesign.Colors.accent, lineWidth: 1).padding(-3)
                            }
                        }
                }
                .trinketTypography(.body)
                .trinketOnArtText(.eyebrow)
                .padding(.vertical, TrinketDesign.Spacing.small)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current benefits")
            .accessibilityValue("Tier \(status.currentTier) of \(definition.maxTier)")
            .accessibilityIdentifier(AccessibilityID.Homestead.benefitsButton)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: celebrationCount) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(HomesteadMotion.celebrationPeak, duration: HomesteadMotion.celebrationRise)
                SpringKeyframe(1, duration: HomesteadMotion.celebrationSettle, spring: .smooth)
            }
        }
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

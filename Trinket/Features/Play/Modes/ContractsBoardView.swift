import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct ContractsBoardView: View {
    @Environment(ContractsPlayMode.self) private var contracts
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.presentPlayCombatantDetail) private var presentPlayCombatantDetail

    @State private var message: StageMapMessage?
    @State private var pinnedArtwork: [String] = []
    @State private var feedbackTrigger = 0
    @State private var displayedOffers: [ContractOffer] = []
    @State private var hasPreparedBoard = false
    @State private var showsPreparationProgress = false

    var body: some View {
        StageSelectScreen(
            eyebrow: "Explore",
            title: "Contracts",
            subtitle: nil,
            titleAccessibilityIdentifier: nil,
        ) {
            heroArtwork
        } content: {
            VStack(spacing: 0) {
                if hasPreparedBoard, displayedOffers.isEmpty {
                    Button("Load Contracts") { perform { contracts.enter() } }
                        .trinketPrimaryActionButton()
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                }
                ZStack(alignment: .top) {
                    StageSelectList(
                        rows: StageSelectRowPresentation<ContractOffer>.contractRows(
                            offers: displayedOffers,
                        ),
                        rowSpacing: TrinketDesign.Spacing.large,
                        isPrimaryActionDisabled: { _ in
                            !isBoardInteractive
                        },
                        onArtworkTap: inspect,
                        onPrimaryAction: { offer in
                            guard isBoardInteractive, displayedOffers.contains(offer) else { return false }
                            message = contracts.startBattle(offerID: offer.id)
                            return message == nil
                        },
                        artwork: { offer, _ in contractArtwork(for: offer) },
                        partyPickerSheet: { _ in StageBattlePartyPickerSheet() },
                    )
                    .id(displayedOffers.map(\.id))
                    .transition(.opacity)
                    .trinketPresentationVisibility(isBoardInteractive, opacity: hasPreparedBoard ? 1 : 0)
                    .padding(.bottom, TrinketDesign.Layout.compactTabBarContentClearance)
                }
            }
            .containerRelativeFrame(.horizontal)
        }
        .accessibilityIdentifier(AccessibilityID.Play.contractsBoard)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    perform { contracts.refresh() }
                } label: {
                    ZStack {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, options: .nonRepeating, value: feedbackTrigger)
                            .opacity(showsPreparationProgress ? 0 : 1)
                        if showsPreparationProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(isBattleActive)
                .accessibilityLabel("Refresh Contracts")
                .accessibilityValue(showsPreparationProgress ? "Preparing contracts" : "")
                .accessibilityIdentifier(AccessibilityID.Play.contractsRefresh)
            }
        }
        .trinketMessageAlert($message)
        .trinketSensoryFeedback(.selection, trigger: feedbackTrigger, enabled: options.hapticsEnabled)
        .task {
            guard !isBattleActive else { return }
            message = contracts.enter()
        }
        .task(id: playerSave.contracts.offers) {
            await prepareBoard(offers: playerSave.contracts.offers)
        }
        .task(id: isPreparing) {
            showsPreparationProgress = false
            guard isPreparing else { return }
            do {
                try await Task.sleep(for: .seconds(TrinketMotion.Interaction.pendingIndicatorDelay))
                try Task.checkCancellation()
                showsPreparationProgress = true
            } catch {}
        }
        .onDisappear {
            PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
            pinnedArtwork = []
            hasPreparedBoard = false
        }
    }

    private var isPreparing: Bool {
        !hasPreparedBoard || displayedOffers != playerSave.contracts.offers
    }

    private var isBoardInteractive: Bool {
        !isBattleActive && !isPreparing
    }

    @ViewBuilder
    private var heroArtwork: some View {
        if let art = ArtCatalog.backgroundArtByID["gameModeContracts"], pinnedArtwork.contains(art.imageName) {
            FocalBackgroundArtwork(art: art)
        } else {
            TrinketDesign.Colors.canvas
        }
    }

    @ViewBuilder
    private func contractArtwork(for offer: ContractOffer) -> some View {
        if isArtworkReady(for: offer), let art = GameContent.enemy(matching: offer.enemyID)?.combatant.artReference {
            MapTileArtwork(art: art)
        } else {
            MapTilePlaceholder(tint: TrinketDesign.Colors.encounterBattle, icon: .system("scroll.fill"))
        }
    }

    private func artworkNames(for offers: [ContractOffer]) -> [String] {
        let enemies = offers.compactMap {
            GameContent.enemy(matching: $0.enemyID)?.combatant.artReference?.imageName
        }
        return Array(Set(enemies + [ArtCatalog.backgroundArtByID["gameModeContracts"]?.imageName].compactMap(\.self))).sorted()
    }

    private func isArtworkReady(for offer: ContractOffer) -> Bool {
        guard let name = GameContent.enemy(matching: offer.enemyID)?.combatant.artReference?.imageName else { return false }
        return pinnedArtwork.contains(name)
    }

    private func prepareBoard(offers: [ContractOffer]) async {
        let names = artworkNames(for: offers)
        let added = Array(Set(names).subtracting(pinnedArtwork))
        await PreparedArtworkCache.shared.prepareAndPin(names: added)
        guard !Task.isCancelled, offers == playerSave.contracts.offers else {
            PreparedArtworkCache.shared.releasePins(names: added)
            return
        }
        pinnedArtwork = Array(Set(pinnedArtwork).union(added))
        withAnimation(TrinketMotion.Screen.crossfade) {
            displayedOffers = offers
            hasPreparedBoard = true
        }
        do {
            try await Task.sleep(for: .seconds(TrinketMotion.Screen.crossfadeDuration))
            try Task.checkCancellation()
            let outgoing = Set(pinnedArtwork).subtracting(names)
            PreparedArtworkCache.shared.releasePins(names: Array(outgoing))
            pinnedArtwork.removeAll { outgoing.contains($0) }
        } catch {}
    }

    private func inspect(_ offer: ContractOffer) {
        guard isBoardInteractive, displayedOffers.contains(offer),
              let encounter = contracts.resolvedEncounter(for: offer) else { return }
        presentPlayCombatantDetail(CombatantCardDetail(
            combatant: encounter.combatant,
            progression: .at(level: encounter.level),
        ))
    }

    private func perform(_ action: () -> StageMapMessage?) {
        message = action()
        if message == nil {
            feedbackTrigger &+= 1
        }
    }
}

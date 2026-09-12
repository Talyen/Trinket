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
                if playerSave.contracts.offers.isEmpty {
                    Button("Load Contracts") { perform { contracts.enter() } }
                        .trinketPrimaryActionButton()
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                }
                StageSelectList(
                    rows: StageSelectRowPresentation<ContractOffer>.contractRows(
                        offers: playerSave.contracts.offers,
                    ),
                    rowSpacing: TrinketDesign.Spacing.large,
                    isPrimaryActionDisabled: { _ in
                        isBattleActive
                    },
                    onArtworkTap: inspect,
                    onPrimaryAction: { offer in
                        message = contracts.startBattle(offerID: offer.id)
                        return message == nil
                    },
                    artwork: { offer, _ in contractArtwork(for: offer) },
                    partyPickerSheet: { _ in StageBattlePartyPickerSheet() },
                )
                .padding(.bottom, TrinketDesign.Layout.compactTabBarContentClearance)
            }
            .containerRelativeFrame(.horizontal)
        }
        .accessibilityIdentifier(AccessibilityID.Play.contractsBoard)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { perform { contracts.refresh() } }
                    .disabled(isBattleActive)
                    .accessibilityIdentifier(AccessibilityID.Play.contractsRefresh)
            }
        }
        .trinketMessageAlert($message)
        .trinketSensoryFeedback(.selection, trigger: feedbackTrigger, enabled: options.hapticsEnabled)
        .task {
            guard !isBattleActive else { return }
            message = contracts.enter()
        }
        .task(id: artworkNames) { await refreshArtworkPins() }
        .onDisappear {
            PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
            pinnedArtwork = []
        }
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

    private var artworkNames: [String] {
        let enemies = playerSave.contracts.offers.compactMap {
            GameContent.enemy(matching: $0.enemyID)?.combatant.artReference?.imageName
        }
        return Array(Set(enemies + [ArtCatalog.backgroundArtByID["gameModeContracts"]?.imageName].compactMap(\.self))).sorted()
    }

    private func isArtworkReady(for offer: ContractOffer) -> Bool {
        guard let name = GameContent.enemy(matching: offer.enemyID)?.combatant.artReference?.imageName else { return false }
        return pinnedArtwork.contains(name)
    }

    private func refreshArtworkPins() async {
        pinnedArtwork = await ArtworkPinSet.refresh(next: artworkNames, current: pinnedArtwork)
    }

    private func inspect(_ offer: ContractOffer) {
        guard let encounter = contracts.resolvedEncounter(for: offer) else { return }
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

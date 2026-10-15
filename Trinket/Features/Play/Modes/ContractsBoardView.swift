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
    @State private var artworkPins = PreparedArtworkPinSet()
    @State private var feedbackTrigger = 0
    @State private var displayedOffers: [ContractOffer] = []
    @State private var hasPreparedBoard = false
    @State private var showsPreparationProgress = false

    var body: some View {
        StageSelectScreen(
            eyebrow: nil,
            title: String(localized: L10n.ui_contractsboardview_contracts_0488a),
            subtitle: nil,
            titleAccessibilityIdentifier: nil,
        ) {
            heroArtwork
        } content: {
            VStack(spacing: 0) {
                if hasPreparedBoard, displayedOffers.isEmpty {
                    Button(String(localized: L10n.ui_contractsboardview_load_contracts_46e66)) { perform { contracts.enter() } }
                        .trinketPrimaryActionButton()
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                }
                ZStack(alignment: .top) {
                    StageSelectList(
                        rows: StageSelectRowPresentation<ContractOffer>.contractRows(
                            offers: displayedOffers, inventory: playerSave.inventory,
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
                        Image(systemName: "dice.fill")
                            .trinketTypography(.button)
                            .foregroundStyle(canRefreshContracts
                                ? AnyShapeStyle(TrinketDesign.Colors.accentEmphasized)
                                : AnyShapeStyle(.secondary))
                            .symbolEffect(.bounce, options: .nonRepeating, value: feedbackTrigger)
                            .opacity(showsPreparationProgress ? 0 : 1)
                        if showsPreparationProgress {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .disabled(!canRefreshContracts)
                .accessibilityLabel(Text(L10n.ui_contractsboardview_refresh_contracts_63bdc))
                .accessibilityValue(showsPreparationProgress ? String(localized: L10n.ui_contractsboardview_preparing_contracts_b8319) :
                    (playerSave.contracts
                        .refreshAvailable ? String(localized: L10n.ui_contractsboardview_ready_5fa7a) :
                        String(localized: L10n.ui_contractsboardview_win_a_contract_to_refresh_9aba7)))
                .accessibilityIdentifier(AccessibilityID.Play.contractsRefresh)
            }
        }
        .disabled(playerSave.isRetryingSaveAction)
        .trinketPlayActionResult($message)
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
            artworkPins.release()
            hasPreparedBoard = false
        }
    }

    private var isPreparing: Bool {
        !hasPreparedBoard || displayedOffers != playerSave.contracts.offers
    }

    private var canRefreshContracts: Bool {
        playerSave.contracts.refreshAvailable && !isBattleActive && !playerSave.isRetryingSaveAction
    }

    private var isBoardInteractive: Bool {
        !isBattleActive && !isPreparing
    }

    @ViewBuilder
    private var heroArtwork: some View {
        if let art = ArtCatalog.backgroundArtByID[EncounterArtIDs.contractsHeroID], artworkPins.names.contains(art.imageName) {
            FocalBackgroundArtwork(art: art)
        } else {
            TrinketDesign.Colors.canvas
        }
    }

    @ViewBuilder
    private func contractArtwork(for offer: ContractOffer) -> some View {
        if isArtworkReady(for: offer), let art = GameContent.enemy(matching: offer.enemyID)?.combatant.artReference {
            // 74pt rows render compact; match Spires by preferring thumbnails.
            MapTileArtwork(art: art, prefersThumbnail: true)
        } else {
            MapTilePlaceholder(tint: TrinketDesign.Colors.encounterBattle, icon: .system("scroll.fill"))
        }
    }

    private func artworkNames(for offers: [ContractOffer]) -> [String] {
        let enemies = offers.compactMap {
            GameContent.enemy(matching: $0.enemyID)?.combatant.artReference
        }.flatMap { [$0.imageName, $0.thumbnailImageName].compactMap(\.self) }
        return Array(Set(enemies + [ArtCatalog.backgroundArtByID[EncounterArtIDs.contractsHeroID]?.imageName].compactMap(\.self))).sorted()
    }

    private func isArtworkReady(for offer: ContractOffer) -> Bool {
        guard let name = GameContent.enemy(matching: offer.enemyID)?.combatant.artReference?.imageName else { return false }
        return artworkPins.names.contains(name)
    }

    private func prepareBoard(offers: [ContractOffer]) async {
        guard let update = await artworkPins.prepare(
            names: artworkNames(for: offers), retainingOutgoing: true,
            isCurrent: { offers == playerSave.contracts.offers },
        ) else { return }
        withAnimation(TrinketMotion.Screen.crossfade) {
            displayedOffers = offers
            hasPreparedBoard = true
        }
        do {
            try await Task.sleep(for: .seconds(TrinketMotion.Screen.crossfadeDuration))
            try Task.checkCancellation()
            guard offers == playerSave.contracts.offers else { return }
            artworkPins.finish(update)
        } catch {}
    }

    private func inspect(_ offer: ContractOffer) {
        guard isBoardInteractive, displayedOffers.contains(offer),
              let encounter = contracts.resolvedEncounter(for: offer) else { return }
        presentPlayCombatantDetail(makePlayEnemyDetail(
            combatant: encounter.combatant,
            level: encounter.level,
        ))
    }

    private func perform(_ action: () -> StageMapMessage?) {
        message = action()
        if message == nil {
            feedbackTrigger &+= 1
        }
    }
}

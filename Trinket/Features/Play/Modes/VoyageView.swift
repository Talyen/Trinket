import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct VoyageView: View {
    @Environment(VoyagePlayMode.self) private var voyage
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(EncounterPlayMode.self) private var encounters
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.presentPlayCombatantDetail) private var presentPlayCombatantDetail
    @State private var displayed: PlayerVoyageState?
    @State private var pinnedArtwork: [String] = []
    @State private var message: StageMapMessage?
    @State private var abandonRunID: String?
    @State private var embarkedOfferID: String?
    @State private var isCrossfading = false
    @State private var preparationGeneration = UUID()
    @Environment(\.dismiss) private var dismiss

    private var hasEncounter: Bool {
        encounters.activeShopEncounter != nil || encounters.activeMysteryEncounter != nil
    }

    private var isReady: Bool {
        displayed == playerSave.voyage && !isBattleActive && !hasEncounter && !isCrossfading
    }

    private var run: VoyageRun? {
        displayed?.activeRun
    }

    var body: some View {
        ZStack {
            if let displayed {
                voyageScreen(displayed)
                    .id(displayed.activeRun?.id ?? "voyage-board")
                    .transition(.opacity)
                    .trinketPresentationVisibility(displayed == playerSave.voyage && !isCrossfading, opacity: 1)
            } else {
                ProgressView()
            }
        }
        .accessibilityIdentifier(AccessibilityID.Voyage.screen)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let run, !run.isComplete {
                    Menu {
                        Button("Abandon Voyage", role: .destructive) { abandonRunID = run.id }
                            .accessibilityIdentifier(AccessibilityID.Voyage.abandon)
                    } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("Voyage options")
                        .accessibilityIdentifier(AccessibilityID.Voyage.options)
                        .disabled(!isReady)
                } else if run == nil || run?.isComplete == true {
                    Button("Refresh Voyages", systemImage: "dice.fill") { voyage.refresh() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityID.Voyage.refresh)
                        .disabled(!isReady || playerSave.voyage.isUnreadable)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let abandonRunID, run?.id == abandonRunID, run?.isComplete == false {
                VStack(spacing: TrinketDesign.Spacing.medium) {
                    Text("Keep rewards already earned. Remaining progress and the completion bonus will be lost.")
                        .trinketTypography(.secondaryBody)
                    HStack {
                        Button("Cancel") { self.abandonRunID = nil }
                            .trinketSecondaryActionButton(accessibilityIdentifier: AccessibilityID.Voyage.cancelAbandon)
                        Button("Abandon Voyage", role: .destructive) {
                            guard isReady, run?.id == abandonRunID, run?.isComplete == false else { return }
                            self.abandonRunID = nil
                            voyage.abandon(runID: abandonRunID)
                        }
                        .trinketPrimaryActionButton(
                            tint: TrinketDesign.Colors.destructive,
                            accessibilityIdentifier: AccessibilityID.Voyage.confirmAbandon,
                        )
                    }
                }
                .padding(TrinketDesign.Layout.contentMargin)
                .trinketScreenBackground()
            }
        }
        .trinketPlayActionResult($message)
        .disabled(playerSave.isRetryingSaveAction)
        .task { message = voyage.enter() }
        .task(id: RefreshInput(state: playerSave.voyage, hasEncounter: hasEncounter)) {
            guard !hasEncounter else { return }
            await prepareDisplay(playerSave.voyage)
        }
        .task(id: PreparationInput(
            roster: playerSave.roster,
            inventory: playerSave.inventory,
            homestead: playerSave.homestead,
            state: playerSave.voyage,
        )) {
            guard !hasEncounter else { return }
            _ = voyage.enter()
            voyage.prepareNextBattle()
        }
        .onDisappear {
            PreparedArtworkCache.shared.releasePins(names: pinnedArtwork)
            pinnedArtwork = []
            displayed = nil
            embarkedOfferID = nil
            isCrossfading = false
            abandonRunID = nil
            preparationGeneration = UUID()
        }
    }

    private func voyageScreen(_ state: PlayerVoyageState) -> some View {
        let run = state.activeRun
        let heroID = run?.offer.chapterID ?? "gameModeVoyage"
        return StageSelectScreen(
            eyebrow: run.map { "\($0.offer.difficulty.title.uppercased()) VOYAGE" },
            title: run.flatMap { GameContent.chapter(id: $0.offer.chapterID)?.title } ?? "Voyage",
            subtitle: nil,
            heroModifier: run.map { run in
                ModifierCaptionPresentation(run.offer.rewardModifier.resolved(
                    ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
                    ownedUniqueIDs: playerSave.inventory.ownedUniqueIDs,
                ))
            },
            titleAccessibilityIdentifier: nil,
            subtitleAccessibilityIdentifier: AccessibilityID.Voyage.destinationReward,
        ) {
            if let art = ArtCatalog.backgroundArtByID[heroID], pinnedArtwork.contains(art.imageName) {
                FocalBackgroundArtwork(art: art)
            } else {
                TrinketDesign.Colors.canvas
            }
        } content: {
            Group {
                if state.isUnreadable {
                    HStack {
                        Button("Back") { dismiss() }
                        Button("Retry") { message = voyage.enter() }
                            .trinketSecondaryActionButton(accessibilityIdentifier: AccessibilityID.Voyage.retry)
                    }
                    .trinketSecondaryActionButton()
                } else if let run, !run.isComplete {
                    route(run)
                } else {
                    board(state.offers)
                }
            }
            .padding(.bottom, TrinketDesign.Layout.compactTabBarContentClearance)
        }
    }

    private func board(_ offers: [VoyageOffer]) -> some View {
        StageSelectList(
            rows: StageSelectRowPresentation<VoyageOffer>.voyageOffers(offers, inventory: playerSave.inventory),
            rowSpacing: TrinketDesign.Spacing.large,
            primaryActionLabelColor: TrinketDesign.Colors.canvas,
            isPrimaryActionDisabled: { _ in !isReady }, onArtworkTap: { _ in },
            onPrimaryAction: { offer in
                guard isReady else { return false }
                embarkedOfferID = offer.id
                voyage.embark(offerID: offer.id)
                return true
            }, artwork: { offer, _ in
                if let art = ArtCatalog.backgroundArtByID[offer.chapterID] {
                    MapTileArtwork(art: art)
                }
            }, partyPickerSheet: { _ in StageBattlePartyPickerSheet() },
        )
    }

    private func route(_ run: VoyageRun) -> some View {
        StageSelectList(
            rows: StageSelectRowPresentation<VoyageNode>.voyageNodes(run, inventory: playerSave.inventory),
            isPrimaryActionDisabled: { _ in !isReady }, onArtworkTap: inspect,
            onPrimaryAction: { node in
                guard isReady else { return false }
                message = voyage.handleNode(runID: run.id, nodeID: node.id)
                return message == nil
            }, artwork: { node, isActive in
                if let art = artwork(for: node, in: run) {
                    MapTileArtwork(art: art, prefersThumbnail: !isActive)
                } else {
                    MapTilePlaceholder(tint: LabyrinthMapPresentation.tint(for: node.type), icon: GameIcon(id: node.type.iconID))
                }
            }, partyPickerSheet: { _ in StageBattlePartyPickerSheet() },
        )
    }

    private func inspect(_ node: VoyageNode) {
        guard isReady, let encounter = voyage.resolvedEncounter(for: node) else { return }
        let modifiers = RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs)
        presentPlayCombatantDetail(makePlayEnemyDetail(
            combatant: encounter.combatant,
            level: encounter.level,
            nodeModifiers: modifiers,
        ))
    }

    private func artwork(for node: VoyageNode, in run: VoyageRun) -> (any PreparedArtworkReference)? {
        if let enemyID = node.enemyID {
            return GameContent.enemy(matching: enemyID)?.combatant.artReference
        }
        if node.type == .recruit {
            return GameContent.recruitEncounterArtReference(forEventID: node.recruitEventID)
        }
        if node.type == .mystery,
           let event = voyage.previewMysteryEvent(for: node, runID: run.id) {
            return MysteryEventArtwork.preparedReference(event: event, chapterID: run.offer.chapterID)
        }
        return LabyrinthMapPresentation.destinationEncounterArtID(for: node.type).flatMap { ArtCatalog.encounterArtByID[$0] }
    }

    private func prepareDisplay(_ state: PlayerVoyageState) async {
        let generation = UUID()
        preparationGeneration = generation
        isCrossfading = false
        var names: Set<String> = []
        let backgrounds = ["gameModeVoyage"] + state.offers.map(\.chapterID) + [state.activeRun?.offer.chapterID].compactMap(\.self)
        for id in backgrounds {
            if let art = ArtCatalog.backgroundArtByID[id] {
                names.insert(art.imageName)
            }
        }
        if let run = state.activeRun, !run.isComplete {
            for node in run.nodes {
                guard let art = artwork(for: node, in: run) else { continue }
                names.insert(node.id == run.nextNode?.id ? art.imageName : art.preparedThumbnailImageName ?? art.imageName)
            }
        }
        let added = names.subtracting(pinnedArtwork)
        let acquired = await PreparedArtworkCache.shared.prepareAndPin(names: Array(added))
        guard !Task.isCancelled, state == playerSave.voyage, !hasEncounter else {
            PreparedArtworkCache.shared.releasePins(names: acquired)
            return
        }
        let shouldCrossfade = embarkedOfferID != nil
            && state.activeRun?.offer.id == embarkedOfferID
            && displayed?.activeRun?.id != state.activeRun?.id
            && displayed != nil
        pinnedArtwork = Array(Set(pinnedArtwork).union(acquired)).sorted()
        if shouldCrossfade {
            embarkedOfferID = nil
            isCrossfading = true
            withAnimation(TrinketMotion.Screen.crossfade) { displayed = state }
            do {
                try await Task.sleep(for: .seconds(TrinketMotion.Screen.crossfadeDuration))
                try Task.checkCancellation()
                guard generation == preparationGeneration else { return }
            } catch { return }
            isCrossfading = false
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { displayed = state }
        }
        let outgoing = Set(pinnedArtwork).subtracting(names)
        PreparedArtworkCache.shared.releasePins(names: Array(outgoing))
        pinnedArtwork.removeAll { outgoing.contains($0) }
    }

    private struct RefreshInput: Equatable {
        let state: PlayerVoyageState
        let hasEncounter: Bool
    }

    private struct PreparationInput: Equatable {
        let roster: PlayerRosterState
        let inventory: PlayerInventoryState
        let homestead: PlayerHomesteadState
        let state: PlayerVoyageState
    }
}

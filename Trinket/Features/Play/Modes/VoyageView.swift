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

    private var hasEncounter: Bool {
        encounters.activeShopEncounter != nil || encounters.activeMysteryEncounter != nil
    }

    private var isReady: Bool {
        displayed == playerSave.voyage && !isBattleActive && !hasEncounter
    }

    private var run: VoyageRun? {
        displayed?.activeRun
    }

    private var heroID: String {
        run?.offer.chapterID ?? "gameModeVoyage"
    }

    var body: some View {
        StageSelectScreen(
            eyebrow: run.map { "\($0.offer.difficulty.title.uppercased()) VOYAGE" },
            title: run.flatMap { GameContent.chapter(id: $0.offer.chapterID)?.title } ?? "Voyage",
            subtitle: run.map { "\($0.nodes.filter(\.isCleared).count) of \($0.nodes.count) completed" },
            titleAccessibilityIdentifier: nil,
            subtitleAccessibilityIdentifier: AccessibilityID.Voyage.progress,
        ) {
            if let art = ArtCatalog.backgroundArtByID[heroID], pinnedArtwork.contains(art.imageName) {
                FocalBackgroundArtwork(art: art)
            } else {
                TrinketDesign.Colors.canvas
            }
        } content: {
            Group {
                if playerSave.voyage.isUnreadable {
                    ContentUnavailableView(
                        "Voyage Unavailable",
                        systemImage: "map",
                        description: Text("Your progress is preserved. Try again later."),
                    )
                } else if let run {
                    route(run)
                } else if let displayed {
                    board(displayed.offers)
                } else {
                    ProgressView().padding()
                }
            }
            .padding(.bottom, TrinketDesign.Layout.compactTabBarContentClearance)
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
                } else if run == nil {
                    Button("Refresh Voyages", systemImage: "dice.fill") { voyage.refresh() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityID.Voyage.refresh)
                        .disabled(!isReady || playerSave.voyage.isUnreadable)
                }
            }
        }
        .confirmationDialog("Abandon Voyage?", isPresented: Binding(
            get: { abandonRunID != nil }, set: {
                if !$0 {
                    abandonRunID = nil
                }
            },
        ), titleVisibility: .visible) {
            Button("Abandon Voyage", role: .destructive) {
                if let abandonRunID {
                    voyage.abandon(runID: abandonRunID)
                }
                abandonRunID = nil
            }
            .accessibilityIdentifier(AccessibilityID.Voyage.confirmAbandon)
        } message: { Text("Keep rewards already earned. Remaining progress and the completion bonus will be lost.") }
        .trinketMessageAlert($message)
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
        }
    }

    private func board(_ offers: [VoyageOffer]) -> some View {
        StageSelectList(
            rows: StageSelectRowPresentation<VoyageOffer>.voyageOffers(offers), rowSpacing: TrinketDesign.Spacing.large,
            isPrimaryActionDisabled: { _ in !isReady }, onArtworkTap: { _ in },
            onPrimaryAction: { offer in
                guard isReady else { return false }
                voyage.embark(offerID: offer.id)
                return true
            }, artwork: { offer, _ in
                if let art = ArtCatalog.backgroundArtByID[offer.chapterID] {
                    MapTileArtwork(art: art)
                }
            }, partyPickerSheet: { _ in StageBattlePartyPickerSheet() },
        )
    }

    @ViewBuilder
    private func route(_ run: VoyageRun) -> some View {
        if run.isComplete {
            StageSelectCompletionPanel(
                title: "Voyage Complete", description: "Your completion bonus was included in the final battle rewards.",
                buttonTitle: "Back to Voyages", tint: TrinketDesign.Colors.accent,
                accessibilityIdentifier: AccessibilityID.Voyage.completed, onBack: { voyage.dismissCompleted() },
            )
        } else {
            StageSelectList(
                rows: StageSelectRowPresentation<VoyageNode>.voyageNodes(run, inventory: playerSave.inventory),
                isPrimaryActionDisabled: { _ in !isReady }, onArtworkTap: inspect,
                onPrimaryAction: { node in
                    guard isReady else { return false }
                    message = voyage.handleNode(runID: run.id, nodeID: node.id)
                    return message == nil
                }, artwork: { node, isActive in
                    if let art = Self.artwork(node) {
                        MapTileArtwork(art: art, prefersThumbnail: !isActive)
                    } else {
                        MapTilePlaceholder(tint: LabyrinthMapPresentation.tint(for: node.type), icon: GameIcon(id: node.type.iconID))
                    }
                }, partyPickerSheet: { _ in StageBattlePartyPickerSheet() },
            )
        }
    }

    private func inspect(_ node: VoyageNode) {
        guard isReady else { return }
        let modifiers = RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs)
        if let encounter = voyage.resolvedEncounter(for: node) {
            presentPlayCombatantDetail(makePlayEnemyDetail(
                combatant: encounter.combatant,
                level: encounter.level,
                labyrinthModifiers: modifiers,
            ))
        } else {
            message = StageMapMessage(
                title: node.type.title,
                message: modifiers.map { "\($0.title): \($0.effect.description)" }.joined(separator: "\n"),
            )
        }
    }

    private static func artwork(_ node: VoyageNode) -> (any PreparedArtworkReference)? {
        if let enemyID = node.enemyID {
            return GameContent.enemy(matching: enemyID)?.combatant.artReference
        }
        if node.type == .recruit {
            return GameContent.recruitEncounterArtReference(forEventID: node.recruitEventID)
        }
        return LabyrinthMapPresentation.destinationEncounterArtID(for: node.type).flatMap { ArtCatalog.encounterArtByID[$0] }
    }

    private func prepareDisplay(_ state: PlayerVoyageState) async {
        var names: Set<String> = []
        let backgrounds = ["gameModeVoyage"] + state.offers.map(\.chapterID) + [state.activeRun?.offer.chapterID].compactMap(\.self)
        for id in backgrounds {
            if let art = ArtCatalog.backgroundArtByID[id] {
                names.insert(art.imageName)
            }
        }
        if let run = state.activeRun {
            for node in run.nodes {
                guard let art = Self.artwork(node) else { continue }
                names.insert(node.id == run.nextNode?.id ? art.imageName : art.preparedThumbnailImageName ?? art.imageName)
            }
        }
        let added = names.subtracting(pinnedArtwork)
        await PreparedArtworkCache.shared.prepareAndPin(names: Array(added))
        guard !Task.isCancelled, state == playerSave.voyage, !hasEncounter else {
            PreparedArtworkCache.shared.releasePins(names: Array(added))
            return
        }
        let outgoing = Set(pinnedArtwork).subtracting(names)
        pinnedArtwork = names.sorted()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { displayed = state }
        PreparedArtworkCache.shared.releasePins(names: Array(outgoing))
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

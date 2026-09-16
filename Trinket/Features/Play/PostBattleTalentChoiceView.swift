import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct PostBattleTalentChoiceView: View {
    @Environment(PlaySession.self) private var play
    @Environment(\.scenePhase) private var scenePhase
    @State private var retainedCombatantID: String?

    var body: some View {
        ZStack {
            if let combatantID = play.currentPostBattleTalentCombatantID ?? retainedCombatantID {
                PostBattleTalentChoiceContent(combatantID: combatantID)
                    .id(combatantID)
                    .transition(.opacity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: play.currentPostBattleTalentCombatantID)
        .onChange(of: play.currentPostBattleTalentCombatantID, initial: true) { _, id in
            if let id {
                retainedCombatantID = id
            }
        }
        .task(id: play.postBattleTalentConfirmationID) {
            guard let id = play.postBattleTalentConfirmationID else { return }
            do {
                try await Task.sleep(for: .seconds(TrinketMotion.Interaction.confirmationDuration))
                try Task.checkCancellation()
                play.finishPostBattleTalentConfirmation(id: id)
            } catch {}
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                finishConfirmation()
            }
        }
        .onDisappear {
            finishConfirmation()
            // Cleared after the exit transition so the next presentation never
            // renders one frame of this combatant's tree first.
            retainedCombatantID = nil
        }
    }

    private func finishConfirmation() {
        if let id = play.postBattleTalentConfirmationID {
            play.finishPostBattleTalentConfirmation(id: id)
        }
    }
}

private struct PostBattleTalentChoiceContent: View {
    @Environment(PlaySession.self) private var play
    @Environment(PlayerSaveStore.self) private var playerSave

    @Environment(OptionsStore.self) private var options
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationPath: [String] = []
    @State private var enteredTreeIDs: Set<String> = []
    @State private var hasFinishedEntrance = false
    @State private var treeSelectionTrigger = 0

    let combatantID: String

    var body: some View {
        NavigationStack(path: $navigationPath) {
            if let combatant, let config {
                treeSelection(combatant: combatant, config: config)
                    .trinketPresentationVisibility(play.currentPostBattleTalentCombatantID == combatantID, opacity: 1)
                    .navigationDestination(for: String.self) { treeID in
                        if let tree = config.tree(matching: treeID) {
                            talentSelection(combatant: combatant, tree: tree)
                                .trinketPresentationVisibility(play.currentPostBattleTalentCombatantID == combatantID, opacity: 1)
                        }
                    }
            } else {
                Color.clear
                    .onAppear(perform: play.dismissPostBattleTalentChoice)
            }
        }
        .trinketPresentationVisibility(play.currentPostBattleTalentCombatantID == combatantID, opacity: 1)
        .task(id: isEntranceActive) {
            await revealCategories()
        }
        .onChange(of: isEntranceActive) { _, active in
            if !active {
                settleCategories()
            }
        }
        .onDisappear(perform: settleCategories)
        .disabled(playerSave.isRetryingSaveAction)
        .interactiveDismissDisabled(playerSave.isRetryingSaveAction)
        .trinketSensoryFeedback(
            .selection,
            trigger: treeSelectionTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private var isEntranceActive: Bool {
        scenePhase == .active
            && navigationPath.isEmpty
            && play.currentPostBattleTalentCombatantID == combatantID
    }

    private func revealCategories() async {
        guard isEntranceActive, !hasFinishedEntrance, let config else { return }
        let eligibleTrees = config.trees.filter { !legalNodes(in: $0, combatantID: combatantID).isEmpty }
        await Task.yield()
        do {
            for (index, tree) in eligibleTrees.enumerated() {
                if index > 0 {
                    try await Task.sleep(for: .seconds(TrinketMotion.Reward.categoryEntranceStagger))
                }
                try Task.checkCancellation()
                guard isEntranceActive, !hasFinishedEntrance else { return }
                withAnimation(TrinketMotion.Reward.reveal) {
                    _ = enteredTreeIDs.insert(tree.id)
                }
            }
            hasFinishedEntrance = true
        } catch {
            settleCategories()
        }
    }

    private func settleCategories() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hasFinishedEntrance = true
        }
    }

    private var combatant: Combatant? {
        GameContent.combatant(matching: combatantID)
    }

    private var config: CombatantTalentConfig? {
        CombatantTalentCatalog.config(for: combatantID)
    }

    private func treeSelection(
        combatant: Combatant,
        config: CombatantTalentConfig,
    ) -> some View {
        DetailHeroScrollShell(title: combatant.name) { baseHeight in
            DetailHeroHeader(
                title: combatant.name,
                baseHeight: baseHeight,
            ) {
                CombatantArtwork(combatant: combatant)
            } footer: {
                Text("Choose a Talent")
                    .trinketTypography(.secondaryBody)
                    .trinketOnArtText(.eyebrow)
            }
        } bodyContent: {
            LazyVGrid(columns: treeColumns, spacing: TrinketDesign.Spacing.small) {
                ForEach(config.trees) { tree in
                    talentTreeButton(tree, combatantID: combatant.id)
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.top, TrinketDesign.Spacing.medium)
            .padding(.bottom, TrinketDesign.Spacing.large)
        }
        .accessibilityIdentifier(AccessibilityID.TalentChoice.screen)
    }

    private func talentSelection(combatant: Combatant, tree: TalentTree) -> some View {
        CombatantTalentsView(
            tree: tree,
            progression: playerSave.roster.progression(for: combatant),
            unlockedTalents: playerSave.roster.unlockedTalents(for: combatant.id),
            initialSelectedNodeID: legalNodes(in: tree, combatantID: combatant.id).first?.id,
            showsReset: false,
            nodeAccessibilityIdentifier: AccessibilityID.TalentChoice.node,
            unlockAccessibilityIdentifier: AccessibilityID.TalentChoice.unlockButton,
            hapticsEnabled: options.hapticsEnabled,
            onUnlockTalent: { node, tree in
                choose(node: node, tree: tree)
            },
        )
    }

    private func talentTreeButton(_ tree: TalentTree, combatantID: String) -> some View {
        let nodes = legalNodes(in: tree, combatantID: combatantID)

        return Button {
            navigationPath.append(tree.id)
            treeSelectionTrigger &+= 1
        } label: {
            TalentTreeCard(
                tree: tree,
                caption: choiceCountLabel(nodes.count),
                isLocked: nodes.isEmpty,
                showsShine: !nodes.isEmpty,
                accessibilityID: AccessibilityID.TalentChoice.tree(id: tree.id),
            )
        }
        .trinketArtworkCardButtonStyle(pressedScale: TrinketMotion.Interaction.choiceCardPressedScale)
        .scaleEffect(
            nodes.isEmpty || hasFinishedEntrance || enteredTreeIDs.contains(tree.id)
                ? 1 : TrinketMotion.Reward.categoryEntranceScale,
        )
        .disabled(nodes.isEmpty)
    }

    private func legalNodes(in tree: TalentTree, combatantID: String) -> [TalentNode] {
        let roster = playerSave.roster
        let unlocked = roster.unlockedTalents(for: combatantID)
        let points = roster.availableTalentPoints(for: combatantID)
        return tree.nodes.filter {
            tree.canUnlock(
                node: $0,
                unlockedNodeIDs: unlocked,
                availablePoints: points,
            )
        }
    }

    private func choose(node: TalentNode, tree: TalentTree) -> TalentUnlockResult {
        guard play.currentPostBattleTalentCombatantID == combatantID else { return .unavailable }
        let result = play.choosePostBattleTalent(nodeID: node.id, treeID: tree.id)
        switch result {
        case .unlocked:
            break
        case .unavailable:
            navigationPath.removeAll()
        case .persistenceFailed:
            playerSave.retrySaveAction(key: "talent-\(combatantID)") {
                _ = choose(node: node, tree: tree)
            }
        }
        return result
    }

    private var treeColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: TrinketDesign.Spacing.small),
            count: 3,
        )
    }

    private func choiceCountLabel(_ count: Int) -> String {
        count == 1 ? "1 choice" : "\(count) choices"
    }
}

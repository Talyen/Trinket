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
        .onDisappear(perform: finishConfirmation)
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
    @State private var navigationPath: [String] = []
    @State private var showsSaveFailure = false
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
        .alert("Couldn't Save Talent", isPresented: $showsSaveFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Talent choice was not saved. Please try again.")
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: treeSelectionTrigger,
            enabled: options.hapticsEnabled,
        )
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
        .trinketArtworkCardButtonStyle()
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
            showsSaveFailure = true
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

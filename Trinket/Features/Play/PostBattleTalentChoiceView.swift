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
    @Environment(PlayerSaveStore.self) private var playerSave

    @Environment(OptionsStore.self) private var options
    @State private var navigationPath: [String] = []
    @State private var showsSaveFailure = false
    @State private var treeSelectionTrigger = 0
    @State private var talentErrorTrigger = 0

    var body: some View {
        NavigationStack(path: $navigationPath) {
            if let combatant, let config {
                treeSelection(combatant: combatant, config: config)
                    .navigationDestination(for: String.self) { treeID in
                        if let tree = config.trees.first(where: { $0.id == treeID }) {
                            talentSelection(combatant: combatant, tree: tree)
                        }
                    }
            } else {
                Color.clear
                    .onAppear(perform: play.dismissPostBattleTalentChoice)
            }
        }
        .onChange(of: play.currentPostBattleTalentCombatantID) { _, _ in
            navigationPath.removeAll()
        }
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
        .trinketSensoryFeedback(
            .error,
            trigger: talentErrorTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private var combatant: Combatant? {
        guard let combatantID = play.currentPostBattleTalentCombatantID else { return nil }
        return GameContent.heroes.first(where: { $0.id == combatantID })
            ?? GameContent.companions.first(where: { $0.id == combatantID })
    }

    private var config: CombatantTalentConfig? {
        guard let combatantID = play.currentPostBattleTalentCombatantID else { return nil }
        return CombatantTalentCatalog.allConfigs[combatantID]
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
        .toolbar {
            closeToolbarItem
        }
        .accessibilityIdentifier(AccessibilityID.TalentChoice.screen)
    }

    private func talentSelection(combatant: Combatant, tree: TalentTree) -> some View {
        CombatantTalentsView(
            tree: tree,
            progression: playerSave.roster.progression(for: combatant),
            unlockedTalents: Binding(
                get: { playerSave.roster.unlockedTalents(for: combatant.id) },
                set: { _ in },
            ),
            initialSelectedNodeID: legalNodes(in: tree, combatantID: combatant.id).first?.id,
            showsReset: false,
            nodeAccessibilityIdentifier: AccessibilityID.TalentChoice.node,
            unlockAccessibilityIdentifier: AccessibilityID.TalentChoice.unlockButton,
            hapticsEnabled: options.hapticsEnabled,
            onUnlockTalent: { node, tree in
                choose(node: node, tree: tree)
            },
            onResetTalents: {},
        )
        .toolbar {
            closeToolbarItem
        }
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
        .trinketQuietTapButtonStyle()
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
        let result = play.choosePostBattleTalent(nodeID: node.id, treeID: tree.id)
        switch result {
        case .unlocked:
            break
        case .unavailable:
            navigationPath.removeAll()
        case .persistenceFailed:
            showsSaveFailure = true
            talentErrorTrigger &+= 1
        }
        return result
    }

    private var treeColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: TrinketDesign.Spacing.small),
            count: 3,
        )
    }

    @ToolbarContentBuilder
    private var closeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Close", action: play.dismissPostBattleTalentChoice)
                .accessibilityIdentifier(AccessibilityID.TalentChoice.closeButton)
        }
    }

    private func choiceCountLabel(_ count: Int) -> String {
        count == 1 ? "1 choice" : "\(count) choices"
    }
}

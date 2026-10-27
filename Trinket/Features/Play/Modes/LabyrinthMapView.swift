import BattleEngine
import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct LabyrinthMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(EncounterPlayMode.self) private var encounters
    @Environment(\.isBattleActive) private var isBattleActive
    @State private var retainedPresentation: LabyrinthMapSnapshot?
    @State private var snapshotCache = LabyrinthMapSnapshotCache()
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @State private var nodeMessage: StageMapMessage?
    @State private var viewedFloor = 1
    @State private var selectedNodeID: String?
    @State private var nodeSelectionFeedbackTrigger = 0

    private var state: PlayerLabyrinthState {
        retainedPresentation?.state ?? playerSave.labyrinth
    }

    private var hasEncounter: Bool {
        encounters.activeMysteryEncounter != nil || encounters.activeShopEncounter != nil
    }

    private var isRetainingPresentation: Bool {
        hasEncounter || isBattleActive || labyrinth.battle.activeBattle != nil
    }

    private var floors: [LabyrinthCluster] {
        state.clusters.lazy.filter { $0.depthBand > 0 }.sorted { $0.depthBand < $1.depthBand }
    }

    private var viewedCluster: LabyrinthCluster? {
        floors.first { $0.depthBand == viewedFloor }
    }

    private var selectedNode: LabyrinthNode? {
        selectedNodeID.flatMap { state.node(id: $0) }
    }

    var body: some View {
        Group {
            if state.hasMap, let viewedCluster {
                floorContent(
                    viewedCluster,
                    snapshot: retainedPresentation ?? snapshotCache.snapshot(playerSave: playerSave, cluster: viewedCluster),
                )
            } else if state.isMapPayloadUnreadable {
                HStack {
                    Button(String(localized: L10n.ui_labyrinthmapview_back_76900)) { dismiss() }
                    Button(String(localized: L10n.ui_labyrinthmapview_retry_94208)) { nodeMessage = labyrinth.enter() }
                        .trinketSecondaryActionButton(accessibilityIdentifier: AccessibilityID.Play.labyrinthEnter)
                }
                .trinketSecondaryActionButton()
            } else {
                emptyState
            }
        }
        .navigationTitle(Text(L10n.ui_labyrinthmapview_labyrinth_df308))
        .navigationBarTitleDisplayMode(.inline)
        .trinketScreenBackground()
        .toolbar {
            if state.hasMap {
                ToolbarItem(placement: .topBarTrailing) {
                    floorMenu
                }
            }
        }
        .onAppear {
            guard retainedPresentation == nil else { return }
            let enteredMap = !state.hasMap
            if enteredMap, let message = labyrinth.enter() {
                nodeMessage = message
            }
            viewedFloor = accessibleFloor(state.currentFloorNumber)
            if !enteredMap {
                labyrinth.prepareReachableBattles()
            }
        }
        .onChange(of: playerSave.labyrinth) { previous, current in
            guard retainedPresentation == nil else { return }
            reconcileProgress(previous: previous, current: current)
        }
        .onChange(of: isRetainingPresentation) { _, isActive in
            guard !isActive, let retainedPresentation else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.retainedPresentation = nil
                reconcileProgress(previous: retainedPresentation.state, current: playerSave.labyrinth)
            }
        }
        .onChange(of: StageSelectPrepareDependency.labyrinth(playerSave: playerSave)) { _, _ in
            labyrinth.prepareReachableBattles()
        }
        .onDisappear {
            labyrinth.selectPreparedBattle(nodeID: nil)
        }
        .trinketPlayActionResult($nodeMessage)
    }

    private func accessibleFloor(_ floor: Int) -> Int {
        max(1, floor)
    }

    private var floorMenu: some View {
        Menu {
            ForEach(floors) { floor in
                Button {
                    showFloor(floor.depthBand)
                } label: {
                    if floor.depthBand == viewedFloor {
                        Label(String(localized: L10n.ui_labyrinthmapview_floor_1_699ae("\(floor.depthBand)")), systemImage: "checkmark")
                    } else {
                        Text(L10n.ui_labyrinthmapview_floor_1_699ae("\(floor.depthBand)"))
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthFloor(floor.depthBand))
            }
        } label: {
            Label(String(localized: L10n.ui_labyrinthmapview_floor_1_699ae("\(viewedFloor)")), systemImage: "square.stack")
        }
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthFloorMenu)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: L10n.ui_labyrinthmapview_labyrinth_df308),
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
            )
        } description: {
            Text(L10n.ui_labyrinthmapview_the_path_remembers_descend_when_you_are_ready_0ced1)
        } actions: {
            Button(String(localized: L10n.ui_labyrinthmapview_enter_dc865)) {
                if let message = labyrinth.enter() {
                    nodeMessage = message
                } else {
                    viewedFloor = accessibleFloor(state.currentFloorNumber)
                }
            }
            .frame(maxWidth: .infinity)
            .trinketPrimaryActionButton()
            .trinketCenteredPrimaryAction()
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthEnter)
        }
    }

    private func floorContent(_ cluster: LabyrinthCluster, snapshot: LabyrinthMapSnapshot) -> some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LabyrinthFloorMap(
                    cluster: cluster,
                    snapshot: snapshot,
                    selectedNodeID: selectedNodeID,
                    availableWidth: max(
                        1,
                        proxy.size.width - 2 * TrinketDesign.Layout.contentMargin,
                    ),
                    viewportWidth: proxy.size.width,
                    onSelectNode: { selectedNodeID = $0 },
                    onDismissSelection: { selectedNodeID = nil },
                )
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.top, TrinketDesign.Spacing.small)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.top)
            .id(cluster.id)
            .transition(.opacity.combined(with: .offset(y: 12)))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Group {
                    if let selectedNode {
                        LabyrinthNodeInspector(
                            node: selectedNode,
                            type: snapshot.type(for: selectedNode),
                            resolvedMysteryEvent: snapshot.events[selectedNode.id],
                            recruitArtwork: snapshot.recruitArtwork(for: selectedNode),
                            onPrimaryAction: { handleNodeAction(selectedNode, snapshot: snapshot) },
                        )
                        .frame(maxWidth: min(420, proxy.size.height * 0.7))
                        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                        .padding(.bottom, TrinketDesign.Spacing.small)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(LabyrinthMapMotion.inspector, value: selectedNodeID)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthMap)
        .animation(LabyrinthMapMotion.floorChange, value: viewedFloor)
        .trinketSensoryFeedback(
            .selection,
            trigger: nodeSelectionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .onChange(of: selectedNodeID) { _, newID in
            if let newID, let node = state.node(id: newID), node.type.isCombat {
                labyrinth.selectPreparedBattle(nodeID: newID)
                nodeSelectionFeedbackTrigger &+= 1
            } else {
                labyrinth.selectPreparedBattle(nodeID: nil)
                if newID != nil {
                    nodeSelectionFeedbackTrigger &+= 1
                }
            }
        }
    }

    private func handleNodeAction(_ node: LabyrinthNode, snapshot: LabyrinthMapSnapshot) -> Bool {
        guard !isRetainingPresentation else { return false }
        retainedPresentation = snapshot
        let message = labyrinth.handleNodeAction(nodeID: node.id)
        if !isRetainingPresentation {
            retainedPresentation = nil
        }
        if let message {
            nodeMessage = message
            return false
        }
        return true
    }

    private func reconcileProgress(previous: PlayerLabyrinthState, current: PlayerLabyrinthState) {
        if current.currentFloorNumber > previous.currentFloorNumber {
            selectedNodeID = nil
            showFloor(accessibleFloor(current.currentFloorNumber))
        } else if let selectedNodeID, current.node(id: selectedNodeID)?.isCleared == true {
            self.selectedNodeID = nil
        }
    }

    private func showFloor(_ floor: Int) {
        guard floors.contains(where: { $0.depthBand == floor }) else { return }
        selectedNodeID = nil
        viewedFloor = floor
    }
}

/// Frozen map presentation retained across encounter covers so the returning
/// map cannot flash unprepared content. Owned by the map view; the floor map
/// renders from it.
@MainActor
struct LabyrinthMapSnapshot {
    let state: PlayerLabyrinthState
    let events: [String: MysteryEvent]
    private let unlockedHeroIDs: Set<String>
    private let unlockedCompanionIDs: Set<String>
    private let worldSeed: UInt64
    private let access: ContentAccessPolicy

    init(preview: LabyrinthMysteryPreview, cluster: LabyrinthCluster) {
        state = preview.labyrinth
        unlockedHeroIDs = preview.unlockedHeroIDs
        unlockedCompanionIDs = preview.unlockedCompanionIDs
        worldSeed = preview.worldSeed
        access = preview.access
        events = preview.events(for: cluster.nodeIDs).filter { nodeID, event in
            preview.labyrinth.nodes[nodeID]?.type != .recruit || !event.isRecruit
        }
    }

    func recruitArtwork(for node: LabyrinthNode) -> EncounterArtReference? {
        LabyrinthMapPresentation.recruitEncounterArtReference(
            for: node,
            worldSeed: worldSeed,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs,
            access: access,
        )
    }

    func type(for node: LabyrinthNode) -> LabyrinthNodeType {
        LabyrinthMapPresentation.effectiveType(
            for: node,
            worldSeed: worldSeed,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs,
            access: access,
        )
    }
}

@MainActor
private final class LabyrinthMapSnapshotCache {
    private var inputs: LabyrinthMysteryPreview?
    private var cluster: LabyrinthCluster?
    private var cached: LabyrinthMapSnapshot?

    func snapshot(playerSave: PlayerSaveStore, cluster: LabyrinthCluster) -> LabyrinthMapSnapshot {
        let inputs = LabyrinthMysteryPreview(playerSave: playerSave)
        if self.inputs == inputs, self.cluster == cluster, let cached {
            return cached
        }
        let snapshot = LabyrinthMapSnapshot(preview: inputs, cluster: cluster)
        self.inputs = inputs
        self.cluster = cluster
        cached = snapshot
        return snapshot
    }
}

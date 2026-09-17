import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct LabyrinthMapView: View {
    private static let inspectorScrollClearance: CGFloat = 360

    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(EncounterPlayMode.self) private var encounters
    @State private var retainedPresentation: LabyrinthMapSnapshot?
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

    private var floors: [LabyrinthCluster] {
        state.clusters.filter { $0.depthBand > 0 }.sorted { $0.depthBand < $1.depthBand }
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
                    snapshot: retainedPresentation ?? LabyrinthMapSnapshot(
                        playerSave: playerSave, labyrinth: labyrinth, cluster: viewedCluster,
                    ),
                )
            } else {
                emptyState
            }
        }
        .navigationTitle("Labyrinth")
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
        .onChange(of: hasEncounter) { _, isActive in
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
        .trinketMessageAlert($nodeMessage)
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
                        Label("Floor \(floor.depthBand)", systemImage: "checkmark")
                    } else {
                        Text("Floor \(floor.depthBand)")
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthFloor(floor.depthBand))
            }
        } label: {
            Text("Floor \(viewedFloor)")
        }
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthFloorMenu)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Labyrinth", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        } description: {
            Text("The path remembers. Descend when you are ready.")
        } actions: {
            Button("Enter") {
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
                    onSelectNode: { selectedNodeID = $0 },
                    onDismissSelection: { selectedNodeID = nil },
                )
                .id(cluster.id)
                .transition(.opacity.combined(with: .offset(y: 12)))
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.top, TrinketDesign.Spacing.small)
                .padding(
                    .bottom,
                    selectedNode == nil
                        ? TrinketDesign.Spacing.extraLarge
                        : Self.inspectorScrollClearance,
                )
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.top)
        }
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthMap)
        .overlay(alignment: .bottom) {
            if let selectedNode {
                LabyrinthNodeInspector(
                    node: selectedNode,
                    type: snapshot.type(for: selectedNode),
                    resolvedMysteryEvent: snapshot.events[selectedNode.id],
                    recruitArtwork: snapshot.recruitArtwork(for: selectedNode),
                    onPrimaryAction: { handleNodeAction(selectedNode, snapshot: snapshot) },
                )
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                .padding(.bottom, TrinketDesign.Spacing.small)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(LabyrinthMapMotion.floorChange, value: viewedFloor)
        .animation(LabyrinthMapMotion.inspector, value: selectedNodeID)
        .trinketSensoryFeedback(
            .selection,
            trigger: nodeSelectionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .onChange(of: selectedNodeID) { _, newValue in
            guard newValue != nil else { return }
            nodeSelectionFeedbackTrigger &+= 1
        }
    }

    private func handleNodeAction(_ node: LabyrinthNode, snapshot: LabyrinthMapSnapshot) -> Bool {
        guard !hasEncounter else { return false }
        retainedPresentation = snapshot
        let message = labyrinth.handleNodeAction(nodeID: node.id)
        if !hasEncounter {
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
    private let roster: PlayerRosterState
    private let worldSeed: UInt64
    private let access: ContentAccessPolicy

    init(playerSave: PlayerSaveStore, labyrinth: LabyrinthPlayMode, cluster: LabyrinthCluster) {
        state = playerSave.labyrinth
        roster = playerSave.roster
        worldSeed = playerSave.worldSeed
        access = playerSave.contentAccess
        events = Dictionary(uniqueKeysWithValues: LabyrinthMapPresentation.floorNodes(for: cluster, in: state).compactMap { node in
            labyrinth.previewMysteryEvent(for: node).map { (node.id, $0) }
        })
    }

    func recruitArtwork(for node: LabyrinthNode) -> EncounterArtReference? {
        LabyrinthMapPresentation.recruitEncounterArtReference(
            for: node,
            worldSeed: worldSeed,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs,
            access: access,
        )
    }

    func type(for node: LabyrinthNode) -> LabyrinthNodeType {
        LabyrinthMapPresentation.effectiveType(
            for: node,
            worldSeed: worldSeed,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs,
            access: access,
        )
    }
}

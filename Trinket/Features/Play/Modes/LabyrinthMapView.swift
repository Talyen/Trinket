import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct LabyrinthMapView: View {
    /// Bottom inset so the floor map clears the selected-node inspector overlay.
    private static let inspectorScrollClearance: CGFloat = 360

    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @State private var nodeMessage: StageMapMessage?
    @State private var viewedFloor = 1
    @State private var selectedNodeID: String?

    private var state: PlayerLabyrinthState {
        playerSave.labyrinth
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
                floorContent(viewedCluster)
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
            let enteredMap = !state.hasMap
            if enteredMap {
                _ = labyrinth.enter()
            }
            viewedFloor = max(1, state.currentFloorNumber)
            // Entering a fresh map mutates `playerSave.labyrinth`; the change
            // observer below prepares reachable battles after that mutation.
            // Avoid doing the same preparation again in this appearance pass.
            if !enteredMap {
                labyrinth.prepareReachableBattles()
            }
        }
        .onChange(of: playerSave.labyrinth) { previous, current in
            labyrinth.prepareReachableBattles()
            if current.currentFloorNumber > previous.currentFloorNumber {
                selectedNodeID = nil
                showFloor(current.currentFloorNumber)
            } else if let selectedNodeID, current.node(id: selectedNodeID)?.isCleared == true {
                self.selectedNodeID = nil
            }
        }
        .onChange(of: playerSave.roster) { _, _ in labyrinth.prepareReachableBattles() }
        .onChange(of: playerSave.inventory) { _, _ in labyrinth.prepareReachableBattles() }
        .onChange(of: playerSave.homestead) { _, _ in labyrinth.prepareReachableBattles() }
        .alert(item: $nodeMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
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
                    viewedFloor = max(1, state.currentFloorNumber)
                }
            }
            .trinketPrimaryActionButton()
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthEnter)
        }
    }

    private func floorContent(_ cluster: LabyrinthCluster) -> some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LabyrinthFloorMap(
                    cluster: cluster,
                    state: state,
                    selectedNodeID: selectedNodeID,
                    availableWidth: max(
                        1,
                        proxy.size.width - 2 * TrinketDesign.Metrics.contentMargin
                    ),
                    onSelectNode: { selectedNodeID = $0 },
                    onDismissSelection: { selectedNodeID = nil }
                )
                .id(cluster.id)
                .transition(.opacity.combined(with: .offset(y: 12)))
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.top, TrinketDesign.Metrics.smallSpacing)
                .padding(
                    .bottom,
                    selectedNode == nil
                        ? TrinketDesign.Metrics.extraLargeSpacing
                        : Self.inspectorScrollClearance
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
                    state: state,
                    onMessage: { nodeMessage = $0 }
                )
                .frame(maxWidth: 340)
                .padding(.bottom, TrinketDesign.Metrics.smallSpacing)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(TrinketMotion.Labyrinth.floorChange, value: viewedFloor)
        .animation(TrinketMotion.Labyrinth.inspector, value: selectedNodeID)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectedNodeID,
            enabled: options.hapticsEnabled
        )
    }

    private func showFloor(_ floor: Int) {
        guard floors.contains(where: { $0.depthBand == floor }) else { return }
        selectedNodeID = nil
        viewedFloor = floor
    }
}

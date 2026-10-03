import Foundation
import os
import SwiftData
import TrinketContent
import TrinketCore

private let labyrinthMapLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "LabyrinthMapPayload",
)

extension LabyrinthProgressModel {
    func toPlayerLabyrinthState() -> PlayerLabyrinthState {
        var state = PlayerLabyrinthState(
            worldSeed: worldSeed,
            mapVersion: mapVersion,
            hasEntered: hasEntered,
        )
        guard let mapPayload else { return state }
        guard mapVersion == LabyrinthGenerator.currentMapVersion else {
            state.isMapPayloadUnreadable = true
            return state
        }
        do {
            let payload = try JSONDecoder().decode(LabyrinthMapPayload.self, from: mapPayload)
            state.clusters = payload.clusters
            state.nodes = Dictionary(
                payload.nodes.map { ($0.id, $0) },
                uniquingKeysWith: { _, new in new },
            )
        } catch {
            labyrinthMapLogger.error(
                "Failed to decode labyrinth map payload; keeping stored blob: \(error.localizedDescription, privacy: .public)",
            )
            state.isMapPayloadUnreadable = true
        }
        return state
    }

    func update(from state: PlayerLabyrinthState, context _: ModelContext? = nil) {
        worldSeed = state.worldSeed
        mapVersion = state.mapVersion
        hasEntered = state.hasEntered
        if state.isMapPayloadUnreadable {
            return
        }
        let payload = LabyrinthMapPayload(
            clusters: state.clusters,
            nodes: Array(state.nodes.values).sorted { $0.id < $1.id },
        )
        do {
            mapPayload = try JSONEncoder().encode(payload)
        } catch {
            labyrinthMapLogger.error(
                "Failed to encode labyrinth map payload: \(error.localizedDescription, privacy: .public)",
            )
        }
    }
}

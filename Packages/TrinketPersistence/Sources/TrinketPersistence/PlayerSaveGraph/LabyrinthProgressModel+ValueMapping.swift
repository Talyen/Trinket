import Foundation
import os
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
                payload.nodes.lazy.map { ($0.id, $0) },
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

    func apply(_ state: PlayerLabyrinthState, payload: PlayerSaveGraphWrite.LabyrinthPayload) {
        worldSeed = state.worldSeed
        mapVersion = state.mapVersion
        hasEntered = state.hasEntered
        if case let .replace(bytes) = payload {
            mapPayload = bytes
        }
    }
}

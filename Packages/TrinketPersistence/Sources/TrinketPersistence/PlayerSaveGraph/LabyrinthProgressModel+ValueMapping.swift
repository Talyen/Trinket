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
        switch decodeMapPayload() {
        case .missing:
            PlayerLabyrinthState(
                worldSeed: worldSeed,
                mapVersion: mapVersion,
                hasEntered: hasEntered,
                clusters: [],
                nodes: [:],
            )
        case let .decoded(payload):
            PlayerLabyrinthState(
                worldSeed: worldSeed,
                mapVersion: mapVersion,
                hasEntered: hasEntered,
                clusters: payload.clusters,
                nodes: Dictionary(
                    payload.nodes.map { ($0.id, $0) },
                    uniquingKeysWith: { _, new in new },
                ),
            )
        case .unreadable:
            PlayerLabyrinthState(
                worldSeed: worldSeed,
                mapVersion: mapVersion,
                hasEntered: hasEntered,
                clusters: [],
                nodes: [:],
                isMapPayloadUnreadable: true,
            )
        }
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

    private enum MapPayloadDecode {
        case missing
        case decoded(LabyrinthMapPayload)
        case unreadable
    }

    private func decodeMapPayload() -> MapPayloadDecode {
        guard let mapPayload else {
            return .missing
        }
        guard mapVersion == LabyrinthGenerator.currentMapVersion else { return .unreadable }
        do {
            return try .decoded(JSONDecoder().decode(LabyrinthMapPayload.self, from: mapPayload))
        } catch {
            labyrinthMapLogger.error(
                "Failed to decode labyrinth map payload; keeping stored blob: \(error.localizedDescription, privacy: .public)",
            )
            return .unreadable
        }
    }
}

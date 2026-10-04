import Foundation
@testable import TrinketPersistence

struct PlaythroughRecord: Codable {
    let sequence: Int
    let action: PlaythroughAction
    let state: CloudSaveSnapshot
    let result: String?
    var battle: PlaythroughBattleObservation?
}

struct PlaythroughBattleObservation: Codable, Equatable {
    let turn: Int
    let health: [Int]
    let hand: [Int]
    let playable: [Int]
    let outcome: String
}

@MainActor
final class PlaythroughJournal {
    let directory: URL
    private let handle: FileHandle
    private let limit: Int
    private var size = 0
    private let encoder: JSONEncoder

    init(directory: URL, scenario: PlaythroughScenario) throws {
        self.directory = directory
        limit = scenario.maxArtifactBytes
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(scenario).write(to: directory.appendingPathComponent("scenario.json"), options: .atomic)
        let url = directory.appendingPathComponent("actions.jsonl")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        handle = try FileHandle(forWritingTo: url)
    }

    deinit {
        try? handle.close()
    }

    func append(_ record: PlaythroughRecord) throws {
        var data = try encoder.encode(record)
        data.append(0x0A)
        guard size + data.count <= limit else { throw PlaythroughFailure.budget("journal bytes") }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        size += data.count
    }

    func finish(_ summary: PlaythroughSummary) throws {
        try encoder.encode(summary).write(to: directory.appendingPathComponent("summary.json"), options: .atomic)
    }

    static func semantic(_ save: PlayerSave) -> CloudSaveSnapshot {
        var value = save
        // Wall-clock write metadata does not affect legal choices or rewards.
        // The production snapshot also omits the local session generation.
        value.modifiedAt = Date(timeIntervalSince1970: 0)
        value.journey.mysteryOfferPayloads = value.journey.mysteryOfferPayloads.mapValues(canonicalPayload)
        value.journey.shopPayloads = value.journey.shopPayloads.mapValues(canonicalPayload)
        value.labyrinth.nodes = value.labyrinth.nodes.mapValues { original in
            var node = original
            node.mysteryOffersPayload = original.mysteryOffersPayload.map(canonicalPayload)
            node.shopPayload = original.shopPayload.map(canonicalPayload)
            return node
        }
        if !value.voyage.isUnreadable,
           let voyage = try? JSONDecoder().decode(
               PlayerVoyageState.self, from: canonicalVoyagePayload(value.voyage.encodedPayload),
           ) {
            value.voyage = voyage
        }
        return CloudSaveSnapshot(value)
    }

    static func decodeRecord(_ data: Data) throws -> PlaythroughRecord {
        let object = try JSONSerialization.jsonObject(with: data)
        let normalized = normalize(object)
        return try JSONDecoder().decode(PlaythroughRecord.self, from: JSONSerialization.data(withJSONObject: normalized))
    }

    private static func normalize(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, pair in
                let (key, value) = pair
                if key == "keywords", let keywords = value as? [String] {
                    result[key] = keywords.sorted()
                } else if ["mysteryOfferPayloads", "shopPayloads"].contains(key), let values = value as? [String: String] {
                    result[key] = values.mapValues { Data(base64Encoded: $0).map { canonicalPayload($0).base64EncodedString() } ?? $0 }
                } else if ["mysteryOffersPayload", "shopPayload", "voyagePayload"].contains(key),
                          let string = value as? String, let data = Data(base64Encoded: string) {
                    result[key] = (key == "voyagePayload" ? canonicalVoyagePayload(data) : canonicalPayload(data)).base64EncodedString()
                } else {
                    result[key] = normalize(value)
                }
            }
        }
        if let array = value as? [Any] {
            return array.map(normalize)
        }
        return value
    }

    private static func canonicalVoyagePayload(_ data: Data) -> Data {
        guard !PlayerVoyageState.decodePayload(data).isUnreadable else { return data }
        return canonicalPayload(data)
    }

    private static func canonicalPayload(_ data: Data) -> Data {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            return try JSONSerialization.data(withJSONObject: normalize(object), options: [.sortedKeys])
        } catch {
            // Preserve malformed evidence verbatim; normalization must never repair it.
            return data
        }
    }
}

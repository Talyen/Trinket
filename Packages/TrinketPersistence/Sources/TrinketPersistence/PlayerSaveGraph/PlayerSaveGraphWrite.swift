import Foundation
import TrinketContent

/// Prepares every fallible payload before any SwiftData mutation. Applying or
/// compensating a prepared write performs no serialization.
struct PlayerSaveGraphWrite {
    let save: PlayerSave
    let slices: PlayerSaveSlice
    let labyrinthPayload: Data?
    let preservesLabyrinthPayload: Bool
    let contractsPayload: Data?
    let voyagePayload: Data?
    let libraryPayload: Data?
    let itemPowerPayloads: [String: Data]

    init(save: PlayerSave, slices: PlayerSaveSlice) throws {
        self.save = save
        self.slices = slices
        preservesLabyrinthPayload = save.labyrinth.isMapPayloadUnreadable
        labyrinthPayload = slices.contains(.labyrinth) ? try Self.encodeLabyrinth(save.labyrinth) : nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        contractsPayload = slices.contains(.contracts) ? try encoder.encode(save.contracts) : nil
        if slices.contains(.voyage) {
            voyagePayload = try save.voyage.unreadablePayload ?? encoder.encode(save.voyage)
        } else {
            voyagePayload = nil
        }
        libraryPayload = slices.contains(.library) ? try save.library.encodedPayload() : nil
        var powers: [String: Data] = [:]
        if slices.contains(.inventory) {
            for item in save.inventory.items {
                if let affixPowers = item.affixPowers {
                    powers[item.id] = try ItemAffixPowerCoding.encode(affixPowers)
                }
            }
        }
        itemPowerPayloads = powers
    }

    /// Capture original bytes, including unreadable payloads, so a refused
    /// write cannot lose them or fail while serializing compensation.
    init(restoring save: PlayerSave, slices: PlayerSaveSlice, root: PlayerSaveRoot) {
        self.save = save
        self.slices = slices
        preservesLabyrinthPayload = false
        labyrinthPayload = slices.contains(.labyrinth) ? root.labyrinth?.mapPayload : nil
        contractsPayload = slices.contains(.contracts) ? root.contractsPayload : nil
        voyagePayload = slices.contains(.voyage) ? root.voyagePayload : nil
        libraryPayload = slices.contains(.library) ? root.libraryPayload : nil
        var powers: [String: Data] = [:]
        if slices.contains(.inventory) {
            for item in root.inventory?.items ?? [] {
                powers[item.id] = item.affixPowersJSON
            }
        }
        itemPowerPayloads = powers
    }

    static func encodeLabyrinth(_ state: PlayerLabyrinthState) throws -> Data? {
        guard !state.isMapPayloadUnreadable else { return nil }
        return try JSONEncoder().encode(LabyrinthMapPayload(
            clusters: state.clusters,
            nodes: Array(state.nodes.values).sorted { $0.id < $1.id },
        ))
    }
}

import Foundation
import TrinketContent

/// Prepares every fallible payload before any SwiftData mutation. Applying or
/// compensating a prepared write performs no serialization.
struct PlayerSaveGraphWrite {
    enum LabyrinthPayload {
        case preserve
        case replace(Data?)
    }

    let save: PlayerSave
    let slices: PlayerSaveSlice
    let labyrinthPayload: LabyrinthPayload
    let contractsPayload: Data?
    let voyagePayload: Data?
    let libraryPayload: Data?
    let itemPowerPayloads: [String: Data]

    init(save: PlayerSave, slices: PlayerSaveSlice) throws {
        self.save = save
        self.slices = slices
        if slices.contains(.labyrinth), !save.labyrinth.isMapPayloadUnreadable {
            labyrinthPayload = try .replace(JSONEncoder().encode(LabyrinthMapPayload(
                clusters: save.labyrinth.clusters,
                nodes: save.labyrinth.nodes.values.sorted { $0.id < $1.id },
            )))
        } else {
            labyrinthPayload = .preserve
        }
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
        labyrinthPayload = slices.contains(.labyrinth) ? .replace(root.labyrinth?.mapPayload) : .preserve
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
}

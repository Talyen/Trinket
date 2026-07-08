import Foundation
import TrinketCore

/// Injectable player-save content lookups. Persistence sanitization and merge logic
/// use this seam instead of reaching for `GameContent` directly.
public protocol PlayerContentCatalog: Sendable {
    var chapters: [Chapter] { get }
    var heroIDs: Set<String> { get }
    var petIDs: Set<String> { get }
    func stage(id: String) -> Stage?
    func itemBaseType(id: String) -> ItemBaseType?
    func itemTemplate(matching templateID: String) -> InventoryItem?
}

public struct GameContentPlayerCatalog: PlayerContentCatalog {
    public init() {}

    public var chapters: [Chapter] {
        GameContent.chapters
    }

    public var heroIDs: Set<String> {
        Set(GameContent.heroes.map(\.id))
    }

    public var petIDs: Set<String> {
        Set(GameContent.pets.map(\.id))
    }

    public func stage(id: String) -> Stage? {
        GameContent.stage(id: id)
    }

    public func itemBaseType(id: String) -> ItemBaseType? {
        GameContent.itemBaseTypes.first { $0.id == id }
    }

    public func itemTemplate(matching templateID: String) -> InventoryItem? {
        GameContent.itemTemplate(matching: templateID)
    }
}

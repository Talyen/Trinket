import Foundation
import SwiftData

@Model
public final class CollectionAttentionModel {
    public var root: PlayerSaveRoot?
    public var viewedCombatantIDs: [String] = []
    public var viewedItemIDs: [String] = []

    public init() {}
}

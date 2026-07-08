import Foundation
import TrinketCore

public extension PlayerSaveRoot {
    convenience init(save: PlayerSave, id: String = "primary") {
        self.init(id: id)
        update(from: save)
    }

    func toPlayerSave() -> PlayerSave {
        let inventoryState = inventory?.toPlayerInventoryState() ?? .freshStart
        return PlayerSave(
            schemaVersion: schemaVersion,
            modifiedAt: modifiedAt,
            sessionGeneration: sessionGeneration,
            journey: journey?.toJourneyProgressState() ?? .initial,
            roster: roster?.toPlayerRosterState(inventory: inventoryState) ?? .freshStart,
            inventory: inventoryState,
            homestead: homestead?.toPlayerHomesteadState() ?? .freshStart
        )
    }

    func update(from save: PlayerSave) {
        schemaVersion = save.schemaVersion
        modifiedAt = save.modifiedAt
        sessionGeneration = save.sessionGeneration

        syncChild(\.journey, make: JourneyProgressModel()) {
            $0.update(from: save.journey)
        } setRoot: {
            $0.root = self
        }

        syncChild(\.roster, make: RosterModel()) {
            $0.update(from: save.roster)
        } setRoot: {
            $0.root = self
        }

        syncChild(\.inventory, make: InventoryModel()) {
            $0.update(from: save.inventory)
        } setRoot: {
            $0.root = self
        }

        syncChild(\.homestead, make: HomesteadModel()) {
            $0.update(from: save.homestead)
        } setRoot: {
            $0.root = self
        }
    }

    private func syncChild<Model: AnyObject>(
        _ keyPath: ReferenceWritableKeyPath<PlayerSaveRoot, Model?>,
        make: @autoclosure @escaping () -> Model,
        update: (Model) -> Void,
        setRoot: (Model) -> Void
    ) {
        let model = self[keyPath: keyPath] ?? make()
        update(model)
        self[keyPath: keyPath] = model
        setRoot(model)
    }
}

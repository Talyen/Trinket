import TrinketFeatureSupport

@MainActor
enum ArtworkPinSet {
    static func refresh(next: [String], current: [String]) async -> [String] {
        let nextSet = Set(next)
        let previous = Set(current)
        let added = nextSet.subtracting(previous)
        if !added.isEmpty {
            await PreparedArtworkCache.shared.prepareAndPin(names: Array(added))
            guard !Task.isCancelled else {
                PreparedArtworkCache.shared.releasePins(names: Array(added))
                return current
            }
        }
        guard !Task.isCancelled else { return current }
        PreparedArtworkCache.shared.releasePins(names: Array(previous.subtracting(nextSet)))
        return Array(nextSet).sorted()
    }
}

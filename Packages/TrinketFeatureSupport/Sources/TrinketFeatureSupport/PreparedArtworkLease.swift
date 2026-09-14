import Foundation

@MainActor
public final class PreparedArtworkLease {
    private let names: [String]

    public init(names: [String]) async {
        guard !Task.isCancelled else {
            self.names = []
            return
        }
        self.names = await PreparedArtworkCache.shared.acquirePinnedArtwork(names: names)
    }

    isolated deinit {
        PreparedArtworkCache.shared.releasePins(names: names)
    }
}

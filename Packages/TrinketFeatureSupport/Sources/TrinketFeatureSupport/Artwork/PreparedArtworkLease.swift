import Foundation

/// An acquisition can be released only by its owner, at most once.
@MainActor
public final class PreparedArtworkLease {
    private var names: [String]?
    private let cache: PreparedArtworkCache

    public convenience init(names: [String]) async {
        await self.init(names: names, cache: .shared)
    }

    init(names: [String], cache: PreparedArtworkCache) async {
        self.names = await cache.acquirePinnedArtwork(names: names)
        self.cache = cache
    }

    public func release() {
        guard let names = takeNames() else { return }
        cache.releasePins(names: names)
    }

    /// Launch replacement transfers this acquisition into the cache's launch owner.
    func takeNames() -> [String]? {
        defer { names = nil }
        return names
    }

    isolated deinit {
        if let names {
            cache.releasePins(names: names)
        }
    }
}

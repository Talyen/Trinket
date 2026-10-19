import os
import SwiftUI
import TrinketContent
import UIKit

private let preparedArtworkFallbackLogger = Logger(
    subsystem: "com.trinket.diagnostics",
    category: "ArtworkCache",
)

@MainActor
private enum PreparedArtworkFallbackDedupe {
    static var seen: Set<String> = []
    static func shouldLog(_ name: String) -> Bool {
        seen.insert(name).inserted
    }
}

@MainActor
private enum PreparedArtworkFallbackWarmup {
    private static var pending: Set<String> = []

    static func prepare(_ name: String) {
        guard pending.insert(name).inserted else { return }
        Task { @MainActor in
            defer { pending.remove(name) }
            await PreparedArtworkCache.shared.prepare(names: [name])
        }
    }
}

/// Concurrency-Safety: `@unchecked Sendable` — `name` is a value type and `image` only crosses isolation through the main-actor cache.
struct PreparedArtwork: @unchecked Sendable {
    let name: String
    let image: UIImage?
}

public extension Image {
    enum PreparedArtworkDisplaySize: Sendable {
        /// Prepared first paint; the shared renderer upgrades to the measured pixel size.
        case compact
        case full
    }

    @MainActor
    static func preparedAsset(named name: String) -> Image {
        if let image = PreparedArtworkCache.shared.image(named: name) {
            return Image(uiImage: image)
        }
        if PreparedArtworkFallbackDedupe.shouldLog(name) {
            preparedArtworkFallbackLogger.debug(
                "PreparedArtwork cache miss for \(name, privacy: .public): on-demand decode will hitch",
            )
        }
        PreparedArtworkFallbackWarmup.prepare(name)
        return Image(name)
    }
}

public protocol PreparedArtworkReference {
    var imageName: String { get }
    var preparedThumbnailImageName: String? { get }
}

public extension PreparedArtworkReference {
    var preparedThumbnailImageName: String? {
        nil
    }
}

extension CombatantArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        thumbnailImageName
    }
}

extension AbilityArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        thumbnailImageName
    }
}

extension ItemArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        thumbnailImageName
    }
}

extension EncounterArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        thumbnailImageName
    }
}

extension BackgroundArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        thumbnailImageName
    }
}

extension SlotBackgroundArtReference: PreparedArtworkReference {}

extension ResourceArtReference: PreparedArtworkReference {}

extension TalentArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        thumbnailImageName
    }
}

public extension View {
    func decorativePreparedArtwork() -> some View {
        accessibilityHidden(true)
    }
}

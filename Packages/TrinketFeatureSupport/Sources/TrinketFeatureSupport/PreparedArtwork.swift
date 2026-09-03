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
    static var order: [String] = []
    private static let cap = 200
    static func shouldLog(_ name: String) -> Bool {
        guard !seen.contains(name) else { return false }
        if seen.count >= cap, !order.isEmpty {
            seen.remove(order.removeFirst())
        }
        seen.insert(name)
        order.append(name)
        return true
    }
}

/// Concurrency-Safety: `@unchecked Sendable` — `name` is a value type and `image` only crosses isolation through the main-actor cache.
struct PreparedArtwork: @unchecked Sendable {
    let name: String
    let image: UIImage?
}

public extension Image {
    enum PreparedArtworkDisplaySize: Sendable {
        case compact
        case full
    }

    @MainActor
    static func preparedAsset(
        _ reference: some PreparedArtworkReference,
        displaySize: PreparedArtworkDisplaySize,
    ) -> Image {
        let name = switch displaySize {
        case .compact:
            reference.preparedThumbnailImageName ?? reference.imageName
        case .full:
            reference.imageName
        }
        return preparedAsset(named: name)
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
        return Image(name)
    }
}

public protocol PreparedArtworkReference {
    var imageName: String { get }
    var preparedThumbnailImageName: String? { get }
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

extension SlotBackgroundArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        nil
    }
}

extension ResourceArtReference: PreparedArtworkReference {
    public var preparedThumbnailImageName: String? {
        nil
    }
}

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

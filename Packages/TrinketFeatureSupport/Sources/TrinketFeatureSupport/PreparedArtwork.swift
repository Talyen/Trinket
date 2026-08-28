import CoreGraphics
import SwiftUI
import TrinketContent
import UIKit

/// Concurrency-Safety: `@unchecked Sendable` — `name` is a value type and
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
        displaySize: PreparedArtworkDisplaySize
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
            Image(uiImage: image)
        } else {
            Image(name)
        }
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

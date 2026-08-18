import CoreGraphics
import SwiftUI
import TrinketContent
import UIKit

/// Concurrency-Safety: `@unchecked Sendable` — `name` is a value type and
/// `image` is immutable after `byPreparingForDisplay()`; task-group workers only
/// produce instances that the MainActor cache then retains.
struct PreparedArtwork: @unchecked Sendable {
    let name: String
    let image: UIImage?
}

public extension Image {
    /// Semantic render size for catalog references that may provide a thumbnail.
    enum PreparedArtworkDisplaySize: Sendable {
        case compact
        case full
    }

    /// Loads catalog artwork with an explicit display-size choice. Compact use
    /// prefers the generated thumbnail and safely falls back when none exists.
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

    /// Catalog artwork that prefers the launch-prepared bitmap cache.
    ///
    /// UIImage-backed prepared images become VoiceOver / XCUITest hits unless marked
    /// decorative. After `.resizable()` / framing, chain `.accessibilityHidden(true)`
    /// (or `.decorativePreparedArtwork()`) unless this image *is* the accessibility element.
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
    /// Marks prepared catalog art as decorative when a parent control owns accessibility.
    func decorativePreparedArtwork() -> some View {
        accessibilityHidden(true)
    }
}

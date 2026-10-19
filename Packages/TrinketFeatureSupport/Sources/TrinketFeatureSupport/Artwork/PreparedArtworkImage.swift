import SwiftUI
import TrinketDesignSystem

/// Resizable catalog artwork. Existing pins supply first paint; visible compact
/// artwork upgrades from the full source when its measured Retina size needs it.
public struct PreparedArtworkImage: View {
    @Environment(\.displayScale) private var displayScale
    @State private var requestName: String?
    @Environment(\.isDecorativeMotionActive) private var isPresentationActive
    @State private var pins = PreparedArtworkPinSet(
        acquire: { await Set(PreparedArtworkCache.shared.acquirePinnedArtwork(names: Array($0), priority: .viewport)) },
        release: { PreparedArtworkCache.shared.releasePins(names: Array($0)) },
    )

    private let imageName: String
    private let thumbnailName: String?
    private let displaySize: Image.PreparedArtworkDisplaySize
    private let magnification: CGFloat

    public init(
        _ reference: some PreparedArtworkReference,
        displaySize: Image.PreparedArtworkDisplaySize,
    ) {
        self.init(
            imageName: reference.imageName,
            thumbnailName: reference.preparedThumbnailImageName,
            displaySize: displaySize,
        )
    }

    public init(
        imageName: String,
        thumbnailName: String?,
        displaySize: Image.PreparedArtworkDisplaySize,
        magnification: CGFloat = 1,
    ) {
        self.imageName = imageName
        self.thumbnailName = thumbnailName
        self.displaySize = displaySize
        self.magnification = magnification
    }

    private var fallbackName: String {
        displaySize == .compact ? (thumbnailName ?? imageName) : imageName
    }

    private var activeRequestName: String? {
        guard isPresentationActive, displaySize == .compact,
              let requestName,
              ArtworkRasterRequest(cacheName: requestName)?.sourceName == imageName else { return nil }
        return requestName
    }

    private var renderedName: String {
        guard displaySize == .compact else { return imageName }
        if pins.names.contains(imageName) {
            return imageName
        }
        guard let requestName = activeRequestName, pins.names.contains(requestName) else { return fallbackName }
        return requestName
    }

    public var body: some View {
        Image.preparedAsset(named: renderedName)
            .resizable()
            .interpolation(.high)
            .onGeometryChange(for: String?.self) { geometry in
                guard displaySize == .compact, thumbnailName != nil else { return nil }
                if let viewport = geometry.bounds(of: .scrollView),
                   !viewport.intersects(CGRect(origin: .zero, size: geometry.size)) {
                    return nil
                }
                return ArtworkRasterRequest(
                    sourceName: imageName, pointSize: geometry.size,
                    displayScale: displayScale, magnification: magnification,
                )?.cacheName
            } action: { requestName = $0 }
            .task(id: activeRequestName) {
                guard let requestName = activeRequestName,
                      let request = ArtworkRasterRequest(cacheName: requestName)
                else {
                    pins.release()
                    return
                }
                // Already-sharp tiny icons retain their existing prepared thumbnail.
                if let fallback = PreparedArtworkCache.shared.image(named: fallbackName)?.cgImage,
                   max(fallback.width, fallback.height) >= request.pixelDimension {
                    pins.release()
                    return
                }
                if let full = PreparedArtworkCache.shared.image(named: imageName)?.cgImage,
                   max(full.width, full.height) <= request.pixelDimension {
                    await pins.prepare(names: [imageName])
                } else {
                    await pins.prepare(names: [requestName])
                }
            }
            .onDisappear { pins.release() }
    }
}

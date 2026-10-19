import Foundation

/// Cache identity includes the source and a bounded pixel bucket, never raw layout floats.
struct ArtworkRasterRequest: Equatable {
    private static let prefix = "@raster/"
    let sourceName: String
    let pixelDimension: Int

    init?(sourceName: String, pointSize: CGSize, displayScale: CGFloat, magnification: CGFloat = 1) {
        guard pointSize.width.isFinite, pointSize.height.isFinite,
              pointSize.width > 0, pointSize.height > 0,
              displayScale.isFinite, displayScale > 0,
              magnification.isFinite, magnification > 0 else { return nil }
        let pixels = max(pointSize.width, pointSize.height) * displayScale * magnification
        guard pixels.isFinite, pixels > 0 else { return nil }
        self.sourceName = sourceName
        pixelDimension = [128, 192, 256, 384, 512, 768, 1024, 1536, 2048, 3072, 4096]
            .first { CGFloat($0) >= pixels } ?? 4096
    }

    init?(cacheName: String) {
        guard cacheName.hasPrefix(Self.prefix) else { return nil }
        let parts = cacheName.dropFirst(Self.prefix.count).split(separator: "/", maxSplits: 1)
        guard parts.count == 2, let dimension = Int(parts[0]), (1 ... 4096).contains(dimension) else { return nil }
        sourceName = String(parts[1])
        pixelDimension = dimension
    }

    var cacheName: String {
        "\(Self.prefix)\(pixelDimension)/\(sourceName)"
    }
}

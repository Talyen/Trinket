import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Holds the compressed clips for one encounter, not decoded video frames.
enum BossIdleClipCache {
    static let byteLimit = 40 * 1024 * 1024

    enum Failure: Error {
        case empty, tooLarge
    }

    static func read(_ urls: [URL], byteLimit: Int = byteLimit) throws -> [Data] {
        guard !urls.isEmpty else { throw Failure.empty }
        guard byteLimit > 0 else { throw Failure.tooLarge }
        var result: [Data] = []
        var total = 0
        for url in urls {
            try Task.checkCancellation()
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size > 0, size <= byteLimit - total else {
                throw Failure.tooLarge
            }
            let data = try Data(contentsOf: url)
            guard data.count == size else { throw Failure.empty }
            total += data.count
            result.append(data)
        }
        try Task.checkCancellation()
        return result
    }
}

/// AVFoundation retains its delegate weakly, so the battle owns this alongside its asset.
/// Concurrency-Safety: the loader queue only reads immutable data; the asset is configured once and owned by the main-actor player.
final class BossIdleCachedAsset: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    let data: Data
    let asset: AVURLAsset
    private let loaderQueue = DispatchQueue(label: "trinket.boss-idle-resource")

    init?(data: Data, name: String) {
        guard !data.isEmpty, let url = URL(string: "trinket-boss-idle://clip/\(name).mp4") else { return nil }
        self.data = data
        asset = AVURLAsset(url: url)
        super.init()
        asset.resourceLoader.setDelegate(self, queue: loaderQueue)
    }

    func resourceLoader(_: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest) -> Bool {
        if let info = request.contentInformationRequest {
            info.contentType = UTType.mpeg4Movie.identifier
            info.contentLength = Int64(data.count)
            info.isByteRangeAccessSupported = true
        }
        if let requested = request.dataRequest {
            guard let range = Self.byteRange(
                offset: requested.currentOffset,
                requestedOffset: requested.requestedOffset,
                length: requested.requestedLength,
                toEnd: requested.requestsAllDataToEndOfResource,
                count: data.count,
            ) else {
                request.finishLoading(with: NSError(domain: "Trinket.BossIdle", code: 1))
                return true
            }
            if !range.isEmpty {
                requested.respond(with: data.subdata(in: range))
            }
        }
        request.finishLoading()
        return true
    }

    static func byteRange(offset: Int64, requestedOffset: Int64, length: Int, toEnd: Bool, count: Int) -> Range<Int>? {
        guard requestedOffset >= 0, offset >= 0, length >= 0, count >= 0,
              let start = Int(exactly: max(offset, requestedOffset)), start <= count else { return nil }
        if toEnd {
            return start ..< count
        }
        let (requestedEnd, overflow) = requestedOffset.addingReportingOverflow(Int64(length))
        guard !overflow, let end = Int(exactly: requestedEnd), end >= start else { return nil }
        return start ..< min(end, count)
    }
}

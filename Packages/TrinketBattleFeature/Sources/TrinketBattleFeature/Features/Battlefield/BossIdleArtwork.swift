import AVFoundation
import SwiftUI
import UIKit

/// Finished Alchemy clips are bundled as authored battle resources.
enum BossIdleCatalog {
    private static let blightTreant = clips(named: "blight-treant", count: 3)
    private static let forgeGolem = clips(named: "forge-golem", count: 3)
    private static let frostwarden = clips(named: "frostwarden", count: 3)
    private static let ironBear = clips(named: "iron-bear", count: 3)
    private static let bloodCountess = clips(named: "blood-countess", count: 5)
    private static let seraph = clips(named: "seraph", count: 3)
    private static let stoneTitan = clips(named: "stone-titan", count: 3)

    static func clips(for enemyID: String) -> [URL]? {
        switch enemyID {
        case "the_blight_treant": blightTreant
        case "the_forge_golem": forgeGolem
        case "the_frostwarden": frostwarden
        case "the_iron_bear": ironBear
        case "the_blood_countess": bloodCountess
        case "the_seraph": seraph
        case "the_stone_titan": stoneTitan
        default: nil
        }
    }

    private static func clips(named name: String, count: Int) -> [URL]? {
        let urls = (1 ... count).compactMap { number in
            Bundle.module.url(forResource: "\(name)-idle-\(number)-1280", withExtension: "mp4", subdirectory: "BossIdles")
        }
        return urls.count == count ? urls : nil
    }
}

/// Each shuffled round contains every clip, with no repeat at the round boundary.
struct BossIdleOrder {
    private let count: Int
    private var remaining: [Int] = []
    private var previous: Int?

    init(count: Int) {
        self.count = count
    }

    mutating func next() -> Int? {
        guard count > 0 else { return nil }
        if remaining.isEmpty {
            remaining = Array(0 ..< count).shuffled()
            if count > 1, remaining.last == previous {
                remaining.swapAt(0, count - 1)
            }
        }
        let result = remaining.removeLast()
        previous = result
        return result
    }
}

struct BossIdleArtwork: UIViewRepresentable {
    let clips: [URL]
    let isVisible: Bool
    let isForeground: Bool

    func makeUIView(context _: Context) -> BossIdlePlayerView {
        let view = BossIdlePlayerView()
        view.prepare(clips: clips, isVisible: isVisible, isForeground: isForeground)
        return view
    }

    func updateUIView(_ view: BossIdlePlayerView, context _: Context) {
        view.updatePresentation(isVisible: isVisible, isForeground: isForeground)
    }

    static func dismantleUIView(_ view: BossIdlePlayerView, coordinator _: ()) {
        view.stop()
    }
}

/// The outgoing frame stays on screen until the next layer has a displayable frame.
struct BossIdleHandoff {
    enum Action: Equatable {
        case show(Int)
        case transition(from: Int, to: Int)
    }

    private(set) var active: Int?
    private var ready = [false, false]
    private var reachedSeam = false

    mutating func markReady(_ slot: Int) -> Action? {
        guard ready.indices.contains(slot) else { return nil }
        ready[slot] = true
        if active == nil, slot == 0 {
            active = 0
            return .show(0)
        }
        return transitionIfReady()
    }

    mutating func markSeam(_ slot: Int) -> Action? {
        guard active == slot else { return nil }
        reachedSeam = true
        return transitionIfReady()
    }

    mutating func reset(_ slot: Int) {
        guard ready.indices.contains(slot) else { return }
        ready[slot] = false
    }

    private mutating func transitionIfReady() -> Action? {
        guard reachedSeam, let current = active, ready[1 - current] else { return nil }
        let next = 1 - current
        reachedSeam = false
        active = next
        return .transition(from: current, to: next)
    }
}

@MainActor
final class BossIdlePlayerView: UIView {
    private final class Slot {
        var id = UUID()
        let player = AVPlayer()
        var layer = AVPlayerLayer()
        var readyObservation: NSKeyValueObservation?
        var statusObservation: NSKeyValueObservation?
        var seamObserver: Any?
        var endObserver: NSObjectProtocol?
        var failureObserver: NSObjectProtocol?

        func reset() {
            invalidate()
            id = UUID()
            // A fresh layer cannot report the previous clip's display readiness.
            layer = AVPlayerLayer()
        }

        func invalidate() {
            readyObservation = nil
            statusObservation = nil
            if let seamObserver {
                player.removeTimeObserver(seamObserver)
                self.seamObserver = nil
            }
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            if let failureObserver {
                NotificationCenter.default.removeObserver(failureObserver)
            }
            player.pause()
            player.replaceCurrentItem(with: nil)
            layer.player = nil
            layer.removeFromSuperlayer()
        }
    }

    private var clips: [URL] = []
    private var cachedAssets: [(cached: BossIdleCachedAsset, duration: CMTime)] = []
    private var slots: [Slot?] = [nil, nil]
    private var order = BossIdleOrder(count: 0)
    private var handoff = BossIdleHandoff()
    private var preparation: Task<Void, Never>?
    private var recycle: Task<Void, Never>?
    private var memoryObserver: NSObjectProtocol?
    private var shouldPlay = false
    private var memoryPressure = false
    private var generation = 0
    private static let overlap: TimeInterval = 0.14
    private static let dissolve: TimeInterval = 0.10

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.memoryPressure = true
                self?.clearPlayback()
            }
        }
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard slots.contains(where: { $0.map { $0.layer.frame != bounds } ?? false }) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for slot in slots where slot?.layer.frame != bounds {
            slot?.layer.frame = bounds
        }
        CATransaction.commit()
    }

    func prepare(clips: [URL], isVisible: Bool, isForeground: Bool) {
        self.clips = clips
        updatePresentation(isVisible: isVisible, isForeground: isForeground)
    }

    func updatePresentation(isVisible: Bool, isForeground: Bool) {
        let shouldPlay = isVisible && isForeground
        guard self.shouldPlay != shouldPlay else { return }
        self.shouldPlay = shouldPlay
        if shouldPlay {
            if let index = handoff.active {
                slots[index]?.player.play()
            } else {
                start()
            }
        } else {
            // Retain the decoded frame, clip order, and standby item across app switches.
            for slot in slots {
                slot?.player.pause()
            }
        }
    }

    func stop() {
        shouldPlay = false
        clearPlayback()
        if let memoryObserver {
            NotificationCenter.default.removeObserver(memoryObserver)
        }
        memoryObserver = nil
        clips.removeAll()
    }

    private func start() {
        guard preparation == nil, cachedAssets.isEmpty, !clips.isEmpty, !memoryPressure else { return }
        generation += 1
        let expectedGeneration = generation
        let urls = clips
        let reader = Task.detached(priority: .userInitiated) { try BossIdleClipCache.read(urls) }
        preparation = Task { [weak self] in
            do {
                let data = try await withTaskCancellationHandler {
                    try await reader.value
                } onCancel: {
                    reader.cancel()
                }
                try Task.checkCancellation()
                let cacheID = UUID().uuidString
                let assets = data.enumerated().compactMap { BossIdleCachedAsset(data: $0.element, name: "\(cacheID)-clip-\($0.offset)") }
                guard assets.count == data.count else { throw BossIdleClipCache.Failure.empty }
                var prepared: [(cached: BossIdleCachedAsset, duration: CMTime)] = []
                for asset in assets {
                    guard try await asset.asset.load(.isPlayable) else { throw BossIdleClipCache.Failure.empty }
                    let (duration, _) = try await asset.asset.load(.duration, .tracks)
                    prepared.append((asset, duration))
                    try Task.checkCancellation()
                }
                guard let self, generation == expectedGeneration else { return }
                preparation = nil
                cachedAssets = prepared
                order = BossIdleOrder(count: prepared.count)
                handoff = BossIdleHandoff()
                prepareSlot(0)
                prepareSlot(1)
            } catch {
                guard let self, generation == expectedGeneration else { return }
                clearPlayback()
            }
        }
    }

    private func prepareSlot(_ index: Int) {
        guard let clip = order.next(), cachedAssets.indices.contains(clip) else { return }
        handoff.reset(index)
        let slot = slots[index] ?? Slot()
        slot.reset()
        let id = slot.id
        slots[index] = slot
        slot.player.isMuted = true
        slot.player.actionAtItemEnd = .pause
        slot.layer.videoGravity = .resizeAspectFill
        slot.layer.frame = bounds
        slot.layer.opacity = 0
        slot.layer.player = slot.player
        layer.addSublayer(slot.layer)
        let asset = cachedAssets[clip]
        let item = AVPlayerItem(asset: asset.cached.asset)
        slot.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.itemReachedSeam(index, id: id) }
        }
        slot.failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.itemFailed(index, id: id) }
        }
        slot.statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in self?.itemFailed(index, id: id) }
        }
        slot.readyObservation = slot.layer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            Task { @MainActor [weak self] in self?.itemReady(index, id: id) }
        }
        slot.player.replaceCurrentItem(with: item)
        let seam = asset.duration.seconds - Self.overlap
        if seam.isFinite, seam > 0 {
            let time = CMTime(seconds: seam, preferredTimescale: 600)
            slot.seamObserver = slot.player.addBoundaryTimeObserver(forTimes: [NSValue(time: time)], queue: .main) { [weak self] in
                MainActor.assumeIsolated { self?.itemReachedSeam(index, id: id) }
            }
        }
    }

    private func itemReady(_ index: Int, id: UUID) {
        guard slots[index]?.id == id else { return }
        perform(handoff.markReady(index))
    }

    private func itemReachedSeam(_ index: Int, id: UUID) {
        guard slots[index]?.id == id else { return }
        perform(handoff.markSeam(index))
    }

    private func itemFailed(_ index: Int, id: UUID) {
        guard slots[index]?.id == id else { return }
        clearPlayback()
    }

    private func perform(_ action: BossIdleHandoff.Action?) {
        switch action {
        case let .show(index):
            guard let slot = slots[index] else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            slot.layer.opacity = 1
            CATransaction.commit()
            if shouldPlay {
                slot.player.play()
            }
        case let .transition(from, to):
            guard let outgoing = slots[from], let incoming = slots[to] else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            outgoing.layer.zPosition = 0
            incoming.layer.zPosition = 1
            incoming.layer.opacity = 1
            if shouldPlay {
                fadeIn(incoming.layer)
            }
            CATransaction.commit()
            if shouldPlay {
                incoming.player.play()
            }
            let expectedGeneration = generation
            recycle?.cancel()
            recycle = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.dissolve))
                guard !Task.isCancelled, let self, generation == expectedGeneration else { return }
                prepareSlot(from)
            }
        case nil:
            break
        }
    }

    private func fadeIn(_ layer: AVPlayerLayer) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = Self.dissolve
        layer.add(fade, forKey: "boss-idle-crossfade")
    }

    private func clearPlayback() {
        generation += 1
        preparation?.cancel()
        preparation = nil
        recycle?.cancel()
        recycle = nil
        for slot in slots {
            slot?.invalidate()
        }
        slots = [nil, nil]
        cachedAssets.removeAll()
        handoff = BossIdleHandoff()
    }
}

import AVFoundation
import SwiftUI
import UIKit

/// Finished Alchemy clips are bundled as authored battle resources.
enum BossIdleCatalog {
    static func clips(for enemyID: String) -> [URL]? {
        let entry: (String, Int)? = switch enemyID {
        case "the_blight_treant": ("blight-treant", 3)
        case "the_forge_golem": ("forge-golem", 3)
        case "the_frostwarden": ("frostwarden", 3)
        case "the_iron_bear": ("iron-bear", 3)
        case "the_blood_countess": ("blood-countess", 5)
        case "the_seraph": ("seraph", 3)
        case "the_stone_titan": ("stone-titan", 3)
        default: nil
        }
        guard let (name, count) = entry else { return nil }
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

    init(count: Int, previous: Int? = nil) {
        self.count = count
        self.previous = previous
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
    let isActive: Bool

    func makeUIView(context _: Context) -> BossIdlePlayerView {
        let view = BossIdlePlayerView()
        view.prepare(clips: clips, isActive: isActive)
        return view
    }

    func updateUIView(_ view: BossIdlePlayerView, context _: Context) {
        view.setActive(isActive)
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
    private var ended = false

    mutating func markReady(_ slot: Int) -> Action? {
        guard ready.indices.contains(slot) else { return nil }
        ready[slot] = true
        if active == nil, slot == 0 {
            active = 0
            return .show(0)
        }
        return transitionIfReady()
    }

    mutating func markEnded(_ slot: Int) -> Action? {
        guard active == slot else { return nil }
        ended = true
        return transitionIfReady()
    }

    mutating func reset(_ slot: Int) {
        guard ready.indices.contains(slot) else { return }
        ready[slot] = false
    }

    private mutating func transitionIfReady() -> Action? {
        guard ended, let current = active, ready[1 - current] else { return nil }
        let next = 1 - current
        ended = false
        active = next
        return .transition(from: current, to: next)
    }
}

@MainActor
final class BossIdlePlayerView: UIView {
    private final class Slot {
        let id = UUID()
        let clip: Int
        let player = AVPlayer()
        let layer = AVPlayerLayer()
        var readyObservation: NSKeyValueObservation?
        var statusObservation: NSKeyValueObservation?
        var endObserver: NSObjectProtocol?
        var failureObserver: NSObjectProtocol?

        init(clip: Int) {
            self.clip = clip
        }

        func invalidate() {
            readyObservation = nil
            statusObservation = nil
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
    private var cachedAssets: [BossIdleCachedAsset] = []
    private var slots: [Slot?] = [nil, nil]
    private var order = BossIdleOrder(count: 0)
    private var handoff = BossIdleHandoff()
    private var preparation: Task<Void, Never>?
    private var recycle: Task<Void, Never>?
    private var memoryObserver: NSObjectProtocol?
    private var active = false
    private var memoryPressure = false
    private var generation = 0
    private var lastDisplayedClip: Int?

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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for slot in slots {
            slot?.layer.frame = bounds
        }
        CATransaction.commit()
    }

    func prepare(clips: [URL], isActive: Bool) {
        self.clips = clips
        active = isActive
        if active {
            start()
        }
    }

    func setActive(_ isActive: Bool) {
        guard active != isActive else { return }
        active = isActive
        if active, !memoryPressure {
            start()
        } else {
            clearPlayback()
        }
    }

    func stop() {
        active = false
        clearPlayback()
        if let memoryObserver {
            NotificationCenter.default.removeObserver(memoryObserver)
        }
        memoryObserver = nil
        clips.removeAll()
    }

    private func start() {
        guard preparation == nil, !clips.isEmpty, !memoryPressure else { return }
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
                for asset in assets {
                    guard try await asset.asset.load(.isPlayable) else { throw BossIdleClipCache.Failure.empty }
                    _ = try await asset.asset.load(.duration, .tracks)
                    try Task.checkCancellation()
                }
                guard let self, active, generation == expectedGeneration else { return }
                cachedAssets = assets
                order = BossIdleOrder(count: assets.count, previous: lastDisplayedClip)
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
        guard active, let clip = order.next(), cachedAssets.indices.contains(clip) else { return }
        slots[index]?.invalidate()
        handoff.reset(index)
        let slot = Slot(clip: clip)
        let id = slot.id
        slots[index] = slot
        slot.player.isMuted = true
        slot.player.actionAtItemEnd = .pause
        slot.layer.videoGravity = .resizeAspectFill
        slot.layer.frame = bounds
        slot.layer.opacity = 0
        slot.layer.player = slot.player
        layer.addSublayer(slot.layer)
        let item = AVPlayerItem(asset: cachedAssets[clip].asset)
        slot.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.itemEnded(index, id: id) }
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
    }

    private func itemReady(_ index: Int, id: UUID) {
        guard active, slots[index]?.id == id else { return }
        perform(handoff.markReady(index))
    }

    private func itemEnded(_ index: Int, id: UUID) {
        guard active, slots[index]?.id == id else { return }
        perform(handoff.markEnded(index))
    }

    private func itemFailed(_ index: Int, id: UUID) {
        guard slots[index]?.id == id else { return }
        clearPlayback()
    }

    private func perform(_ action: BossIdleHandoff.Action?) {
        switch action {
        case let .show(index):
            guard let slot = slots[index] else { return }
            lastDisplayedClip = slot.clip
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            slot.layer.opacity = 1
            CATransaction.commit()
            fadeIn(slot.layer)
            slot.player.play()
        case let .transition(from, to):
            guard let outgoing = slots[from], let incoming = slots[to] else { return }
            lastDisplayedClip = incoming.clip
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            outgoing.layer.zPosition = 0
            incoming.layer.zPosition = 1
            incoming.layer.opacity = 1
            CATransaction.commit()
            fadeIn(incoming.layer)
            incoming.player.play()
            let expectedGeneration = generation
            recycle?.cancel()
            recycle = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled, let self, active, generation == expectedGeneration else { return }
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
        fade.duration = 0.18
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

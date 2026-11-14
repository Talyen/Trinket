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

    /// Mean luma differences in the central 4:3 crop at 0.03 and 0.08 seconds
    /// into a 0.14-second overlap. Rows are outgoing; columns are incoming.
    static func seamScores(for clips: [URL]) -> [[Double]]? {
        guard let name = clips.first?.lastPathComponent.components(separatedBy: "-idle-").first else { return nil }
        switch name {
        case "blight-treant": return [[0, 22.07, 21.96], [5.75, 0, 5.92], [6.40, 6.46, 0]]
        case "forge-golem": return [[0, 2.69, 2.72], [2.57, 0, 2.62], [3.25, 3.15, 0]]
        case "frostwarden": return [[0, 14.26, 14.19], [14.36, 0, 14.21], [15.70, 15.57, 0]]
        case "iron-bear": return [[0, 12.81, 12.76], [11.72, 0, 12.10], [11.68, 12.06, 0]]
        case "blood-countess": return [
                [0, 12.45, 13.18, 12.02, 12.22], [14.20, 0, 14.93, 13.85, 13.97],
                [14.22, 14.25, 0, 13.88, 13.96], [13.50, 13.57, 14.19, 0, 13.27],
                [13.83, 14.00, 14.51, 13.59, 0],
            ]
        case "seraph": return [[0, 10.31, 12.18], [6.90, 0, 6.76], [8.49, 7.66, 0]]
        case "stone-titan": return [[0, 5.60, 5.79], [6.27, 0, 6.17], [5.96, 5.68, 0]]
        default: return nil
        }
    }

    private static func clips(named name: String, count: Int) -> [URL]? {
        let urls = (1 ... count).compactMap { number in
            Bundle.module.url(forResource: "\(name)-idle-\(number)-1280", withExtension: "mp4", subdirectory: "BossIdles")
        }
        return urls.count == count ? urls : nil
    }
}

/// Each round contains every clip, preferring closer matches without adjacent repeats.
struct BossIdleOrder {
    private let count: Int
    private let scores: [[Double]]?
    private var remaining: [Int] = []
    private var previous: Int?
    private var initial: Int?

    init(count: Int, scores: [[Double]]? = nil, initial: Int? = nil) {
        self.count = count
        self.initial = initial.flatMap { (0 ..< count).contains($0) ? $0 : nil }
        self.scores = scores?.count == count && scores?.allSatisfy { $0.count == count } == true ? scores : nil
    }

    mutating func next() -> Int? {
        guard count > 0 else { return nil }
        if remaining.isEmpty {
            remaining = Array(0 ..< count).shuffled()
        }
        if let initial {
            self.initial = nil
            remaining.removeAll { $0 == initial }
            previous = initial
            return initial
        }
        let eligible = remaining.filter { count == 1 || $0 != previous }
        let candidates = eligible.isEmpty ? remaining : eligible
        var choices = candidates
        if let previous, let scores, let best = candidates.map({ scores[previous][$0] }).min() {
            // Preserve variety among near-equivalent handoffs.
            choices = candidates.filter { scores[previous][$0] <= best * 1.05 }
        }
        guard let result = choices.randomElement() else { return nil }
        remaining.removeAll { $0 == result }
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
        var playingObservation: NSKeyValueObservation?
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
            playingObservation = nil
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

    private let poster = UIImageView()
    private var clips: [URL] = []
    private var cachedAssets: [(cached: BossIdleCachedAsset, duration: CMTime)] = []
    private var slots: [Slot?] = [nil, nil]
    private var order = BossIdleOrder(count: 0)
    private var handoff = BossIdleHandoff()
    private var preparation: Task<Void, Never>?
    private var recycle: Task<Void, Never>?
    private var pendingTransition: (from: Int, to: Int, id: UUID)?
    private var memoryObserver: NSObjectProtocol?
    private var shouldPlay = false
    private var memoryPressure = false
    private var generation = 0
    private static let overlap: TimeInterval = 0.14
    private static let dissolve: TimeInterval = 0.10

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .black
        poster.contentMode = .scaleAspectFill
        poster.clipsToBounds = true
        addSubview(poster)
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
        poster.frame = bounds
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
        if let first = clips.first {
            let path = first.deletingPathExtension().path + "-first.png"
            poster.image = UIImage(contentsOfFile: path)
        }
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
                order = BossIdleOrder(count: prepared.count, scores: BossIdleCatalog.seamScores(for: urls), initial: 0)
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
        slot.playingObservation = slot.player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard player.timeControlStatus == .playing else { return }
            Task { @MainActor [weak self] in self?.itemPlaying(index, id: id) }
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
            guard let incoming = slots[to] else { return }
            pendingTransition = (from, to, incoming.id)
            if shouldPlay {
                incoming.player.play()
                if incoming.player.timeControlStatus == .playing {
                    itemPlaying(to, id: incoming.id)
                }
            }
        case nil:
            break
        }
    }

    private func itemPlaying(_ index: Int, id: UUID) {
        guard shouldPlay, let pending = pendingTransition, pending.to == index, pending.id == id,
              let outgoing = slots[pending.from], let incoming = slots[index], incoming.id == id else { return }
        pendingTransition = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outgoing.layer.zPosition = 0
        incoming.layer.zPosition = 1
        incoming.layer.opacity = 1
        fadeIn(incoming.layer)
        CATransaction.commit()
        let expectedGeneration = generation
        recycle?.cancel()
        recycle = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.dissolve))
            guard !Task.isCancelled, let self, generation == expectedGeneration else { return }
            prepareSlot(pending.from)
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
        pendingTransition = nil
        for slot in slots {
            slot?.invalidate()
        }
        slots = [nil, nil]
        cachedAssets.removeAll()
        handoff = BossIdleHandoff()
    }
}

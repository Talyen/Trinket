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

@MainActor
final class BossIdlePlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private let player = AVQueuePlayer()
    private var assets: [AVURLAsset] = []
    private var order = BossIdleOrder(count: 0)
    private var observers: [UUID: [NSObjectProtocol]] = [:]
    private var preparation: Task<Void, Never>?
    private var active = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        player.isMuted = true
        player.actionAtItemEnd = .advance
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.player = player
        layer.addSublayer(playerLayer)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func prepare(clips: [URL], isActive: Bool) {
        active = isActive
        preparation = Task { [weak self] in
            let prepared = clips.map { AVURLAsset(url: $0) }
            do {
                for asset in prepared {
                    guard try await asset.load(.isPlayable) else { return }
                    _ = try await asset.load(.duration, .tracks)
                }
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            assets = prepared
            order = BossIdleOrder(count: prepared.count)
            for _ in prepared {
                enqueueNext()
            }
            if active {
                player.play()
            }
        }
    }

    func setActive(_ isActive: Bool) {
        active = isActive
        if isActive, !assets.isEmpty {
            player.play()
        } else {
            player.pause()
        }
    }

    func stop() {
        preparation?.cancel()
        preparation = nil
        player.pause()
        player.removeAllItems()
        for tokens in observers.values {
            for token in tokens {
                NotificationCenter.default.removeObserver(token)
            }
        }
        observers.removeAll()
        assets.removeAll()
        playerLayer.player = nil
    }

    private func enqueueNext() {
        guard let index = order.next() else { return }
        let item = AVPlayerItem(asset: assets[index])
        let id = UUID()
        let finished = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let tokens = observers.removeValue(forKey: id) else { return }
                for token in tokens {
                    NotificationCenter.default.removeObserver(token)
                }
                enqueueNext()
            }
        }
        let failed = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, observers[id] != nil else { return }
                stop()
            }
        }
        observers[id] = [finished, failed]
        player.insert(item, after: nil)
    }
}

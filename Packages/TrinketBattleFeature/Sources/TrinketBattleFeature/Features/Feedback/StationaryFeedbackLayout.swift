import CoreGraphics
import Foundation

struct StationaryFeedbackLayout {
    static let sizeScale = 1.2
    static let popDuration: TimeInterval = 0.14
    static let initialScale = 0.75
    static let peakScale = 1.9
    static let finalScale = 1.3
    static let holdDuration: TimeInterval = 0.15
    static let shrinkDuration: TimeInterval = 1.10
    static let driftDistance: CGFloat = 32
    static let pushDuration: TimeInterval = 0.18
    static let fadeDuration: TimeInterval = 0.50
    static let mergePulseDuration: TimeInterval = 0.18
    static let mergePulseScale = 1.10
    static let shineDuration: TimeInterval = 0.45
    static let shrinkStart = popDuration + holdDuration
    static let lifetime = shrinkStart + shrinkDuration
    static let fadeStart = lifetime - fadeDuration

    struct Slot: Equatable {
        let id: Int
        var rect: CGRect
        let fitScale: CGFloat
    }

    private(set) var slots: [Slot] = []
    private(set) var bounds: CGRect = .zero

    mutating func retain(ids: Set<Int>, in bounds: CGRect) {
        if self.bounds != bounds {
            slots.removeAll()
            self.bounds = bounds
        }
        slots.removeAll { !ids.contains($0.id) }
    }

    mutating func place(id: Int, size: CGSize) -> Slot? {
        if let slot = slots.first(where: { $0.id == id }) {
            return slot
        }
        let area = bounds.insetBy(dx: 8, dy: 8)
        guard area.width > 0, area.height > 0, size.width > 0, size.height > 0 else { return nil }
        let fit = min(1, area.width / size.width, area.height / size.height)
        let fitted = CGSize(width: min(area.width, size.width * fit), height: min(area.height, size.height * fit))
        let pushDistance = max(fitted.height, slots.map(\.rect.height).max() ?? 0) * Self.peakScale * 0.5
        for index in slots.indices {
            slots[index].rect = slots[index].rect.offsetBy(dx: 0, dy: -pushDistance)
        }
        let rect = CGRect(
            x: area.midX - fitted.width / 2, y: area.midY - fitted.height / 2,
            width: fitted.width, height: fitted.height,
        )
        let slot = Slot(id: id, rect: rect, fitScale: fit)
        slots.append(slot)
        return slot
    }

    static func edgeOpacity(centerY: CGFloat, in bounds: CGRect) -> Double {
        let fadeHeight = min(40, bounds.height * 0.25)
        guard fadeHeight > 0 else { return 0 }
        let progress = min(1, max(0, (centerY - bounds.minY - 8) / fadeHeight))
        return Double(progress * progress * (3 - 2 * progress))
    }
}

struct StationaryFeedbackPush {
    private var from: CGFloat = 0
    private var target: CGFloat = 0
    private var startedAt: TimeInterval = 0

    /// Item-relative time freezes on suspension and survives shifted scheduling dates.
    func offset(at elapsed: TimeInterval) -> CGFloat {
        let progress = min(1, max(0, (elapsed - startedAt) / StationaryFeedbackLayout.pushDuration))
        let remaining = 1 - progress
        return from + (target - from) * (1 - remaining * remaining * remaining)
    }

    mutating func retarget(to offset: CGFloat, at elapsed: TimeInterval) {
        guard offset != target else { return }
        from = self.offset(at: elapsed)
        target = offset
        startedAt = elapsed
    }
}

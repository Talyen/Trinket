import CoreGraphics
import Foundation

struct StationaryFeedbackLayout {
    static let sizeScale = 1.2
    static let peakScale = 1.9
    static let pushDuration: TimeInterval = 0.18
    static let mergePulseScale = 1.10

    struct Slot: Equatable {
        let id: Int
        let region: CombatFeedbackRegion
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

    mutating func place(id: Int, size: CGSize, region: CombatFeedbackRegion = .impact) -> Slot? {
        if let slot = slots.first(where: { $0.id == id }) {
            return slot
        }
        let area = Self.area(for: region, in: bounds)
        guard area.width > 0, area.height > 0, size.width > 0, size.height > 0 else { return nil }
        let fittingArea = bounds.insetBy(dx: 8, dy: 8)
        let fit = min(1, fittingArea.width / size.width, fittingArea.height / size.height)
        let fitted = CGSize(width: size.width * fit, height: size.height * fit)
        let pushDistance = max(fitted.height, slots.filter { $0.region == region }.map(\.rect.height).max() ?? 0)
            * Self.peakScale * 0.5
        for index in slots.indices where slots[index].region == region {
            slots[index].rect = slots[index].rect.offsetBy(dx: 0, dy: -pushDistance)
        }
        let peakHalfWidth = min(fittingArea.width / 2, fitted.width * Self.peakScale * Self.mergePulseScale / 2)
        let centerX = min(fittingArea.maxX - peakHalfWidth, max(fittingArea.minX + peakHalfWidth, area.midX))
        let rect = CGRect(
            x: centerX - fitted.width / 2, y: area.midY - fitted.height / 2,
            width: fitted.width, height: fitted.height,
        )
        let slot = Slot(id: id, region: region, rect: rect, fitScale: fit)
        slots.append(slot)
        return slot
    }

    static func area(for region: CombatFeedbackRegion, in bounds: CGRect) -> CGRect {
        let inset = bounds.insetBy(dx: 8, dy: 8)
        guard region != .impact else { return inset }
        let width = max(0, (inset.width - 8) / 2)
        let height = max(0, bounds.height * 0.36)
        return CGRect(
            x: region == .benefit ? inset.minX : inset.maxX - width,
            y: inset.maxY - height,
            width: width,
            height: height,
        )
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

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
        let initialCenterY: CGFloat
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
        let fittingArea = bounds.insetBy(dx: 8, dy: 8)
        guard fittingArea.width > 0, fittingArea.height > 0, size.width > 0, size.height > 0 else { return nil }
        let maximumScale = Self.peakScale * Self.mergePulseScale
        let fit = min(1, fittingArea.width / (size.width * maximumScale), fittingArea.height / (size.height * maximumScale))
        let fitted = CGSize(width: size.width * fit, height: size.height * fit)
        let pushDistance = max(fitted.height, slots.filter { $0.region == region }.map(\.rect.height).max() ?? 0)
            * Self.peakScale * 0.5
        for index in slots.indices where slots[index].region == region {
            slots[index].rect = slots[index].rect.offsetBy(dx: 0, dy: -pushDistance)
        }
        let centerY = region == .impact ? bounds.midY : fittingArea.maxY - fitted.height / 2
        let centerX = switch region {
        case .impact: bounds.midX
        case .benefit: fittingArea.minX + fitted.width / 2
        case .setback: fittingArea.maxX - fitted.width / 2
        }
        let rect = CGRect(
            x: centerX - fitted.width / 2, y: centerY - fitted.height / 2,
            width: fitted.width, height: fitted.height,
        )
        let slot = Slot(id: id, region: region, rect: rect, fitScale: fit, initialCenterY: centerY)
        slots.append(slot)
        return slot
    }

    func position(for slot: Slot, renderedSize: CGSize, push: CGFloat, rise: CGFloat, bottomInset: CGFloat) -> CGPoint {
        let inset = bounds.insetBy(dx: 8, dy: 8)
        let halfWidth = renderedSize.width / 2
        let x = switch slot.region {
        case .impact: bounds.midX
        case .benefit: inset.minX + halfWidth
        case .setback: inset.maxX - halfWidth
        }
        let y = slot.region == .impact ? bounds.midY : inset.maxY - bottomInset - renderedSize.height / 2
        return CGPoint(x: x, y: y - push - rise)
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

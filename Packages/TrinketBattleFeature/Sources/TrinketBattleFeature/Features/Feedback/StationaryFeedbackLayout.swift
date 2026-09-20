import CoreGraphics
import Foundation

struct StationaryFeedbackLayout {
    static let clusterCapacity = 5
    static let sizeScale = 1.2
    static let popDuration: TimeInterval = 0.07
    static let settleDuration: TimeInterval = 0.09
    static let peakScale = 2.3
    static let largeScale = 2.0
    static let holdDuration: TimeInterval = 0.50
    static let shrinkDuration: TimeInterval = 0.35
    static let fadeDuration: TimeInterval = 0.25
    static let mergePulseDuration: TimeInterval = 0.18
    static let mergePulseScale = 1.10
    static let shineDuration: TimeInterval = 0.25
    static let holdStart = popDuration + settleDuration
    static let shrinkStart = holdStart + holdDuration
    static let fadeStart = shrinkStart + shrinkDuration
    static let lifetime = fadeStart + fadeDuration

    struct Slot: Equatable {
        let id: Int
        let rect: CGRect
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

    mutating func place(id: Int, size: CGSize) -> (slot: Slot, evicted: Set<Int>)? {
        if let slot = slots.first(where: { $0.id == id }) {
            return (slot, [])
        }
        let area = bounds.insetBy(dx: 8, dy: 8)
        guard area.width > 0, area.height > 0, size.width > 0, size.height > 0 else { return nil }
        let fit = min(1, area.width / size.width, area.height / size.height)
        let fitted = CGSize(width: min(area.width, size.width * fit), height: min(area.height, size.height * fit))
        var evicted: Set<Int> = []
        while true {
            if slots.count < Self.clusterCapacity, let rect = clusteredRect(size: fitted, in: area) {
                let slot = Slot(id: id, rect: rect, fitScale: fit)
                slots.append(slot)
                return (slot, evicted)
            }
            guard !slots.isEmpty else { return nil }
            evicted.insert(slots.removeFirst().id)
        }
    }

    private func clusteredRect(size: CGSize, in area: CGRect) -> CGRect? {
        let offsets: [CGPoint] = [
            .zero,
            CGPoint(x: -0.6, y: -0.9),
            CGPoint(x: 0.6, y: 0.9),
            CGPoint(x: 0.6, y: -0.9),
            CGPoint(x: -0.6, y: 0.9),
        ]
        for offset in offsets {
            let x = min(area.maxX - size.width / 2, max(area.minX + size.width / 2, area.midX + offset.x * size.height))
            let y = min(area.maxY - size.height / 2, max(area.minY + size.height / 2, area.midY + offset.y * size.height))
            // Allow glyph overlap, but keep distinct centers even when portrait fitting clamps offsets.
            guard slots.allSatisfy({ slot in
                let separation = min(size.height, slot.rect.height) * 0.5
                return hypot(x - slot.rect.midX, y - slot.rect.midY) >= separation
            }) else { continue }
            return CGRect(x: x - size.width / 2, y: y - size.height / 2, width: size.width, height: size.height)
        }
        return nil
    }
}

import CoreGraphics
import Foundation

struct StationaryFeedbackLayout {
    static let shrinkDuration: TimeInterval = 0.25
    static let lifetime: TimeInterval = 0.5

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
            if let rect = nearestRect(size: fitted, in: area) {
                let slot = Slot(id: id, rect: rect, fitScale: fit)
                slots.append(slot)
                return (slot, evicted)
            }
            guard !slots.isEmpty else { return nil }
            evicted.insert(slots.removeFirst().id)
        }
    }

    private func nearestRect(size: CGSize, in area: CGRect) -> CGRect? {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let minX = area.minX + halfWidth
        let maxX = area.maxX - halfWidth
        let minY = area.minY + halfHeight
        let maxY = area.maxY - halfHeight
        let obstacles = slots.map { $0.rect.insetBy(dx: -6, dy: -6) }
        // The nearest feasible center lies at the portrait center, a boundary,
        // or an expanded obstacle edge. Their Cartesian product covers corners.
        let xs = [area.midX, minX, maxX] + obstacles.flatMap { [$0.minX - halfWidth, $0.maxX + halfWidth] }
        let ys = [area.midY, minY, maxY] + obstacles.flatMap { [$0.minY - halfHeight, $0.maxY + halfHeight] }
        var best: CGRect?
        var bestDistance = CGFloat.infinity
        for y in Set(ys).sorted() where y >= minY && y <= maxY {
            for x in Set(xs).sorted() where x >= minX && x <= maxX {
                let rect = CGRect(x: x - halfWidth, y: y - halfHeight, width: size.width, height: size.height)
                guard !obstacles.contains(where: { obstacle in
                    let overlap = obstacle.intersection(rect)
                    return !overlap.isNull && overlap.width > 0.001 && overlap.height > 0.001
                }) else { continue }
                let distance = pow(x - area.midX, 2) + pow(y - area.midY, 2)
                if distance < bestDistance {
                    best = rect
                    bestDistance = distance
                }
            }
        }
        return best
    }
}

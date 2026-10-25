import CoreGraphics
import Foundation
import SwiftUI
import TrinketDesignSystem

extension EnvironmentValues {
    @Entry var balancedCombatFeedback = true
}

/// Bounded independent feedback. The debug comparison can still select the legacy renderer.
enum BalancedFeedbackMotion {
    static let maximumQueueDelay: TimeInterval = 0.18
    static let nearbyWindow: TimeInterval = 0.36
    static func state(for item: CombatFeedbackItem, at date: Date) -> CombatFeedbackAnimationState {
        if item.region != .impact {
            return CombatFeedbackMotionSampler.state(for: item, at: date)
        }
        let elapsed = max(0, (item.pausedAt ?? date).timeIntervalSince(item.firstScheduledAt))
        let pop = 0.9 + (1.85 - 0.9) * (1 - pow(1 - min(1, elapsed / 0.085), 3))
        let settle = 1.85 + (1.55 - 1.85) * BattleMotion.smoothProgress((elapsed - 0.085) / 0.085)
        let shrink = 1.55 + (1.2 - 1.55) * BattleMotion.smoothProgress((elapsed - 0.17) / 0.76)
        return CombatFeedbackAnimationState(
            opacity: 1 - BattleMotion.smoothProgress((elapsed - 0.77) / 0.28),
            scale: elapsed < 0.085 ? pop : elapsed < 0.17 ? settle : shrink,
            riseProgress: 1 - pow(1 - min(1, max(0, (elapsed - 0.24) / 0.81)), 3),
            shineProgress: min(1, elapsed / 0.45),
        )
    }

    @MainActor
    static func schedule(
        _ incoming: CombatFeedbackItem, at date: Date, previous: [CombatFeedbackItem],
        bounds: CGRect, bottomInset: CGFloat, raster: (CombatFeedbackItem) -> CombatFeedbackRaster?,
    ) -> CombatFeedbackItem {
        let bounds = bounds.isEmpty ? CGRect(x: 0, y: 0, width: 180, height: 250) : bounds
        let relevant = previous.filter {
            $0.targetID == incoming.targetID && ($0.region == incoming.region || (isCentral($0) && isCentral(incoming)))
        }
        let deadline = date.addingTimeInterval(maximumQueueDelay)
        var launch = date
        if let last = relevant.last(where: { $0.region == incoming.region }) {
            launch = max(launch, last.availableAt.addingTimeInterval(0.08))
        }
        launch = min(launch, deadline)
        let end = min(deadline, relevant.map(\.expiresAt).max() ?? launch)
        var incoming = incoming
        incoming.feedbackSpread = spread(for: incoming, previous: relevant, at: launch)
        var item = incoming
        let lifetime = incoming.region == .impact ? 1.05 : incoming.region == .announcement ? 1.6 : 0.92
        let obstacles = relevant.compactMap { old -> (CombatFeedbackItem, Geometry)? in
            raster(old).map { (old, geometry(old, raster: $0, bounds: bounds, bottomInset: bottomInset)) }
        }
        let shape = raster(incoming).map { geometry(incoming, raster: $0, bounds: bounds, bottomInset: bottomInset) }
        while let shape, launch < end {
            item = incoming.scheduled(at: launch)
            item.expiresAt = launch.addingTimeInterval(lifetime)
            if clear(item, geometry: shape, of: obstacles, bounds: bounds) {
                break
            }
            launch = min(deadline, launch.addingTimeInterval(0.015))
        }
        item = incoming.scheduled(at: launch)
        item.expiresAt = launch.addingTimeInterval(lifetime)
        if let shape, item.region == .impact {
            item.feedbackSpread = bestImpactRoute(item, geometry: shape, previous: obstacles, bounds: bounds)
        }
        item.lastReceivedAt = date
        if item.isCritical {
            item.criticalAt = launch
        }
        return item
    }

    private static func spread(for item: CombatFeedbackItem, previous: [CombatFeedbackItem], at launch: Date) -> Int {
        let recent = previous.filter { $0.region == item.region && $0.availableAt.addingTimeInterval(nearbyWindow) >= launch }
        guard !recent.isEmpty else { return 0 }
        if item.region == .announcement {
            return [-1, 1, -2, 2][(recent.count - 1) % 4]
        }
        if item.region == .impact {
            if item.feedbackClass == .heal, recent.contains(where: { isDamage($0) }) {
                return 1
            }
            if isDamage(item), recent.contains(where: { $0.feedbackClass == .heal }) {
                return -1
            }
            if recent.count < 2 {
                return 0
            }
        }
        return recent.last(where: { $0.feedbackSpread != 0 })?.feedbackSpread == -1 ? 1 : -1
    }

    private static func bestImpactRoute(
        _ item: CombatFeedbackItem, geometry: Geometry,
        previous: [(CombatFeedbackItem, Geometry)], bounds: CGRect,
    ) -> Int {
        let hasHeal = previous.contains { $0.0.feedbackClass == .heal }
        let hasDamage = previous.contains { isDamage($0.0) }
        let routes = item.feedbackClass == .heal && hasDamage ? [1, 2, 3, 4, 0, -1, -2, -3, -4]
            : isDamage(item) && hasHeal ? [-1, -2, -3, -4, 0, 1, 2, 3, 4] : [0, -1, 1, -2, 2, -3, 3, -4, 4]
        var best = 0
        var bestScore = Double.infinity
        // Compare projected footprints in both directions so neither a small
        // arrival nor an older fading result disappears underneath another chip.
        for route in routes {
            var candidate = item
            candidate.feedbackSpread = route
            var score = Double(abs(route)) * 0.001
            for elapsed in [0.0, 0.085, 0.17, 0.3, 0.5, 0.8] {
                let date = item.availableAt.addingTimeInterval(elapsed)
                let sample = state(for: candidate, at: date)
                let next = footprint(candidate, geometry: geometry, sample: sample, at: date, bounds: bounds)
                for (old, oldGeometry) in previous where date >= old.availableAt && date < old.expiresAt {
                    let oldSample = state(for: old, at: date)
                    guard sample.opacity > 0.15, oldSample.opacity > 0.15 else { continue }
                    let prior = footprint(old, geometry: oldGeometry, sample: oldSample, at: date, bounds: bounds)
                    let intersection = next.intersection(prior)
                    guard !intersection.isNull else { continue }
                    let area = min(next.width * next.height, prior.width * prior.height)
                    let covered = Double(intersection.width * intersection.height / max(1, area))
                    score += covered + (covered > 0.9 ? 1000 : 0)
                }
            }
            if score < bestScore {
                best = route
                bestScore = score
            }
        }
        return best
    }

    private static func isDamage(_ item: CombatFeedbackItem) -> Bool {
        [.directDamage, .critical, .dot].contains(item.feedbackClass)
    }

    static func position(
        for item: CombatFeedbackItem, base: CGPoint, size: CGSize,
        state: CombatFeedbackAnimationState, elapsed: TimeInterval, bounds: CGRect,
    ) -> CGPoint {
        let peak = item.region == .impact ? 1.85 : item.region == .announcement ? 1.35 : 1.152
        let halfHeight = size.height * peak / 2
        let minimumY = bounds.minY + 8 + halfHeight
        let maximumY = max(minimumY, bounds.maxY - 8 - halfHeight)
        let nameRow = item.feedbackSpread < 0 ? -item.feedbackSpread * 2 - 1 : item.feedbackSpread * 2
        let row = item.region == .announcement ? Double(nameRow) * 32
            : item.region == .impact ? Double(max(0, abs(item.feedbackSpread) - 1)) * 24 : item.feedbackSpread == -1 ? -24.0 : item
            .feedbackSpread == 1 ? -48.0 : 0
        let centerY = min(maximumY, max(minimumY, base.y + row))
        let riseAnchor = item.region == .announcement ? base.y : centerY
        let rise = min(52, max(0, riseAnchor - minimumY)) * state.riseProgress
        let maximumFan = max(0, (bounds.width - size.width * peak) / 2 - 8)
        let progress = 1 - pow(1 - min(1, max(0, elapsed / 0.4)), 3)
        let reach = (abs(item.feedbackSpread).isMultiple(of: 2) ? 2.0 : 1.0) * (16 + 20 * progress)
        let direction = item.feedbackSpread == 0 ? 0.0 : item.feedbackSpread < 0 ? -1.0 : 1.0
        let fan = item.region == .impact ? direction * min(reach, maximumFan) : 0
        return CGPoint(x: base.x + fan, y: centerY - rise)
    }

    private static func isCentral(_ item: CombatFeedbackItem) -> Bool {
        item.region == .impact || item.region == .announcement
    }

    private struct Geometry {
        let center: CGPoint
        let size: CGSize
    }

    private static func geometry(
        _ item: CombatFeedbackItem,
        raster: CombatFeedbackRaster,
        bounds: CGRect,
        bottomInset: CGFloat,
    ) -> Geometry {
        var layout = StationaryFeedbackLayout()
        layout.retain(ids: [item.id], in: bounds)
        let reservation = CGSize(
            width: raster.pointSize.width + max(0, CGFloat(item.reservedDigitCount) * raster.maximumDigitWidth - raster.textWidth),
            height: raster.pointSize.height,
        )
        if item.region == .announcement {
            layout.placeAnnouncementGroup([(item.id, reservation)], groupIndex: 0)
        } else {
            let multiplier = 1.2 * (item.region == .impact ? 1 : 0.8)
            _ = layout.place(
                id: item.id,
                size: CGSize(width: reservation.width * multiplier, height: reservation.height * multiplier),
                region: item.region,
                bottomInset: bottomInset,
            )
        }
        guard let slot = layout.slots.first else { return Geometry(center: .zero, size: .zero) }
        return Geometry(
            center: layout.position(for: slot, push: 0, rise: 0, bottomInset: bottomInset),
            size: CGSize(width: reservation.width * slot.fitScale, height: reservation.height * slot.fitScale),
        )
    }

    private static func clear(
        _ item: CombatFeedbackItem,
        geometry: Geometry,
        of previous: [(CombatFeedbackItem, Geometry)],
        bounds: CGRect,
    ) -> Bool {
        var sampleDate = item.availableAt
        while sampleDate < item.expiresAt {
            let sample = state(for: item, at: sampleDate)
            if sample.opacity > 0.15 {
                let rect = footprint(item, geometry: geometry, sample: sample, at: sampleDate, bounds: bounds).insetBy(dx: -6, dy: -6)
                for (old, oldGeometry) in previous where sampleDate >= old.availableAt && sampleDate < old.expiresAt {
                    let oldSample = state(for: old, at: sampleDate)
                    if oldSample.opacity > 0.15, rect.intersects(footprint(
                        old,
                        geometry: oldGeometry,
                        sample: oldSample,
                        at: sampleDate,
                        bounds: bounds,
                    )) {
                        return false
                    }
                }
            }
            sampleDate = sampleDate.addingTimeInterval(0.015)
        }
        return true
    }

    private static func footprint(
        _ item: CombatFeedbackItem,
        geometry: Geometry,
        sample: CombatFeedbackAnimationState,
        at date: Date,
        bounds: CGRect,
    ) -> CGRect {
        let center = position(
            for: item,
            base: geometry.center,
            size: geometry.size,
            state: sample,
            elapsed: date.timeIntervalSince(item.firstScheduledAt),
            bounds: bounds,
        )
        return CGRect(
            x: center.x - geometry.size.width * sample.scale / 2,
            y: center.y - geometry.size.height * sample.scale / 2,
            width: geometry.size.width * sample.scale, height: geometry.size.height * sample.scale,
        )
    }
}

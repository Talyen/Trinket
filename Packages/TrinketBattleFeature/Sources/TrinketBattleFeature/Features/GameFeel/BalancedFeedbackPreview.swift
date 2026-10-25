import CoreGraphics
import Foundation
import SwiftUI
import TrinketDesignSystem

#if DEBUG
extension EnvironmentValues {
    @Entry var balancedFeedbackPreview = false
}

/// An opt-in native experiment. Shipping battles retain their existing lane and motion.
enum BalancedFeedbackPreview {
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
        var launch = date
        if let last = relevant.last(where: { $0.region == incoming.region }) {
            launch = max(launch, last.availableAt.addingTimeInterval(0.18))
        }
        let end = relevant.map(\.expiresAt).max() ?? launch
        var item = incoming
        let lifetime = incoming.region == .impact ? 1.05 : incoming.region == .announcement ? 1.6 : 0.92
        let obstacles = relevant.compactMap { old -> (CombatFeedbackItem, Geometry)? in
            raster(old).map { (old, geometry(old, raster: $0, bounds: bounds, bottomInset: bottomInset)) }
        }
        guard let pixels = raster(incoming) else { return incoming.scheduled(at: launch) }
        let shape = geometry(incoming, raster: pixels, bounds: bounds, bottomInset: bottomInset)
        while launch < end {
            item = incoming.scheduled(at: launch)
            item.expiresAt = launch.addingTimeInterval(lifetime)
            if clear(item, geometry: shape, of: obstacles, bounds: bounds) {
                break
            }
            launch = launch.addingTimeInterval(0.015)
        }
        item = incoming.scheduled(at: launch)
        item.expiresAt = launch.addingTimeInterval(lifetime)
        item.lastReceivedAt = date
        return item
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
                let rect = footprint(geometry, sample: sample, bounds: bounds).insetBy(dx: -6, dy: -6)
                for (old, oldGeometry) in previous where sampleDate >= old.availableAt && sampleDate < old.expiresAt {
                    let oldSample = state(for: old, at: sampleDate)
                    if oldSample.opacity > 0.15, rect.intersects(footprint(oldGeometry, sample: oldSample, bounds: bounds)) {
                        return false
                    }
                }
            }
            sampleDate = sampleDate.addingTimeInterval(0.015)
        }
        return true
    }

    private static func footprint(_ geometry: Geometry, sample: CombatFeedbackAnimationState, bounds: CGRect) -> CGRect {
        let rise = min(52, max(0, bounds.height / 2 - 12)) * sample.riseProgress
        return CGRect(
            x: geometry.center.x - geometry.size.width * sample.scale / 2,
            y: geometry.center.y - rise - geometry.size.height * sample.scale / 2,
            width: geometry.size.width * sample.scale, height: geometry.size.height * sample.scale,
        )
    }
}
#endif

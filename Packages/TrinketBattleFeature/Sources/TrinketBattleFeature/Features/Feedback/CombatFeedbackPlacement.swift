import CoreGraphics

/// The fixed initial footprint of one independently scheduled chip.
struct CombatFeedbackPlacement {
    let center: CGPoint
    let fitScale: CGFloat

    static func resolve(size: CGSize, region: CombatFeedbackRegion, bounds: CGRect, bottomInset: CGFloat) -> Self? {
        guard size.width > 0, size.height > 0 else { return nil }
        if region == .announcement {
            let cellWidth = max(0, bounds.width - 16)
            let rowHeight = min(100, bounds.height * 0.30)
            let fit = min(1, max(0, cellWidth - 8) / (size.width * 1.35), rowHeight / (size.height * 1.35))
            // Preserve the original rectangle midpoint arithmetic, including rounding.
            let width = size.width * fit
            let height = size.height * fit
            let x = bounds.minX + 8 + cellWidth * 0.5
            let y = bounds.midY - min(64, bounds.height * 0.24)
            let rect = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
            return Self(center: CGPoint(x: rect.midX, y: rect.midY), fitScale: fit)
        }
        var area = bounds.insetBy(dx: 8, dy: 8)
        if region != .impact {
            area.size.height -= bottomInset
            area.size.width = (area.width - 8) / 2
            if region == .setback {
                area.origin.x = bounds.midX + 4
            }
        }
        guard area.width > 0, area.height > 0 else { return nil }
        let sizeScale = 1.2 * (region == .impact ? 1 : CombatFeedbackMotionSampler.statusSizeScale)
        let size = CGSize(width: size.width * sizeScale, height: size.height * sizeScale)
        let maximumScale = region == .impact ? 1.9 * 1.10 : CombatFeedbackMotionSampler.statusPeakScale
        let fit = min(1, area.width / (size.width * maximumScale), area.height / (size.height * maximumScale))
        let fitted = CGSize(width: size.width * fit, height: size.height * fit)
        let halfWidth = fitted.width * maximumScale / 2
        let x = switch region {
        case .impact, .announcement: bounds.midX
        case .benefit: area.minX + halfWidth
        case .setback: area.maxX - halfWidth
        }
        let y = region == .impact ? bounds.midY : area.maxY - fitted.height * maximumScale / 2
        return Self(center: CGPoint(x: x, y: y), fitScale: fit)
    }
}

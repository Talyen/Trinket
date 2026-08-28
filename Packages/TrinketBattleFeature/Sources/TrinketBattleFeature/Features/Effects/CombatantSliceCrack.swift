import CoreGraphics
import Foundation

enum CombatantSliceCrack {
    static let aspectWidth: CGFloat = 192
    static let aspectHeight: CGFloat = 256
    static let segmentCount = 5
    static let wobble: CGFloat = 12
    private static let endPadding: CGFloat = 20

    private static let along = CGVector(
        dx: sin(CombatantSliceGeometry.angleRadians),
        dy: cos(CombatantSliceGeometry.angleRadians)
    )
    private static let normal = CGVector(
        dx: cos(CombatantSliceGeometry.angleRadians),
        dy: -sin(CombatantSliceGeometry.angleRadians)
    )

    static let points: [CGPoint] = {
        let span = cardSpanOffsets
        var vertices = [basePoint(aspectOffset: span.lowerBound - endPadding)]
        let interiorCount = segmentCount - 1
        for index in 1 ... interiorCount {
            let fraction = CGFloat(index) / CGFloat(segmentCount)
            let aspectOffset = span.lowerBound + (span.upperBound - span.lowerBound) * fraction
            let noise = CombatantCardEffectNoise.value(index, salt: 211)
            let offset = wobble * (0.5 + 0.5 * noise) * (index.isMultiple(of: 2) ? 1 : -1)
            vertices.append(offsetPoint(aspectOffset: aspectOffset, perpendicular: offset))
        }
        vertices.append(basePoint(aspectOffset: span.upperBound + endPadding))
        return vertices
    }()

    private static let cumulativeAspectLengths: [CGFloat] = {
        var lengths: [CGFloat] = [0]
        var running: CGFloat = 0
        for index in 0 ..< (points.count - 1) {
            running += segmentAspectLength(index: index)
            lengths.append(running)
        }
        return lengths
    }()

    static var totalAspectLength: CGFloat {
        cumulativeAspectLengths[points.count - 1]
    }

    static var cardFractionRange: ClosedRange<CGFloat> {
        let start = endPadding / totalAspectLength
        return start ... (1 - start)
    }

    static func point(atFraction fraction: CGFloat) -> CGPoint {
        let lead = min(max(fraction, 0), 1)
        let target = lead * totalAspectLength
        for index in 0 ..< (points.count - 1) {
            let start = cumulativeAspectLengths[index]
            let end = cumulativeAspectLengths[index + 1]
            if target <= end {
                let a = points[index]
                let b = points[index + 1]
                let local = end > start ? (target - start) / (end - start) : 0
                return CGPoint(
                    x: a.x + (b.x - a.x) * local,
                    y: a.y + (b.y - a.y) * local
                )
            }
        }
        return points[points.count - 1]
    }

    static func point(atFraction fraction: CGFloat, size: CGSize) -> CGPoint {
        let unit = point(atFraction: fraction)
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    static func polylinePoints(toFraction fraction: CGFloat, size: CGSize) -> [CGPoint] {
        let lead = min(max(fraction, 0), 1)
        var result = [CGPoint(x: points[0].x * size.width, y: points[0].y * size.height)]
        guard lead > 0 else { return result }
        let target = lead * totalAspectLength
        var remaining = target
        for index in 0 ..< (points.count - 1) {
            let a = points[index]
            let b = points[index + 1]
            let segmentLength = segmentAspectLength(index: index)
            if segmentLength <= remaining {
                result.append(CGPoint(x: b.x * size.width, y: b.y * size.height))
                remaining -= segmentLength
            } else {
                let local = segmentLength > 0 ? remaining / segmentLength : 0
                result.append(CGPoint(
                    x: (a.x + (b.x - a.x) * local) * size.width,
                    y: (a.y + (b.y - a.y) * local) * size.height
                ))
                break
            }
        }
        return result
    }

    static func tangent(atFraction fraction: CGFloat) -> CGVector {
        let lead = min(max(fraction, 0), 1)
        let target = lead * totalAspectLength
        let lastIndex = points.count - 2
        var segmentIndex = lastIndex
        for index in 0 ..< lastIndex where target <= cumulativeAspectLengths[index + 1] {
            segmentIndex = index
            break
        }
        let a = points[segmentIndex]
        let b = points[segmentIndex + 1]
        let dx = (b.x - a.x) * aspectWidth
        let dy = (b.y - a.y) * aspectHeight
        let length = hypot(dx, dy)
        guard length > 0 else { return along }
        return CGVector(dx: dx / length, dy: dy / length)
    }

    static func side(of point: CGPoint) -> CGFloat {
        let px = point.x * aspectWidth
        let py = point.y * aspectHeight
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        var nearestSign: CGFloat = 1
        for index in 0 ..< (points.count - 1) {
            let a = points[index]
            let b = points[index + 1]
            let ax = a.x * aspectWidth, ay = a.y * aspectHeight
            let bx = b.x * aspectWidth, by = b.y * aspectHeight
            let abx = bx - ax, aby = by - ay
            let apx = px - ax, apy = py - ay
            let abLength2 = abx * abx + aby * aby
            guard abLength2 > 0 else { continue }
            let local = min(max((apx * abx + apy * aby) / abLength2, 0), 1)
            let closestX = ax + abx * local
            let closestY = ay + aby * local
            let dx = px - closestX
            let dy = py - closestY
            let distance = hypot(dx, dy)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestSign = (dx * normal.dx + dy * normal.dy) >= 0 ? 1 : -1
            }
        }
        return nearestDistance * nearestSign
    }

    private static var cardSpanOffsets: ClosedRange<CGFloat> {
        var offsets: [CGFloat] = []
        for boundary in [0 as CGFloat, 1] {
            let d = (boundary - 0.5) * aspectWidth / along.dx
            let unitY = 0.5 + along.dy * d / aspectHeight
            if (0 ... 1).contains(unitY) {
                offsets.append(d)
            }
        }
        for boundary in [0 as CGFloat, 1] {
            let d = (boundary - 0.5) * aspectHeight / along.dy
            let unitX = 0.5 + along.dx * d / aspectWidth
            if (0 ... 1).contains(unitX) {
                offsets.append(d)
            }
        }
        let minOffset = offsets.min() ?? 0
        let maxOffset = offsets.max() ?? 0
        return minOffset ... maxOffset
    }

    private static func basePoint(aspectOffset d: CGFloat) -> CGPoint {
        CGPoint(
            x: 0.5 + along.dx * d / aspectWidth,
            y: 0.5 + along.dy * d / aspectHeight
        )
    }

    private static func offsetPoint(aspectOffset d: CGFloat, perpendicular: CGFloat) -> CGPoint {
        CGPoint(
            x: 0.5 + (along.dx * d + normal.dx * perpendicular) / aspectWidth,
            y: 0.5 + (along.dy * d + normal.dy * perpendicular) / aspectHeight
        )
    }

    private static func segmentAspectLength(index: Int) -> CGFloat {
        let a = points[index]
        let b = points[index + 1]
        return hypot((b.x - a.x) * aspectWidth, (b.y - a.y) * aspectHeight)
    }
}

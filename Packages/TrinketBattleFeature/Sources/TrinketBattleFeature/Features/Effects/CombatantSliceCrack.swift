import CoreGraphics
import Foundation

/// Deterministic jagged "fissure" crack that spans the Slice card diagonal.
/// Vertices live in unit space (0…1) built from the card's 192×256 aspect
/// space so the split mask, drawn crack, and cut-face particles all share one
/// shape. The crack generally follows the base diagonal (`CombatantSliceGeometry`)
/// with small alternating perpendicular offsets, so the dissolve wipe and the
/// separation direction keep their original look.
enum CombatantSliceCrack {
    static let aspectWidth: CGFloat = 192
    static let aspectHeight: CGFloat = 256
    /// Crack segments; interior direction changes = segmentCount - 1.
    static let segmentCount = 5
    /// Max perpendicular wobble from the base diagonal in aspect pixels.
    static let wobble: CGFloat = 12
    /// How far past the card boundary the crack extends on the base diagonal,
    /// so the split polygons fully cover the card at its corners.
    private static let endPadding: CGFloat = 20

    private static let along = CGVector(
        dx: sin(CombatantSliceGeometry.angleRadians),
        dy: cos(CombatantSliceGeometry.angleRadians)
    )
    private static let normal = CGVector(
        dx: cos(CombatantSliceGeometry.angleRadians),
        dy: -sin(CombatantSliceGeometry.angleRadians)
    )

    /// Crack vertices in unit space: endpoints extend off the card along the
    /// base diagonal, interior vertices zigzag across it.
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

    /// Cumulative aspect-space length before each vertex.
    private static let cumulativeAspectLengths: [CGFloat] = {
        var lengths: [CGFloat] = [0]
        var running: CGFloat = 0
        for index in 0 ..< (points.count - 1) {
            running += segmentAspectLength(index: index)
            lengths.append(running)
        }
        return lengths
    }()

    /// Total crack length in aspect-space pixels.
    static var totalAspectLength: CGFloat {
        cumulativeAspectLengths[points.count - 1]
    }

    /// Arc-length fraction range that lies on the card; the crack's padded
    /// endpoints reach past it so the split polygons fully cover the card.
    static var cardFractionRange: ClosedRange<CGFloat> {
        let start = endPadding / totalAspectLength
        return start ... (1 - start)
    }

    /// Point at arc-length fraction `t` along the crack (unit space).
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

    /// Point at arc-length fraction `t` in the given rendered size.
    static func point(atFraction fraction: CGFloat, size: CGSize) -> CGPoint {
        let unit = point(atFraction: fraction)
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    /// Pixel-space crack vertices from the start up to arc-length fraction `t`.
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

    /// Unit tangent (aspect-space) of the crack segment at fraction `t`.
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

    /// Signed distance from a unit-space point to the crack. Negative on the
    /// primary (-normal) side, matching `CombatantSliceGeometry` half-planing.
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

    /// Aspect-space offsets along the base diagonal where it crosses the card.
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

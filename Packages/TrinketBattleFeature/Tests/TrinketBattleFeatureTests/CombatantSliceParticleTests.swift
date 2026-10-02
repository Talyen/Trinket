import CoreGraphics
import Foundation
import Testing
@testable import TrinketBattleFeature

struct CombatantSliceParticleTests {
    @Test func `prepared cut particles preserve original animation samples at every card size`() throws {
        let particles = CombatantSliceEffectConfig.productionCutParticles
        let sizes = [CGSize(width: 192, height: 256), CGSize(width: 96, height: 128), CGSize(width: 137, height: 201)]
        for particle in particles {
            let index = particle.id
            let pos = (CombatantCardEffectNoise.value(index, salt: 101) - 0.5) * 1.3
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let spray = (CombatantCardEffectNoise.value(index, salt: 107) - 0.5) * 0.8
            let delay = CombatantCardEffectNoise.value(index, salt: 113) * 0.12
            let speed = 45 + CombatantCardEffectNoise.value(index, salt: 127) * 95
            let size = 2.5 + CombatantCardEffectNoise.value(index, salt: 131) * 3.5
            let lifetime = 0.35 + CombatantCardEffectNoise.value(index, salt: 139) * 0.35
            let span = CombatantSliceCrack.cardFractionRange
            let fraction = span.lowerBound + (pos + 0.65) / 1.3 * (span.upperBound - span.lowerBound)
            let tangent = CombatantSliceCrack.tangent(atFraction: fraction)
            let normal = CGVector(dx: tangent.dy, dy: -tangent.dx)
            let progresses: [CGFloat] = [0, 0.05, 0.2, 0.5, 0.9, 1, delay, delay + lifetime]
            for cardSize in sizes {
                for progress in progresses {
                    let age = (progress - delay) / lifetime
                    let actual = particle.sample(progress: progress, cardSize: cardSize)
                    guard age > 0, age < 1 else {
                        #expect(actual == nil)
                        continue
                    }
                    let sample = try #require(actual)
                    let origin = CombatantSliceCrack.point(atFraction: fraction, size: cardSize)
                    let distance = speed * (1 - pow(1 - age, 2))
                    #expect(sample.center.x == origin.x + (normal.dx * side + tangent.dx * spray) * distance)
                    #expect(sample.center.y == origin.y + (normal.dy * side + tangent.dy * spray) * distance)
                    #expect(sample.diameter == size * (1 - 0.3 * age))
                    #expect(sample.opacity == Double(pow(1 - age, 1.4)))
                }
            }
        }
    }
}

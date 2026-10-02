import CoreGraphics
import Foundation
import Testing
@testable import TrinketBattleFeature

struct CardDissolveTextureTests {
    @Test func `transparent dissolve steps share storage across cut variants`() throws {
        let complete = try #require(CardDissolveTexture.thresholdMaskImage(progress: 1))
        let bytes = try #require(complete.dataProvider?.data) as Data
        #expect(stride(from: 0, to: bytes.count, by: 2).allSatisfy { bytes[$0] == 255 && bytes[$0 + 1] == 0 })

        let cuts: [CGFloat?] = [nil, -30]
        let progressValues: [CGFloat] = [0.975, 1]
        for cut in cuts {
            for progress in progressValues {
                let image = try #require(CardDissolveTexture.thresholdMaskImage(progress: progress, cutAngleDegrees: cut))
                #expect(image === complete)
            }
        }
    }

    @Test func `visible dissolve steps retain their distinct transparency`() throws {
        let standard = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.2))
        let sliced = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.2, cutAngleDegrees: -30))
        let later = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.4))
        let standardBytes = try #require(standard.dataProvider?.data) as Data
        let slicedBytes = try #require(sliced.dataProvider?.data) as Data
        let laterBytes = try #require(later.dataProvider?.data) as Data
        #expect(standardBytes != slicedBytes && standardBytes != laterBytes)
        #expect(stride(from: 1, to: standardBytes.count, by: 2).contains { standardBytes[$0] > 0 })
        #expect(CardDissolveTexture.thresholdMaskImage(progress: 0.2) === standard)
    }
}

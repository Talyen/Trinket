import Foundation
import os

package enum ReactionScope {
    package static let maxDepth = 10
    package static let maxTalentReactionDepth = maxDepth
    package static let maxDotRecursionDepth = maxDepth
    package static let maxDrawAndPlayDepth = maxDepth
    package static let maxDoTMirrorChainDepth = 5

    package static let logger = Logger(subsystem: "com.trinket.battle", category: "ReactionScope")

    package static func capHit(site: String, depth: Int) {
        logger.fault("ReactionScope: \(site, privacy: .public) hit cap 10 at depth \(depth, privacy: .public): possible infinite loop")
        #if DEBUG
        if !isRunningTests {
            assertionFailure("ReactionScope: \(site) hit cap 10: possible infinite loop")
        }
        #endif
    }

    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || NSClassFromString("XCTest") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || ProcessInfo.processInfo.environment["SWIFT_TESTING_ENTRY_POINT"] != nil
            || ProcessInfo.processInfo.arguments.contains(where: { $0.contains("Testing") || $0.contains("xctest") })
    }
}

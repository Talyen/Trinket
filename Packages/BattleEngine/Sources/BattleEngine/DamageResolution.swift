import Foundation

/// Backward-compatible alias for `DamagePipeline.canonicalNames`.
package enum DamageSteps {
    public static var canonicalNames: [String] {
        DamagePipeline.canonicalNames
    }
}

import Foundation

enum GeneratedCaseSeeds {
    static func values(defaultCount: UInt64) -> [UInt64] {
        let count: UInt64 = ProcessInfo.processInfo.environment["TRINKET_GENERATED_CASES"] == "512" ? 512 : defaultCount
        return Array(1 ... count)
    }
}

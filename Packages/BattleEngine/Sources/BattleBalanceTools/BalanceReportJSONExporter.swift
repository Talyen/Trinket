import Foundation

public enum BalanceReportJSONExporter {
    public static func render(_ result: BalanceSweepResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(result)
    }
}

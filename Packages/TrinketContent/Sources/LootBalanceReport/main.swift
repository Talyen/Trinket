import Foundation
import TrinketContent

private enum ReportError: LocalizedError {
    case argument(String)

    var errorDescription: String? {
        switch self {
        case let .argument(message): message
        }
    }
}

private func run() throws {
    var arguments = CommandLine.arguments.dropFirst().makeIterator()
    var full = false
    var output: String?
    while let argument = arguments.next() {
        switch argument {
        case "--full": full = true
        case "--output":
            guard let path = arguments.next(), !path.isEmpty, !path.hasPrefix("--") else {
                throw ReportError.argument("--output requires a file path")
            }
            output = path
        case "--help", "-h":
            print("""
            Usage: swift run --package-path Packages/TrinketContent LootBalanceReport [--full] [--output <path>]
            Default: save the complete report under .DerivedData/LootBalanceReports and print its location.
            --full prints the complete report to stdout; alone, it writes no artifact.
            --output saves the report at the specified file path (also with --full).
            """)
            return
        default: throw ReportError.argument("Unknown argument: \(argument); use --help")
        }
    }

    let report = ItemRewardGenerator.balanceReport() + "\n"
    if !full || output != nil {
        let path = output ?? ".DerivedData/LootBalanceReports/\(UUID().uuidString)/report.md"
        let url = URL(fileURLWithPath: path).standardizedFileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try report.write(to: url, atomically: true, encoding: .utf8)
        if full {
            FileHandle.standardError.write(Data("Report: \(url.path)\n".utf8))
        } else {
            let rowCount = report.split(separator: "\n").count(where: { $0.hasPrefix("| ") }) - 1
            print("Loot balance: \(rowCount) rows; levels 1–40, Ordinary/Boss, Sanctum 0/5/10/15/20%, five pools.")
            print("Report: \(url.path)")
            print("Full terminal output: swift run --package-path Packages/TrinketContent LootBalanceReport --full")
        }
    }
    if full {
        print(report, terminator: "")
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("LootBalanceReport: \(error.localizedDescription)\n".utf8))
    exit(1)
}

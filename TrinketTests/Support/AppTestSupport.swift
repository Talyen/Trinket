import Foundation
@testable import Trinket

@MainActor
enum AppTestSupport {
    static let defaultSync = LocalOnlyPlayerSaveSync()

    static func makeEnvironment(arguments: [String] = []) -> AppEnvironment {
        AppEnvironment.parse(arguments: arguments, environment: [:])
    }

    static func makeAppState(
        arguments: [String] = [],
        fileStore: PlayerSaveFileStore? = nil,
        directoryURL: URL,
        sync: LocalOnlyPlayerSaveSync = defaultSync
    ) -> AppState {
        AppState(
            environment: makeEnvironment(arguments: arguments),
            sync: sync,
            fileStore: fileStore ?? SaveTestSupport.makeFileStore(directoryURL: directoryURL)
        )
    }
}

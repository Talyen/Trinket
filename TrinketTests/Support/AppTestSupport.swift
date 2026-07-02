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
        sync: (any PlayerSaveSyncing)? = nil,
        userDefaults: UserDefaults? = nil
    ) -> AppState {
        AppState(
            environment: makeEnvironment(arguments: arguments),
            sync: sync ?? defaultSync,
            fileStore: fileStore ?? SaveTestSupport.makeFileStore(directoryURL: directoryURL),
            userDefaults: userDefaults
        )
    }
}

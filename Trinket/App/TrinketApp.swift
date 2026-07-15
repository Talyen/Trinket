import os
import SwiftUI
import TrinketPersistence

private let trinketAppLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "TrinketApp"
)

@main
struct TrinketApp: App {
    @State private var appState: AppState?
    @State private var bootstrapFailureMessage: String?

    init() {
        do {
            _appState = try State(initialValue: AppState(environment: .shared))
        } catch {
            assertionFailure("AppState bootstrap failed: \(error)")
            trinketAppLogger.error(
                "AppState bootstrap failed: \(error.localizedDescription, privacy: .public)"
            )
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let fallbackShell = try PlayerShellSessionStore(inMemoryOnly: true)
                _appState = try State(initialValue: AppState(
                    environment: .shared,
                    playerSave: fallbackSave,
                    shellSessionStore: fallbackShell
                ))
            } catch {
                trinketAppLogger.fault(
                    "AppState in-memory fallback failed: \(error.localizedDescription, privacy: .public)"
                )
                _appState = State(initialValue: nil)
                _bootstrapFailureMessage = State(
                    initialValue: "Progress storage could not be started on this device. Try freeing space or reinstalling, then launch again."
                )
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let appState {
                ContentView()
                    .environment(appState)
            } else {
                AppBootstrapFailureView(
                    message: bootstrapFailureMessage
                        ?? "Progress storage could not be started on this device."
                )
            }
        }
    }
}

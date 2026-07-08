import SwiftUI
import TrinketPersistence

@main
struct TrinketApp: App {
    @State private var appState: AppState

    init() {
        do {
            _appState = try State(initialValue: AppState(environment: .shared))
        } catch {
            assertionFailure("AppState bootstrap failed: \(error)")
            do {
                let fallbackSave = try PlayerSaveStore(inMemoryOnly: true)
                let fallbackShell = try PlayerShellSessionStore(inMemoryOnly: true)
                _appState = try State(initialValue: AppState(
                    environment: .shared,
                    playerSave: fallbackSave,
                    shellSessionStore: fallbackShell
                ))
            } catch {
                fatalError("AppState in-memory fallback failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

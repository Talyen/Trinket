import os
import SwiftUI
import TrinketContent
import TrinketPersistence

private let trinketAppLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "TrinketApp"
)

@main
struct TrinketApp: App {
    @State private var appState: AppState?
    @State private var bootstrapFailureMessage: String?
    @State private var artworkCache = PreparedArtworkCache.shared

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
                Group {
                    if artworkCache.isLaunchWarmupComplete {
                        ContentView()
                    } else {
                        LaunchWarmupView(progress: artworkCache.progress)
                    }
                }
                .environment(appState)
                .task {
                    await artworkCache.prepareAll(priorityImageNames: priorityImageNames(for: appState))
                }
            } else {
                AppBootstrapFailureView(
                    message: bootstrapFailureMessage
                        ?? "Progress storage could not be started on this device."
                )
            }
        }
    }

    private func priorityImageNames(for appState: AppState) -> [String] {
        let activeParty = [appState.roster.activeHero, appState.roster.activeCompanion]
            .compactMap(\.artReference)
            .flatMap { reference in
                [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
            }
        let activeEnemy = appState.journey.activeStageID
            .flatMap(GameContent.stage(id:))?
            .encounterCombatantArtReference
        let enemyNames = activeEnemy.map { reference in
            [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
        } ?? []
        return activeParty + enemyNames
    }
}

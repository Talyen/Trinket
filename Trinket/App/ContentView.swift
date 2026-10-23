import os
import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

private let contentViewLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "ContentView",
)

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ShellSession.self) private var shellSession
    @Environment(BattleSession.self) private var battle
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var homesteadZoomNamespace

    var onFirstLayout: () -> Void = {}

    var body: some View {
        @Bindable var shellSession = shellSession

        // swiftlint:disable:next accessibility_trait_for_button - Observes existing controls for audio recovery; the root adds no action.
        Group {
            if playerSave.starterSelection.phase != .complete {
                StarterSelectionFlow(
                    initialSelection: playerSave.starterSelection,
                    confirmHero: appState.confirmStarterHero,
                    confirmCompanion: appState.completeStarterSelection,
                )
                .id(playerSave.sessionGeneration)
                .onFirstNonzeroLayout {
                    onFirstLayout()
                }
                .transition(.opacity)
            } else {
                tabRoot(selection: $shellSession.selectedTab)
                    .transition(.opacity)
            }
        }
        .fullGameOfferHost()
        .simultaneousGesture(TapGesture().onEnded {
            appState.resumeAudioAfterMediaServicesReset(scenePhase: scenePhase)
        })
        // Keep the phone's navigation and stacked hubs on every portrait canvas.
        .environment(\.horizontalSizeClass, .compact)
        .animation(TrinketMotion.Screen.crossfade, value: playerSave.starterSelection.phase)
        .trinketSensoryFeedback(
            .success,
            trigger: playerSave.starterSelection.phase == .complete,
            enabled: appState.options.hapticsEnabled,
        )
        .tint(TrinketDesign.Colors.accent)
        .onAppear {
            appState.reconcileShellState(.scenePhaseChanged, scenePhase: scenePhase)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            async let cloudSync: Void = appState.runCloudSynchronization()
            await appState.fullGame.refreshOwnership()
            appState.synchronizePurchaseAccess()
            await cloudSync
        }
        .onChange(of: shellSession.selectedTab) { _, newTab in
            appState.reconcileShellState(.selectedTabChanged, scenePhase: scenePhase)
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.tabSwitch,
                detail: "tab=\(newTab.rawValue)",
            )
        }
        .onChange(of: battle.activeBattle?.id) { _, newValue in
            appState.shellDidSettle(
                .activeBattleChanged(started: newValue != nil),
                scenePhase: scenePhase,
            )
        }
        .onChange(of: appState.play.isGameplayActive) { _, active in
            // Covers Mystery/Shop/talent exits where the battle ID is already
            // nil. Separate from the battle-ID path above by intent.
            if !active {
                appState.synchronizePurchaseAccess()
            }
        }
        .onChange(of: appState.options.musicVolume) { _, _ in
            appState.refreshMusic(scenePhase: scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.reconcileShellState(.scenePhaseChanged, scenePhase: newPhase)
        }
    }

    private func tabRoot(selection: Binding<AppTab>) -> some View {
        @Bindable var shellSession = shellSession
        let intercepting = Binding<AppTab>(
            get: { selection.wrappedValue },
            set: { newTab in
                // Encounter covers are fullscreen and non-dismissable, so the
                // tab bar is unreachable while one is up; this guard covers
                // transition windows and programmatic selection. The drop is
                // logged so a stuck tab is diagnosable instead of silent.
                guard appState.play.encounters.activeMysteryEncounter == nil,
                      appState.play.encounters.activeShopEncounter == nil else {
                    contentViewLogger.info(
                        "Ignoring tab switch to \(newTab.rawValue, privacy: .public) during active encounter.",
                    )
                    return
                }
                appState.resumeAudioAfterMediaServicesReset(scenePhase: scenePhase)
                if newTab == selection.wrappedValue {
                    guard newTab != .play || battle.lifecyclePhase != .active else { return }
                    withAnimation { shellSession.popToRoot(newTab) }
                } else {
                    selection.wrappedValue = newTab
                }
            },
        )

        return TabView(selection: intercepting) {
            Tab(ContentCopy.localized(AppTab.play.displayName), systemImage: AppTab.play.symbolName, value: AppTab.play) {
                PlayView()
                    .modifier(SelectedTabLayoutAcknowledgement(
                        isSelected: shellSession.selectedTab == .play,
                        onLayout: onFirstLayout,
                    ))
                    .trinketDecorativeMotion(shellSession.selectedTab == .play)
            }

            Tab(ContentCopy.localized(AppTab.collection.displayName), systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView {
                        appState.consumePendingCollectionPresentation()
                    }
                    .modifier(SelectedTabLayoutAcknowledgement(
                        isSelected: shellSession.selectedTab == .collection,
                        onLayout: onFirstLayout,
                    ))
                    .trinketDecorativeMotion(shellSession.selectedTab == .collection)
                }
            }

            Tab(ContentCopy.localized(AppTab.homestead.displayName), systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                homesteadTab
                    .modifier(SelectedTabLayoutAcknowledgement(
                        isSelected: shellSession.selectedTab == .homestead,
                        onLayout: onFirstLayout,
                    ))
                    .trinketDecorativeMotion(shellSession.selectedTab == .homestead)
            }

            Tab(ContentCopy.localized(AppTab.options.displayName), systemImage: AppTab.options.symbolName, value: AppTab.options) {
                NavigationStack {
                    OptionsView()
                        .modifier(SelectedTabLayoutAcknowledgement(
                            isSelected: shellSession.selectedTab == .options,
                            onLayout: onFirstLayout,
                        ))
                        .trinketDecorativeMotion(shellSession.selectedTab == .options)
                }
            }
        }
    }

    private var homesteadTab: some View {
        @Bindable var shellSession = shellSession
        return NavigationStack(path: $shellSession.homesteadPath) {
            HomesteadView()
                .navigationDestination(for: HomesteadRoute.self) { route in
                    homesteadRouteView(for: route)
                }
        }
    }

    @ViewBuilder
    private func homesteadRouteView(for route: HomesteadRoute) -> some View {
        switch route {
        case .bestiary:
            LibraryBestiaryView()
        case .research:
            LibraryResearchView()
        case let .researchProject(id):
            if let project = ResearchProject.matching(id) {
                LibraryResearchProjectView(project: project)
            }
        case let .researchRecipe(id):
            if let recipe = EquipmentRecipe.matching(id) {
                LibraryRecipePreview(recipe: recipe)
            }
        case let .workshop(id):
            if let recipe = EquipmentRecipe.matching(id), let definition = GameContent.homesteadNode(matching: recipe.buildingID) {
                HomesteadNodeDetailView(definition: definition, initialRecipeID: recipe.id)
            }
        case let .category(category):
            HomesteadCategoryView(category: category, zoomNamespace: homesteadZoomNamespace)
        case let .node(nodeID):
            if let definition = GameContent.homesteadNodes.first(where: { $0.id == nodeID }) {
                HomesteadNodeDetailView(definition: definition)
                    .navigationTransition(.zoom(sourceID: nodeID, in: homesteadZoomNamespace))
            } else {
                Color.clear.onAppear {
                    if shellSession.homesteadPath.last == route {
                        shellSession.homesteadPath.removeLast()
                    }
                }
            }
        }
    }
}

private struct SelectedTabLayoutAcknowledgement: ViewModifier {
    let isSelected: Bool
    let onLayout: () -> Void

    func body(content: Content) -> some View {
        content
            .onFirstNonzeroLayout(when: isSelected) {
                onLayout()
            }
    }
}

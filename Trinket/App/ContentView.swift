import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ShellSession.self) private var shellSession
    @Environment(BattleSession.self) private var battle
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.scenePhase) private var scenePhase
    @State private var didAcknowledgePersistenceRecovery = false
    @Namespace private var homesteadZoomNamespace

    var onFirstLayout: () -> Void = {}

    var body: some View {
        @Bindable var shellSession = shellSession

        Group {
            if playerSave.starterSelection.phase != .complete {
                StarterSelectionFlow(
                    initialSelection: playerSave.starterSelection,
                    confirmHero: appState.confirmStarterHero,
                    confirmCompanion: appState.completeStarterSelection,
                )
                .onGeometryChange(for: Bool.self) { geometry in
                    geometry.size.width > 0 && geometry.size.height > 0
                } action: { hasLayout in
                    if hasLayout {
                        onFirstLayout()
                    }
                }
                .transition(.opacity)
            } else {
                tabRoot(selection: $shellSession.selectedTab)
                    .transition(.opacity)
            }
        }
        .fullGameOfferHost()
        .animation(TrinketMotion.Screen.crossfade, value: playerSave.starterSelection.phase)
        .trinketSensoryFeedback(
            .success,
            trigger: playerSave.starterSelection.phase == .complete,
            enabled: appState.options.hapticsEnabled,
        )
        .tint(TrinketDesign.Colors.accent)
        .alert(
            "Progress Storage Issue",
            isPresented: Binding(
                get: {
                    appState.requiresPersistenceRecoveryAcknowledgement
                        && !didAcknowledgePersistenceRecovery
                },
                set: { isPresented in
                    if !isPresented {
                        didAcknowledgePersistenceRecovery = true
                    }
                },
            ),
        ) {
            Button("Continue") {
                didAcknowledgePersistenceRecovery = true
            }
        } message: {
            Text(
                appState.persistenceStatusMessage
                    ?? "Saved progress could not be opened normally. Check Options → Progress Status.",
            )
        }
        .onAppear {
            appState.reconcileShellState(.scenePhaseChanged, scenePhase: scenePhase)
        }
        .onChange(of: shellSession.selectedTab) { _, newTab in
            appState.refreshMusic(scenePhase: scenePhase)
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.tabSwitch,
                detail: "tab=\(newTab.rawValue)",
            )
        }
        .onChange(of: battle.activeBattle?.id) { _, newValue in
            if newValue == nil {
                appState.synchronizePurchaseAccess()
            }
            appState.reconcileShellState(
                .activeBattleChanged(started: newValue != nil),
                scenePhase: scenePhase,
            )
        }
        .onChange(of: appState.play.isGameplayActive) { _, active in
            if !active {
                appState.synchronizePurchaseAccess()
            }
        }
        .onChange(of: appState.options.musicVolume) { _, _ in
            appState.refreshMusic(scenePhase: scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await appState.fullGame.refreshOwnership()
                    appState.synchronizePurchaseAccess()
                }
            }
            appState.reconcileShellState(.scenePhaseChanged, scenePhase: newPhase)
        }
    }

    private func tabRoot(selection: Binding<AppTab>) -> some View {
        @Bindable var shellSession = shellSession
        let intercepting = Binding<AppTab>(
            get: { selection.wrappedValue },
            set: { newTab in
                let oldTab = selection.wrappedValue
                if newTab == oldTab {
                    guard newTab != .play || battle.lifecyclePhase != .active else { return }
                    withAnimation { shellSession.popToRoot(newTab) }
                } else {
                    selection.wrappedValue = newTab
                }
            },
        )

        return TabView(selection: intercepting) {
            Tab(AppTab.play.displayName, systemImage: AppTab.play.symbolName, value: AppTab.play) {
                PlayView()
                    .modifier(SelectedTabLayoutAcknowledgement(
                        isSelected: shellSession.selectedTab == .play,
                        onLayout: onFirstLayout,
                    ))
            }

            Tab(AppTab.collection.displayName, systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView {
                        appState.consumePendingCollectionPresentation()
                    }
                    .modifier(SelectedTabLayoutAcknowledgement(
                        isSelected: shellSession.selectedTab == .collection,
                        onLayout: onFirstLayout,
                    ))
                }
            }

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                homesteadTab
                    .modifier(SelectedTabLayoutAcknowledgement(
                        isSelected: shellSession.selectedTab == .homestead,
                        onLayout: onFirstLayout,
                    ))
            }

            Tab(AppTab.options.displayName, systemImage: AppTab.options.symbolName, value: AppTab.options) {
                NavigationStack {
                    OptionsView()
                        .modifier(SelectedTabLayoutAcknowledgement(
                            isSelected: shellSession.selectedTab == .options,
                            onLayout: onFirstLayout,
                        ))
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
        case let .category(category):
            HomesteadCategoryView(category: category, zoomNamespace: homesteadZoomNamespace)
        case let .node(nodeID):
            if let definition = GameContent.homesteadNodes.first(where: { $0.id == nodeID }) {
                HomesteadNodeDetailView(definition: definition)
                    .navigationTransition(.zoom(sourceID: nodeID, in: homesteadZoomNamespace))
            } else {
                ContentUnavailableView(
                    "Project Unavailable",
                    systemImage: "hammer.fill",
                    description: Text("This homestead project is no longer available."),
                )
            }
        }
    }
}

private struct SelectedTabLayoutAcknowledgement: ViewModifier {
    let isSelected: Bool
    let onLayout: () -> Void

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { geometry in
                isSelected && geometry.size.width > 0 && geometry.size.height > 0
            } action: { hasLayout in
                if hasLayout {
                    onLayout()
                }
            }
    }
}

extension EnvironmentValues {
    @Entry var isLaunchPresentationReady = true
}

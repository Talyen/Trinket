import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct AspectClimbView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var prepareFloor: AspectFloor?
    @State private var pendingFloorStart = PendingAspectFloorStart()
    @State private var floorMessage: StageMapMessage?
    @State private var scrollTarget: String?

    let aspectID: AspectID

    private var aspect: AspectDefinition? {
        GameContent.aspect(id: aspectID)
    }

    private var floors: [AspectFloor] {
        GameContent.aspectFloors(for: aspectID)
    }

    private var progress: PlayerAspectsState {
        appState.aspects.current
    }

    private var activeFloorNumber: Int {
        guard let aspect else { return 1 }
        return progress.activeFloor(for: aspectID.rawValue, floorCount: aspect.floorCount)
    }

    var body: some View {
        Group {
            if let aspect {
                climbContent(aspect)
            } else {
                ContentUnavailableView("Aspect Missing", systemImage: "sparkles")
            }
        }
        .navigationTitle(aspect?.title ?? "Aspect")
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground(.playJourney)
        .accessibilityIdentifier(AccessibilityID.Play.aspectClimb(aspectID.rawValue))
        .sheet(item: $prepareFloor, onDismiss: startPendingFloorIfNeeded) { floor in
            BattlePartySheet(
                title: floor.isWarden ? "Warden · Floor \(floor.floor)" : "Floor \(floor.floor)",
                subtitle: GameContent.enemy(matching: floor.enemyID)?.combatant.name,
                aspect: aspect,
                accentColor: aspect?.keyword.visualStyle.color,
                initialHero: appState.roster.activeHero,
                initialPet: appState.roster.activePet,
                onStart: {
                    pendingFloorStart.floor = floor
                    prepareFloor = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(item: $floorMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            scrollTarget = GameContent.aspectFloor(aspectID: aspectID, floor: activeFloorNumber)?.id
        }
        .onChange(of: activeFloorNumber) { _, newValue in
            scrollTarget = GameContent.aspectFloor(aspectID: aspectID, floor: newValue)?.id
        }
    }

    @ViewBuilder
    private func climbContent(_ aspect: AspectDefinition) -> some View {
        let style = aspect.keyword.visualStyle
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                    Label(aspect.epithet, systemImage: style.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.color)
                    Text("Attune a Hero and Pet that match this Aspect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Affinity gear helps — not required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                LazyVStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
                    ForEach(floors) { floor in
                        floorCard(floor, aspect: aspect, style: style)
                            .id(floor.id)
                    }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollTarget, anchor: .center)
        .animation(reduceMotion ? nil : .smooth, value: scrollTarget)
    }

    @ViewBuilder
    private func floorCard(
        _ floor: AspectFloor,
        aspect: AspectDefinition,
        style: Keyword.VisualStyle
    ) -> some View {
        let startable = progress.isFloorStartable(floor.floor, aspectID: aspect.id.rawValue)
        let cleared = progress.isFloorCleared(floor.floor, aspectID: aspect.id.rawValue)
        let unlocked = progress.isFloorUnlocked(
            floor.floor,
            aspectID: aspect.id.rawValue,
            floorCount: aspect.floorCount
        )
        let isActive = startable
        let isLocked = !startable && !cleared

        VStack(alignment: .leading, spacing: isActive || !cleared ? TrinketDesign.Metrics.mediumSpacing : 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(floor.isWarden ? "Warden · Floor \(floor.floor)" : "Floor \(floor.floor)")
                        .font(isActive ? .title3.weight(.bold) : .headline)
                    if unlocked || cleared, let enemy = GameContent.enemy(matching: floor.enemyID) {
                        Text(enemy.combatant.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if cleared {
                        Text("Cleared")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if cleared {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Cleared")
                }
            }

            if startable {
                Button {
                    prepareFloor = floor
                } label: {
                    Text("Begin Floor")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(style.color)
                .disabled(appState.battle.activeBattle != nil)
            }
        }
        .padding(isActive ? TrinketDesign.Metrics.largeSpacing : 14)
        .trinketSurface(isActive ? .elevated : (cleared || unlocked ? .elevated : .denseRow))
        .trinketLockedCardEffect(
            isLocked: isLocked,
            text: isLocked ? "Locked" : nil,
            cornerRadius: TrinketDesign.Corners.card
        )
        .accessibilityIdentifier(AccessibilityID.Play.aspectFloor(aspect.id.rawValue, floor: floor.floor))
        .animation(reduceMotion ? nil : .smooth, value: startable)
    }

    private func startPendingFloorIfNeeded() {
        guard let floor = pendingFloorStart.floor else { return }
        pendingFloorStart.floor = nil
        if let message = appState.startAspectBattle(for: floor) {
            floorMessage = message
        }
    }
}

@MainActor
private final class PendingAspectFloorStart {
    var floor: AspectFloor?
}

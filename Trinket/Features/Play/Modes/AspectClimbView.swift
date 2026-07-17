import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct AspectClimbView: View {
    @Environment(AppState.self) private var appState
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
        appState.aspects
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
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.aspectClimb(aspectID.rawValue))
        .alert(item: $floorMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            scrollTarget = GameContent.aspectFloor(aspectID: aspectID, floor: activeFloorNumber)?.id
            prepareActiveFloorBattle()
        }
        .onChange(of: activeFloorNumber) { _, newValue in
            scrollTarget = GameContent.aspectFloor(aspectID: aspectID, floor: newValue)?.id
            prepareActiveFloorBattle()
        }
        .onChange(of: appState.roster) { _, _ in
            prepareActiveFloorBattle()
        }
        .onChange(of: appState.inventory) { _, _ in
            prepareActiveFloorBattle()
        }
        .onChange(of: appState.homestead) { _, _ in
            prepareActiveFloorBattle()
        }
    }

    @ViewBuilder
    private func climbContent(_ aspect: AspectDefinition) -> some View {
        let style = aspect.keyword.visualStyle
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                    Label(aspect.epithet, systemImage: style.symbolName)
                        .trinketTypography(.badge)
                        .foregroundStyle(style.color)
                    Text("Attune a Hero and Companion that match this Aspect.")
                        .trinketTypography(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Affinity gear helps — not required.")
                        .trinketTypography(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)

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
        .animation(.smooth, value: scrollTarget)
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
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                    Text(
                        GameContent.enemy(matching: floor.enemyID)?.isBoss == true
                            ? "Boss · Floor \(floor.floor)"
                            : "Floor \(floor.floor)"
                    )
                    .trinketTypography(isActive ? .sectionTitle : .cardTitle)
                    if unlocked || cleared, let enemy = GameContent.enemy(matching: floor.enemyID) {
                        Text(enemy.combatant.name)
                            .trinketTypography(.secondaryBody)
                            .foregroundStyle(.secondary)
                    }
                    if cleared {
                        Text("Cleared")
                            .trinketTypography(.badge)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if cleared {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TrinketDesign.Colors.success)
                }
            }

            if startable {
                floorBattleControls(floor, aspect: aspect, tint: style.color)
            }
        }
        .trinketSurface(isActive ? .elevated : (cleared || unlocked ? .elevated : .denseRow))
        .trinketLockedCardEffect(
            isLocked: isLocked,
            text: isLocked ? "Locked" : nil,
            cornerRadius: TrinketDesign.Corners.card
        )
        .accessibilityIdentifier(AccessibilityID.Play.aspectFloor(aspect.id.rawValue, floor: floor.floor))
        .animation(.smooth, value: startable)
    }

    @ViewBuilder
    private func floorBattleControls(
        _ floor: AspectFloor,
        aspect: AspectDefinition,
        tint: Color
    ) -> some View {
        BattlePartyInlinePicker(
            aspect: aspect
        )

        Button {
            if let message = appState.startAspectBattle(for: floor) {
                floorMessage = message
            }
        } label: {
            Text("Begin Floor")
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton(
            tint: tint,
            accessibilityIdentifier: AccessibilityID.Play.aspectBeginFloor(
                aspect.id.rawValue,
                floor: floor.floor
            )
        )
        .disabled(
            appState.battle.activeBattle != nil
                || !AspectAttunement.evaluate(
                    hero: appState.roster.activeHero,
                    companion: appState.roster.activeCompanion,
                    aspect: aspect
                ).isReady
        )
    }

    private func prepareActiveFloorBattle() {
        guard let floor = GameContent.aspectFloor(
            aspectID: aspectID,
            floor: activeFloorNumber
        ) else { return }
        appState.prepareAspectBattle(for: floor)
    }
}

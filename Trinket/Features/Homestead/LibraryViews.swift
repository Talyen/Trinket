import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct LibraryBestiaryView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @State private var selection: CombatantCardDetail?
    @State private var visibleIDs: Set<String> = []

    private var allowedSelection: Binding<CombatantCardDetail?> {
        Binding(get: {
            guard let selection, playerSave.library.isReadable,
                  playerSave.library.progress.encounteredEnemyIDs.contains(selection.id) else { return nil }
            return selection
        }, set: { selection = $0 })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: TrinketDesign.Spacing.small) {
                ForEach(GameContent.enemies) { enemy in
                    let discovered = playerSave.library.isReadable && playerSave.library.progress.encounteredEnemyIDs.contains(enemy.id)
                    Button { selection = LibraryEnemyDetail.snapshot(enemy, roster: playerSave.roster) } label: {
                        LibraryEnemyArtwork(enemy: enemy, discovered: discovered)
                    }
                    .trinketArtworkCardButtonStyle()
                    .disabled(!discovered)
                    .accessibilityLabel(discovered ? ContentCopy.localized(enemy.name) : String(localized: L10n.library_enemy_unknown))
                    .accessibilityIdentifier(AccessibilityID.Homestead.bestiaryEnemy(enemy.id))
                    .onAppear { visibleIDs.insert(enemy.id) }
                    .onDisappear { visibleIDs.remove(enemy.id) }
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .navigationTitle(Text(L10n.library_bestiary))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .trinketScreenBackground()
        .trinketSoftTopScrollEdge()
        .accessibilityIdentifier(AccessibilityID.Homestead.bestiary)
        .modifier(CombatantDetailSheet(
            selection: allowedSelection,
            artworkNames: { CombatantDetailPane.artworkNames(
                combatant: $0.combatant,
                loadout: $0.combatant.abilityLoadout,
                equipmentLoadout: $0.equipmentLoadout,
                inventoryItems: $0.inventoryItems,
            ) },
            detailContent: { detail in LibraryEnemyDetailContent(detail: detail) },
        ))
        .onChange(of: playerSave.sessionGeneration) { _, _ in selection = nil }
        .task(id: visibleIDs) {
            await ArtworkViewportPrewarm.prewarm(
                orderedItems: GameContent.enemies, visibleIDs: visibleIDs, currentVisibleIDs: { visibleIDs },
                thumbnailName: { $0.combatant.artReference?.thumbnailImageName },
                prefetchRows: 1, estimatedColumns: 1,
            )
        }
    }
}

struct LibraryEnemyArtwork: View {
    let enemy: Enemy
    let discovered: Bool

    var body: some View {
        CombatantArtwork(combatant: enemy.combatant, variant: .card)
            .aspectRatio(1200.0 / 896, contentMode: .fit)
            .saturation(discovered ? 1 : 0)
            .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.card))
            .accessibilityHidden(true)
    }
}

enum LibraryEnemyDetail {
    static func snapshot(_ enemy: Enemy, roster: PlayerRosterState) -> CombatantCardDetail {
        let scale = EncounterScaling.contract(.standard).resolve(partyAverageLevel: roster.activePartyAverageLevel)
        let progression = CombatantProgression.at(level: scale.level)
        return CombatantCardDetail(
            combatant: CombatantLevelScaler.scale(enemy: enemy, level: scale.level, profile: scale.profile),
            progression: progression,
        )
    }
}

struct LibraryEnemyDetailContent: View {
    let detail: CombatantCardDetail

    var body: some View {
        CombatantDetailPane(snapshot: detail)
            .safeAreaInset(edge: .bottom) {
                Text(L10n.library_enemy_reference)
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(.secondary)
                    .padding(TrinketDesign.Spacing.small)
                    .frame(maxWidth: .infinity)
                    .trinketScreenBackground()
            }
    }
}

struct LibraryResearchView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(ShellSession.self) private var shell
    @Environment(\.locale) private var locale
    @State private var requestedProject: ResearchProject?
    @State private var preparedProject: ResearchProject?
    @State private var completedAtOpening: Set<String>?

    private var history: LibraryProgress {
        playerSave.library.progress
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                section(completed: false)
                section(completed: true)
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .navigationTitle(Text(L10n.library_research))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .trinketScreenBackground()
        .trinketSoftTopScrollEdge()
        .accessibilityIdentifier(AccessibilityID.Homestead.research)
        .preparingArtwork(request: $requestedProject, presentation: $preparedProject) {
            LibraryArtworkNames.forRoute(.researchProject($0.id))
        }
        .onChange(of: preparedProject) { _, project in
            guard let project, playerSave.library.isReadable else { return }
            LibraryNavigation.open(.researchProject(project.id), in: shell)
        }
        .onChange(of: playerSave.sessionGeneration) { _, _ in requestedProject = nil; preparedProject = nil }
        .onAppear {
            if completedAtOpening == nil {
                completedAtOpening = history.completedResearchIDs
            }
            preparedProject = nil
        }
    }

    @ViewBuilder
    private func section(completed: Bool) -> some View {
        let projects = ResearchProject.all.filter { (completedAtOpening ?? history.completedResearchIDs).contains($0.id) == completed }
        if !projects.isEmpty {
            Text(completed ? L10n.library_completed : L10n.library_in_progress)
                .trinketTypography(.sectionTitle)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(projects) { project in
                    Button { requestedProject = project } label: {
                        HStack(spacing: TrinketDesign.Spacing.medium) {
                            if !completed, let recipe = project.recipeID.flatMap(EquipmentRecipe.matching) {
                                LibraryRecipeArtwork(recipe: recipe).frame(width: 60)
                            }
                            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                                Text(LibraryCopy.title(project.id, locale: locale)).trinketTypography(.rowTitle)
                                if !completed, let recipe = project.recipeID.flatMap(EquipmentRecipe.matching) {
                                    Text(LibraryCopy.recipe(recipe, locale: locale)).foregroundStyle(.secondary)
                                }
                                if !completed {
                                    projectProgress(project)
                                }
                            }
                            Spacer(minLength: 0)
                            if history.completedResearchIDs.contains(project.id) {
                                ResearchCheck(complete: true)
                            }
                            Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, TrinketDesign.Spacing.medium)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Homestead.researchProject(project.id))
                    if project.id != projects.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func projectProgress(_ project: ResearchProject) -> some View {
        let progress = project.progress(
            in: history,
            companionIDs: playerSave.roster.unlockedCompanionIDs,
            highestSpireFloor: GameContent.spires.map { playerSave.spires.highestClearedFloor(for: $0.id.rawValue) }.max() ?? 0,
        )
        if progress.allSatisfy(\.self), playerSave.homestead.tier(for: .library) < project.minimumLibraryTier {
            Text(LibraryCopy.tier(project.minimumLibraryTier, locale: locale)).foregroundStyle(.secondary)
        } else if case let .companions(count) = project.objectives.first {
            Text("\(min(count, playerSave.roster.companions.count))/\(count)").monospacedDigit()
        } else if case let .spireFloor(floor) = project.objectives.first {
            let highest = GameContent.spires.map { playerSave.spires.highestClearedFloor(for: $0.id.rawValue) }.max() ?? 0
            Text("\(min(floor, highest))/\(floor)").monospacedDigit()
        } else {
            HStack(spacing: TrinketDesign.Spacing.small) {
                ForEach(Array(project.objectives.enumerated()), id: \.element) { index, _ in
                    ResearchCheck(complete: progress[index])
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(LibraryCopy.progress(progress.count(where: { $0 }), total: progress.count, locale: locale))
        }
    }
}

struct LibraryResearchProjectView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(ShellSession.self) private var shell
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var objectiveWidth = 94.0
    @State private var selection: CombatantCardDetail?
    @State private var artworkPins = PreparedArtworkPinSet()
    let project: ResearchProject
    var onRecipe: ((EquipmentRecipe) -> Void)?
    var onEnemy: ((Enemy) -> Void)?

    private var progress: [Bool] {
        project.progress(
            in: playerSave.library.progress,
            companionIDs: playerSave.roster.unlockedCompanionIDs,
            highestSpireFloor: GameContent.spires.map { playerSave.spires.highestClearedFloor(for: $0.id.rawValue) }.max() ?? 0,
        )
    }

    private var allowedSelection: Binding<CombatantCardDetail?> {
        Binding(get: {
            guard let selection, playerSave.library.isReadable,
                  playerSave.library.progress.encounteredEnemyIDs.contains(selection.id) else { return nil }
            return selection
        }, set: { selection = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                if let recipe = project.recipeID.flatMap(EquipmentRecipe.matching) {
                    Button {
                        if let onRecipe {
                            onRecipe(recipe)
                        } else {
                            LibraryNavigation.open(.researchRecipe(recipe.id), in: shell)
                        }
                    } label: {
                        VStack(spacing: TrinketDesign.Spacing.small) {
                            LibraryRecipeArtwork(recipe: recipe).frame(width: 126)
                            HStack(spacing: TrinketDesign.Spacing.small) {
                                Text(LibraryCopy.recipe(recipe, locale: locale))
                                Image(systemName: "chevron.right").accessibilityHidden(true)
                            }.trinketTypography(.rowTitle)
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Homestead.researchReward(project.id))
                }
                if project.objectives.contains(where: {
                    if case .defeat = $0 {
                        true
                    } else {
                        false
                    }
                }) {
                    Text(L10n.library_defeat).trinketTypography(.sectionTitle)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: objectiveWidth), alignment: .top)], alignment: .leading) {
                        ForEach(Array(project.objectives.enumerated()), id: \.element) { index, objective in
                            if case let .defeat(id) = objective, let enemy = GameContent.enemy(matching: id) {
                                objectiveCard(enemy, complete: progress[index])
                            }
                        }
                    }
                } else {
                    HStack(spacing: TrinketDesign.Spacing.small) {
                        ResearchCheck(complete: progress.allSatisfy(\.self))
                        Text(project.id == "companion-chronicles" ? LibraryCopy.localized(L10n.library_goal_companions, locale: locale)
                            : LibraryCopy.localized(L10n.library_goal_spire, locale: locale))
                    }
                    if project.id == "companion-chronicles" {
                        Text("\(min(3, playerSave.roster.companions.count))/3").monospacedDigit().foregroundStyle(.secondary)
                    } else {
                        let floor = GameContent.spires.map { playerSave.spires.highestClearedFloor(for: $0.id.rawValue) }.max() ?? 0
                        Text("\(min(10, floor))/10").monospacedDigit().foregroundStyle(.secondary)
                    }
                    if playerSave.library.progress.completedResearchIDs.contains(project.id) {
                        Text(LibraryCopy.archive(project.id, locale: locale)).foregroundStyle(.secondary)
                    }
                }
                if playerSave.homestead.tier(for: .library) < project.minimumLibraryTier {
                    Text(LibraryCopy.tier(project.minimumLibraryTier, locale: locale)).foregroundStyle(.secondary)
                }
            }
            .padding(TrinketDesign.Layout.contentMargin)
        }
        .navigationTitle(LibraryCopy.title(project.id, locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .trinketScreenBackground()
        .trinketSoftTopScrollEdge()
        .accessibilityIdentifier(AccessibilityID.Homestead.researchProjectDetail(project.id))
        .modifier(CombatantDetailSheet(
            selection: allowedSelection,
            artworkNames: { CombatantDetailPane.artworkNames(
                combatant: $0.combatant,
                loadout: $0.combatant.abilityLoadout,
                equipmentLoadout: $0.equipmentLoadout,
                inventoryItems: $0.inventoryItems,
            ) },
            detailContent: { LibraryEnemyDetailContent(detail: $0) },
        ))
        .task(id: project.id) { await artworkPins.prepare(names: LibraryArtworkNames.forRoute(.researchProject(project.id))) }
        .onDisappear { artworkPins.release() }
        .onChange(of: playerSave.sessionGeneration) { _, _ in selection = nil }
    }

    private func objectiveCard(_ enemy: Enemy, complete: Bool) -> some View {
        let discovered = playerSave.library.isReadable && playerSave.library.progress.encounteredEnemyIDs.contains(enemy.id)
        return VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            Button {
                guard discovered else { return }
                if let onEnemy {
                    onEnemy(enemy)
                } else {
                    selection = LibraryEnemyDetail.snapshot(enemy, roster: playerSave.roster)
                }
            } label: { LibraryEnemyArtwork(enemy: enemy, discovered: discovered) }
                .trinketArtworkCardButtonStyle()
                .disabled(!discovered)
                .accessibilityLabel(ContentCopy.localized(enemy.name))
                .accessibilityIdentifier(AccessibilityID.Homestead.researchEnemy(enemy.id))
            HStack(alignment: .top, spacing: TrinketDesign.Spacing.extraSmall) {
                ResearchCheck(complete: complete)
                Text(ContentCopy.localized(enemy.name)).trinketTypography(.cardLabel)
            }
        }
    }
}

struct LibraryRecipeArtwork: View {
    let recipe: EquipmentRecipe
    var body: some View {
        Group {
            if let art = recipe.forgeArtwork {
                Image.preparedAsset(art, displaySize: .compact).resizable().aspectRatio(contentMode: .fill)
            }
        }
        .aspectRatio(3.0 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.card))
        .clipped()
        .accessibilityHidden(true)
    }
}

struct ResearchCheck: View {
    let complete: Bool
    var body: some View {
        Image(systemName: complete ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(complete ? TrinketDesign.Colors.accent : .secondary)
            .accessibilityHidden(true)
    }
}

@MainActor
enum LibraryNavigation {
    static func open(_ route: HomesteadRoute, in shell: ShellSession) {
        if let index = shell.homesteadPath.firstIndex(of: route) {
            shell.homesteadPath = Array(shell.homesteadPath.prefix(through: index))
        } else {
            shell.homesteadPath.append(route)
        }
    }
}

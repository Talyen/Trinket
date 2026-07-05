import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

enum CombatantDetailNavigationChrome {
    case visible
    case hidden
}

struct CombatantDetailPane: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    let allowsEditing: Bool
    var battleHealth: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var navigationChrome: CombatantDetailNavigationChrome = .visible
    @Binding var selectedItemSlot: ItemSlot?

    @State private var headerHeight: CGFloat = 300
    @State private var heroOverscroll: CGFloat = 0
    @State private var titleOpacity: CGFloat = 0

    private var combatBuild: CombatBuild {
        CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items
        )
    }

    private var heroOrPetTrait: CombatantTraitDefinition? {
        GameContent.trait(forCombatantID: combatant.id)
    }

    private var enemyTraits: [CombatantTraitDefinition] {
        guard combatant.role == .enemy,
              let enemy = GameContent.enemy(matching: combatant.id)
        else { return [] }
        return GameContent.traits(for: enemy)
    }

    private var effectiveCombatant: Combatant {
        combatBuild.combatant
    }

    var body: some View {
        GeometryReader { geometry in
            let baseHeaderHeight = HeroHeaderLayout.headerHeight(forWidth: geometry.size.width)

            ScrollView {
                VStack(spacing: 0) {
                    CombatantHeroHeader(
                        combatant: combatant,
                        progression: progression,
                        baseHeight: baseHeaderHeight,
                        overscroll: heroOverscroll
                    )
                    .accessibilityIdentifier("\(combatant.name) detail hero header")

                    VStack(alignment: .leading, spacing: 0) {
                        section("Stats", sectionID: AccessibilityID.CombatantDetail.statsSection) {
                            statRow(
                                "Health",
                                value: "\(currentHealth)/\(combatBuild.effectiveMaxHealth)",
                                accessibilityIdentifier: AccessibilityID.CombatantDetail.healthStat
                            )
                            if combatBuild.effectiveMaxMana > 0 {
                                statRow("Mana", value: "\(combatBuild.effectiveMaxMana) MP")
                            }
                            statRow("Strength", value: "\(effectiveCombatant.primaryStats.strength)")
                            statRow("Agility", value: "\(effectiveCombatant.primaryStats.agility)")
                            statRow("Toughness", value: "\(effectiveCombatant.primaryStats.toughness)")
                            statRow("Intellect", value: "\(effectiveCombatant.primaryStats.intellect)")
                            statRow("Wisdom", value: "\(effectiveCombatant.primaryStats.wisdom)")
                        }

                        if let heroOrPetTrait {
                            traitSection(
                                title: "Trait",
                                trait: heroOrPetTrait,
                                sectionID: AccessibilityID.CombatantDetail.traitSection,
                                descriptionID: AccessibilityID.CombatantDetail.traitDescription
                            )
                        }

                        if !enemyTraits.isEmpty {
                            traitSection(
                                title: "Traits",
                                traits: enemyTraits,
                                sectionID: AccessibilityID.CombatantDetail.enemyTraitsSection,
                                descriptionID: AccessibilityID.CombatantDetail.enemyTraitDescription
                            )
                        }

                        if !activeEffectSummaries.isEmpty {
                            section("Active Effects") {
                                ForEach(activeEffectSummaries) { summary in
                                    KeywordDescriptionText(text: summary.text)
                                        .font(.subheadline)
                                        .accessibilityElement(children: .combine)
                                }
                            }
                        }

                        section("Abilities") {
                            AbilitySummaryGrid(
                                combatant: combatant,
                                progression: progression,
                                loadout: $loadout,
                                allowsEditing: allowsEditing
                            )
                            .padding(.vertical, 4)
                        }

                        section("Items") {
                            EquipmentSlotSummaryGrid(
                                role: combatant.role,
                                equipmentLoadout: equipmentLoadout,
                                inventoryState: inventoryState,
                                onSelect: allowsEditing ? { selectedItemSlot = $0 } : nil
                            )
                            .padding(.vertical, 4)
                        }
                    }
                    .trinketScreenBackground(.collection)
                }
            }
            .ignoresSafeArea(edges: .top)
            .trinketScreenBackground(.collection)
            .combatantDetailNavigationChrome(navigationChrome, title: combatant.name, titleOpacity: titleOpacity)
            .onAppear {
                headerHeight = baseHeaderHeight
            }
            .onChange(of: baseHeaderHeight) { _, newHeight in
                headerHeight = newHeight
            }
            .onScrollGeometryChange(for: ScrollState.self) { geometry in
                ScrollState(
                    offsetY: geometry.contentOffset.y + geometry.contentInsets.top,
                    topInset: geometry.contentInsets.top,
                    overscroll: HeroHeaderLayout.overscroll(
                        contentOffsetY: geometry.contentOffset.y,
                        topInset: geometry.contentInsets.top
                    )
                )
            } action: { _, state in
                let threshold = headerHeight - state.topInset - 44
                heroOverscroll = state.overscroll
                titleOpacity = min(max((state.offsetY - threshold) / 20, 0), 1)
            }
        }
    }

    private func traitSection(
        title: String,
        trait: CombatantTraitDefinition,
        sectionID: String,
        descriptionID: String
    ) -> some View {
        traitSection(title: title, traits: [trait], sectionID: sectionID, descriptionID: descriptionID)
    }

    private func traitSection(
        title: String,
        traits: [CombatantTraitDefinition],
        sectionID: String,
        descriptionID: String
    ) -> some View {
        section(title, sectionID: sectionID) {
            ForEach(traits) { trait in
                VStack(alignment: .leading, spacing: 4) {
                    Text(trait.name)
                        .font(.body.weight(.semibold))
                    KeywordDescriptionText(text: trait.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(descriptionID)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, sectionID: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.top, TrinketDesign.Metrics.contentTopPadding)
                .accessibilityIdentifier(sectionID ?? title)

            content()
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
    }

    private var currentHealth: Int {
        battleHealth ?? combatBuild.effectiveMaxHealth
    }

    private func statRow(_ title: String, value: String, accessibilityIdentifier: String? = nil) -> some View {
        LabeledContent {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        } label: {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }

    private struct ScrollState: Equatable {
        var offsetY: CGFloat
        var topInset: CGFloat
        var overscroll: CGFloat
    }
}

private extension View {
    @ViewBuilder
    func combatantDetailNavigationChrome(
        _ chrome: CombatantDetailNavigationChrome,
        title: String,
        titleOpacity: CGFloat
    ) -> some View {
        switch chrome {
        case .visible:
            navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.headline)
                            .opacity(titleOpacity)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        case .hidden:
            toolbar(.hidden, for: .navigationBar)
        }
    }
}

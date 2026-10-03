import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
struct BattleTransitionsPreviewView<Content: View>: View {
    @ViewBuilder let content: (Stage) -> Content
    @State private var artworkLease: PreparedArtworkLease?

    var body: some View {
        Group {
            if artworkLease != nil {
                content(BattleTransitionsSample.stage)
            } else {
                ProgressView()
            }
        }
        .task {
            let prepared = await PreparedArtworkLease(names: artworkNames)
            guard !Task.isCancelled else { return }
            artworkLease = prepared
        }
        .onDisappear { artworkLease = nil }
    }

    private var artworkNames: [String] {
        var names = [String]()
        if let art = ArtCatalog.backgroundArtByID[BattleTransitionsSample.chapter.id] {
            names.append(art.imageName)
        }
        for sample in BattleTransitionsSample.stages {
            if let art = EncounterArtwork.reference(for: sample, resolvedMysteryEvent: nil, worldSeed: 1772) {
                names.append(art.imageName)
                if let thumbnail = art.preparedThumbnailImageName {
                    names.append(thumbnail)
                }
            }
        }
        return names
    }
}

private enum BattleTransitionsSample {
    static let chapter = GameContent.chapters[0]
    static let stage = chapter.stages.first { $0.encounter.isCombat } ?? chapter.stages[0]
    static let stages = Array(chapter.stages.filter { $0.stageNumber >= stage.stageNumber }.prefix(4))
}

struct BattleTransitionsStagePicker: View {
    let enterBattle: () -> Bool
    private var chapter: Chapter {
        BattleTransitionsSample.chapter
    }

    private var stage: Stage {
        BattleTransitionsSample.stage
    }

    var body: some View {
        StageSelectScreen(
            eyebrow: "Chapter \(chapter.number)".uppercased(),
            title: chapter.title,
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.BattleTransitionLab.picker,
        ) {
            if let art = ArtCatalog.backgroundArtByID[chapter.id] {
                FocalBackgroundArtwork(art: art)
            } else {
                chapter.theme.tint
            }
        } content: {
            StageSelectList(
                rows: BattleTransitionsSample.stages.map(row),
                hapticsEnabledOverride: false,
                isPrimaryActionDisabled: { $0.id != stage.id },
                onArtworkTap: { _ in },
                onPrimaryAction: { sample in sample.id == stage.id && enterBattle() },
                artwork: { sample, isActive in
                    EncounterArtwork(stage: sample, worldSeed: 1772, prefersThumbnail: !isActive)
                },
                partyPickerSheet: { _ in EmptyView() },
            )
        }
    }

    private func row(_ sample: Stage) -> StageSelectRowPresentation<Stage> {
        StageSelectRowPresentation(
            item: sample,
            isActive: sample.id == stage.id,
            activeEyebrow: sample.mapLabel,
            mapLabel: sample.mapLabel,
            title: sample.encounterSubjectName(worldSeed: 1772),
            encounterTypeTitle: sample.encounterTypeTitle,
            icon: GameIcon(id: sample.encounter.iconID),
            tint: sample.encounter.mapTint,
            primaryActionTitle: "Battle",
            showsPartyPicker: false,
            isArtworkInteractive: false,
            rowAccessibilityID: AccessibilityID.BattleTransitionLab.stageRow(sample.id),
            artworkAccessibilityID: AccessibilityID.BattleTransitionLab.stageArtwork(sample.id),
            actionAccessibilityID: AccessibilityID.BattleTransitionLab.enterBattle,
            activeDetailAccessibilityID: AccessibilityID.BattleTransitionLab.stageDetail,
            partyControlAccessibilityID: "",
        )
    }
}
#endif

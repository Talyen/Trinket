import Observation
import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketFeatureSupport

struct PlayEncounterCoversModifier: ViewModifier {
    @Environment(EncounterPlayMode.self) private var encounters
    @Environment(\.isLaunchPresentationReady) private var isLaunchPresentationReady
    @State private var presentedEncounter: PreparedEncounterCover?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $presentedEncounter) { presentation in
                EncounterCoverContent(presentation: presentation)
                    .interactiveDismissDisabled()
            }
            .onChange(of: activeEncounter?.id) { _, id in
                if presentedEncounter?.id != id {
                    presentedEncounter = nil
                }
            }
            .task(id: isLaunchPresentationReady ? activeEncounter?.id : nil) {
                guard isLaunchPresentationReady, let encounter = activeEncounter,
                      presentedEncounter?.id != encounter.id else { return }
                let presentation = await PreparedEncounterCover(
                    encounter: encounter,
                    worldSeed: encounters.playerSave.worldSeed,
                )
                guard !Task.isCancelled, activeEncounter?.id == encounter.id else { return }
                presentedEncounter = presentation
            }
    }

    private var activeEncounter: EncounterCoverSession? {
        if let session = encounters.activeMysteryEncounter {
            return .mystery(session)
        }
        if let session = encounters.activeShopEncounter {
            return .shop(session)
        }
        return nil
    }
}

private struct EncounterCoverContent: View {
    @Environment(EncounterPlayMode.self) private var encounters
    let presentation: PreparedEncounterCover

    var body: some View {
        Group {
            switch presentation.encounter {
            case let .mystery(session):
                MysteryEncounterView(session: session, preparedArtworkNames: presentation.artworkNames)
            case let .shop(session):
                ShopEncounterView(session: session, onLeave: encounters.finishActiveShopEncounter)
            }
        }
        .task(id: artworkNames) {
            await presentation.refreshArtwork(names: artworkNames)
        }
    }

    private var artworkNames: [String] {
        Array(Set(presentation.encounter.artworkNames(worldSeed: encounters.playerSave.worldSeed))).sorted()
    }
}

@MainActor
private enum EncounterCoverSession {
    case mystery(MysteryEncounterSession)
    case shop(ShopEncounterSession)

    var id: ObjectIdentifier {
        switch self {
        case let .mystery(session): ObjectIdentifier(session)
        case let .shop(session): ObjectIdentifier(session)
        }
    }

    func artworkNames(worldSeed: UInt64) -> [String] {
        switch self {
        case let .mystery(session):
            let hero = MysteryEventArtwork.preparedReference(event: session.event, chapterID: session.stage.chapterID)?.imageName
            let recruit = session.combatant?.artReference?.imageName
                ?? session.unlockedCombatantID.flatMap { GameContent.combatant(matching: $0)?.artReference?.imageName }
            return [hero, recruit].compactMap(\.self)
                + session.offers.flatMap { offer in
                    [offer.item.artReference?.imageName, offer.item.artReference?.thumbnailImageName].compactMap(\.self)
                }
        case let .shop(session):
            let hero = session.stage.encounterCombatantArtReference(worldSeed: worldSeed)?.imageName
                ?? session.stage.encounterArtReference?.imageName
            return [hero].compactMap(\.self)
                + session.offers.flatMap { offer in
                    [offer.item.artReference?.imageName, offer.item.artReference?.thumbnailImageName].compactMap(\.self)
                }
        }
    }
}

@MainActor
@Observable
private final class PreparedEncounterCover: Identifiable {
    nonisolated let id: ObjectIdentifier
    let encounter: EncounterCoverSession
    private(set) var artworkNames: [String]

    init(encounter: EncounterCoverSession, worldSeed: UInt64) async {
        id = encounter.id
        self.encounter = encounter
        artworkNames = Array(Set(encounter.artworkNames(worldSeed: worldSeed))).sorted()
        await PreparedArtworkCache.shared.prepareAndPin(names: artworkNames)
    }

    func refreshArtwork(names: [String]) async {
        let refreshed = await ArtworkPinSet.refresh(next: names, current: artworkNames)
        guard !Task.isCancelled else { return }
        artworkNames = refreshed
    }

    isolated deinit {
        PreparedArtworkCache.shared.releasePins(names: artworkNames)
    }
}

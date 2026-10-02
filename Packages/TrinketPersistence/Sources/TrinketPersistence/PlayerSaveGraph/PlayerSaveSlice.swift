import Foundation

/// Sections share stable slice bits across comparison, copying, graph writes,
/// and repair. Sanitizer dependencies are ordered by `PlayerSaveSanitizer`,
/// independently of this declaration order.
/// Cloud sync metadata lives outside these domain slices.
enum PlayerSaveSection: Int, CaseIterable {
    case root = 0
    case inventory = 3
    case roster = 2
    case homestead = 4
    case journey = 1
    case spires = 5
    case voyage = 8
    case contracts = 7
    case labyrinth = 6

    var slice: PlayerSaveSlice {
        PlayerSaveSlice(rawValue: 1 << rawValue)
    }

    func domainDiffers(between snapshot: PlayerSave, and candidate: PlayerSave) -> Bool {
        switch self {
        case .root:
            snapshot.schemaVersion != candidate.schemaVersion
                || snapshot.worldSeed != candidate.worldSeed
                || snapshot.starterSelection != candidate.starterSelection
                || snapshot.corruptionAltarCooldownRemaining != candidate.corruptionAltarCooldownRemaining
        case .journey: snapshot.journey != candidate.journey
        case .roster: snapshot.roster != candidate.roster
        case .inventory: snapshot.inventory != candidate.inventory
        case .homestead: snapshot.homestead != candidate.homestead
        case .spires: snapshot.spires != candidate.spires
        case .labyrinth: snapshot.labyrinth != candidate.labyrinth
        case .contracts: snapshot.contracts != candidate.contracts
        case .voyage: snapshot.voyage != candidate.voyage
        }
    }

    func differs(between snapshot: PlayerSave, and candidate: PlayerSave) -> Bool {
        if self == .root {
            return domainDiffers(between: snapshot, and: candidate)
                || snapshot.modifiedAt != candidate.modifiedAt
                || snapshot.sessionGeneration != candidate.sessionGeneration
        }
        return domainDiffers(between: snapshot, and: candidate)
    }

    func copy(from source: PlayerSave, into destination: inout PlayerSave) {
        switch self {
        case .root: destination.applyRootFields(from: source)
        case .journey: destination.journey = source.journey
        case .roster: destination.roster = source.roster
        case .inventory: destination.inventory = source.inventory
        case .homestead: destination.homestead = source.homestead
        case .spires: destination.spires = source.spires
        case .labyrinth: destination.labyrinth = source.labyrinth
        case .contracts: destination.contracts = source.contracts
        case .voyage: destination.voyage = source.voyage
        }
    }
}

struct PlayerSaveSlice: OptionSet {
    let rawValue: UInt16

    static let root = PlayerSaveSection.root.slice
    static let journey = PlayerSaveSection.journey.slice
    static let roster = PlayerSaveSection.roster.slice
    static let inventory = PlayerSaveSection.inventory.slice
    static let homestead = PlayerSaveSection.homestead.slice
    static let spires = PlayerSaveSection.spires.slice
    static let labyrinth = PlayerSaveSection.labyrinth.slice
    static let contracts = PlayerSaveSection.contracts.slice
    static let voyage = PlayerSaveSection.voyage.slice
    static let all = PlayerSaveSection.allCases.reduce(into: Self(rawValue: 0)) { $0.insert($1.slice) }

    var sections: [PlayerSaveSection] {
        PlayerSaveSection.allCases.filter { contains($0.slice) }
    }

    static func changed(
        between snapshot: PlayerSave,
        and candidate: PlayerSave,
        within candidates: Self = .all,
    ) -> Self {
        var slices: Self = []
        for section in PlayerSaveSection.allCases {
            guard candidates.contains(section.slice),
                  section.differs(between: snapshot, and: candidate)
            else { continue }
            slices.insert(section.slice)
        }
        return slices
    }

    static func persistTargets(for sanitizeSlices: Self) -> Self {
        sanitizeSlices.union(.root)
    }

    static func sanitizeTargets(for mutationSlices: Self) -> Self {
        var targets = mutationSlices
        if targets.contains(.inventory) {
            targets.insert(.roster)
        }
        if targets.contains(.labyrinth) {
            targets.insert(.roster)
        }
        return targets
    }

    static func prepareCandidate(
        from snapshot: PlayerSave,
        candidate proposed: PlayerSave,
    ) throws -> (candidate: PlayerSave, changedSlices: Self) {
        var candidate = proposed
        let mutationSlices = changed(between: snapshot, and: candidate)
        guard !mutationSlices.isEmpty else { return (snapshot, []) }
        let sanitizeSlices = sanitizeTargets(for: mutationSlices)
        candidate = try PlayerSaveSanitizer.sanitizeAndValidate(candidate, changedSlices: sanitizeSlices)
        var changedSlices = changed(
            between: snapshot,
            and: candidate,
            within: persistTargets(for: sanitizeSlices),
        )
        if !changedSlices.isEmpty {
            candidate.modifiedAt = Date()
            changedSlices.insert(.root)
        }
        return (candidate, changedSlices)
    }
}

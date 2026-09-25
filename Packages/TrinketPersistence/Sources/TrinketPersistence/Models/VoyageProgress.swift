import Foundation
import TrinketContent
import TrinketCore

public struct VoyageRun: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        offer.id
    }

    public let offer: VoyageOffer
    public var nodes: [VoyageNode]
    public var earnedGold = 0
    public var earnedMaterials: [HomesteadResource: Int] = [:]
    public var isComplete: Bool {
        nodes.allSatisfy(\.isCleared)
    }

    public var nextNode: VoyageNode? {
        nodes.first { !$0.isCleared }
    }

    public init(offer: VoyageOffer, nodes: [VoyageNode]) {
        self.offer = offer
        self.nodes = nodes
    }

    public func node(id: String) -> VoyageNode? {
        nodes.first { $0.id == id }
    }

    public mutating func updateNode(id: String, _ update: (inout VoyageNode) -> Void) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        update(&nodes[index])
    }
}

public struct PlayerVoyageState: Codable, Equatable, Sendable {
    public static let freshStart = Self()
    public private(set) var version = 1
    public private(set) var offers: [VoyageOffer] = []
    public var activeRun: VoyageRun?
    public private(set) var unreadablePayload: Data?
    public var isUnreadable: Bool {
        unreadablePayload != nil
    }

    public init() {}

    public mutating func ensureBoard(access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases) {
        guard !isUnreadable, activeRun == nil else { return }
        let allowed = Self.chapterIDs(access: access)
        if offers.count != 3 || Set(offers.map(\.chapterID)).count != 3
            || offers.contains(where: { !allowed.contains($0.chapterID) }) {
            refresh(access: access, eligibleModifiers: eligibleModifiers)
        }
    }

    public mutating func refresh(access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases) {
        guard !isUnreadable, activeRun == nil else { return }
        var chapters = Self.chapterIDs(access: access).shuffled()
        var modifiers = eligibleModifiers.isEmpty ? [.gold] : eligibleModifiers.shuffled()
        offers = VoyageDifficulty.allCases.compactMap { difficulty in
            guard let chapterID = chapters.popLast() else { return nil }
            if modifiers.isEmpty {
                modifiers = eligibleModifiers.shuffled()
            }
            return Self.offer(chapterID: chapterID, difficulty: difficulty, modifier: modifiers.popLast() ?? .gold)
        }
    }

    @discardableResult
    public mutating func embark(
        offerID: String, eligibleRecruitEventIDs: [String], access: ContentAccessPolicy,
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> Bool {
        guard !isUnreadable, activeRun == nil, let offer = offers.first(where: { $0.id == offerID }),
              Self.chapterIDs(access: access).contains(offer.chapterID) else { return false }
        activeRun = VoyageRun(
            offer: offer,
            nodes: VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards),
        )
        return true
    }

    public mutating func replaceOffer(
        runID: String, access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
    ) {
        guard let index = offers.firstIndex(where: { $0.id == runID }) else { return }
        let previous = offers[index]
        let used = Set(offers.map(\.chapterID))
        let candidates = Self.chapterIDs(access: access).filter { !used.contains($0) }
        let usedModifiers = Set(offers.enumerated().filter { $0.offset != index }.map(\.element.rewardModifier))
        let pool = eligibleModifiers.filter { !usedModifiers.contains($0) }
        let modifier = (pool.isEmpty ? eligibleModifiers : pool).randomElement() ?? .gold
        offers[index] = Self.offer(
            chapterID: candidates.randomElement() ?? previous.chapterID,
            difficulty: previous.difficulty, modifier: modifier,
        )
    }

    @discardableResult
    public mutating func abandon(
        runID: String, access: ContentAccessPolicy, eligibleModifiers: [RewardModifier] = RewardModifier.allCases,
    ) -> Bool {
        guard !isUnreadable, let run = activeRun, run.id == runID, !run.isComplete else { return false }
        replaceOffer(runID: runID, access: access, eligibleModifiers: eligibleModifiers)
        activeRun = nil
        return true
    }

    public mutating func dismissCompleted() {
        guard activeRun?.isComplete == true else { return }
        activeRun = nil
    }

    public func node(runID: String, nodeID: String) -> VoyageNode? {
        guard !isUnreadable, activeRun?.id == runID else { return nil }
        return activeRun?.node(id: nodeID)
    }

    public mutating func updateNode(runID: String, nodeID: String, _ update: (inout VoyageNode) -> Void) {
        guard !isUnreadable, activeRun?.id == runID else { return }
        activeRun?.updateNode(id: nodeID, update)
    }

    public func isPlayable(runID: String, nodeID: String) -> Bool {
        !isUnreadable && activeRun?.id == runID && activeRun?.nextNode?.id == nodeID
    }

    public var encodedPayload: Data {
        if let unreadablePayload {
            return unreadablePayload
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do { return try encoder.encode(self) } catch { preconditionFailure("Voyage state must be encodable") }
    }

    public static func decodePayload(_ data: Data?) -> Self {
        guard let data else { return .freshStart }
        do {
            let state = try JSONDecoder().decode(Self.self, from: data)
            if state.isValid {
                return state
            }
        } catch {
            // Preserve unknown or damaged bytes instead of replacing progress.
        }
        var state = Self()
        state.unreadablePayload = data
        return state
    }

    func sanitized() -> Self {
        guard !isUnreadable, !isValid else { return self }
        var preserved = Self()
        preserved.unreadablePayload = encodedPayload
        return preserved
    }

    private var isValid: Bool {
        guard version == 1, offers.isEmpty || (offers.count == 3 && Set(offers.map(\.id)).count == 3
            && Set(offers.map(\.difficulty)).count == 3 && Set(offers.map(\.chapterID)).count == 3),
            offers.allSatisfy({ !$0.id.isEmpty && VoyageCatalog.bossID(chapterID: $0.chapterID) != nil }) else { return false }
        guard let run = activeRun else { return true }
        guard run.nodes.count == run.offer.difficulty.nodeCount, Set(run.nodes.map(\.id)).count == run.nodes.count,
              run.nodes.first?.type == .battle, run.nodes.last?.type == .boss,
              run.earnedGold >= 0, run.earnedMaterials.values.allSatisfy({ $0 >= 0 }),
              VoyageCatalog.bossID(chapterID: run.offer.chapterID) != nil else { return false }
        var foundUncleared = false
        for node in run.nodes {
            if foundUncleared && node.isCleared {
                return false
            }
            foundUncleared = foundUncleared || !node.isCleared
            if node.type == .entrance || node.id.isEmpty {
                return false
            }
            if node.type.isCombat, node.enemyID.flatMap({ GameContent.enemy(matching: $0) }) == nil {
                return false
            }
            if node.modifierIDs.contains(where: { LabyrinthCatalog.modifier(id: $0) == nil }) {
                return false
            }
        }
        return true
    }

    private static func chapterIDs(access: ContentAccessPolicy) -> [String] {
        GameContent.chapters.filter { access.allowsChapter($0.number) && VoyageCatalog.bossID(chapterID: $0.id) != nil }.map(\.id)
    }

    private static func offer(chapterID: String, difficulty: VoyageDifficulty, modifier: RewardModifier) -> VoyageOffer {
        VoyageOffer(
            id: UUID().uuidString, chapterID: chapterID, difficulty: difficulty,
            seed: UInt64.random(in: .min ... .max), rewardModifier: modifier,
        )
    }
}

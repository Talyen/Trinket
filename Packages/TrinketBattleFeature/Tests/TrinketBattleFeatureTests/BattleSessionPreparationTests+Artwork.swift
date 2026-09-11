import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import TrinketBattleFeature

extension BattleSessionPreparationTests {
    @Test func `artwork replacement balances overlapping pins`() async {
        let pins = ArtworkPinRecorder()
        let preparation = pins.makePreparation()
        pins.acquire(["shared"])

        await preparation.prepare(names: ["shared", "old"], displayScale: 1) {}
        await preparation.prepare(names: ["shared", "new"], displayScale: 1) {}
        let acquisitions = pins.acquisitions
        await preparation.prepare(names: ["shared", "new"], displayScale: 1) {}
        #expect(pins.acquisitions == acquisitions)
        #expect(pins.counts == ["shared": 2, "new": 1])

        preparation.release()
        preparation.release()
        #expect(pins.counts == ["shared": 1])
    }

    @Test func `pruning prepared artwork releases only discarded runs`() async throws {
        let pins = ArtworkPinRecorder()
        let session = BattleSession(openingHandDrawStagger: 0)
        session.artworkPreparation = pins.makePreparation()
        let first = artworkConfiguration(key: "first", abilities: [.slash])
        let second = artworkConfiguration(key: "second", abilities: [.heal])
        let firstKey = try #require(first.runKey)
        let firstNames = try Set([#require(Ability.slash.artReference?.imageName)])
        let secondNames = try Set([#require(Ability.heal.artReference?.imageName)])
        #expect(firstNames.isDisjoint(with: secondNames))
        #expect(session.prepareBattleRun(first))
        await session.prepareBattlePresentationAssets(displayScale: 1)
        #expect(session.prepareBattleRun(second))
        #expect(Set(pins.counts.keys) == firstNames)
        await session.prepareBattlePresentationAssets(displayScale: 1)
        #expect(Set(pins.counts.keys) == firstNames.union(secondNames))
        session.trimMemoryFootprint(releaseBattleLog: true)
        #expect(Set(pins.counts.keys) == firstNames.union(secondNames))

        session.keepPreparedRuns([firstKey])
        #expect(Set(pins.counts.keys) == firstNames)
        session.keepPreparedRuns([])
        #expect(pins.counts.isEmpty)
        #expect(session.lifecyclePhase == .idle)
    }

    @Test(arguments: [false, true])
    func `prepared activation retains active and sibling artwork`(whilePreparing: Bool) async throws {
        let pins = ArtworkPinRecorder()
        let barrier = ArtworkPreparationBarrier()
        var shouldPause = whilePreparing
        let session = BattleSession(openingHandDrawStagger: 0)
        session.artworkPreparation = pins.makePreparation(decoding: {
            if shouldPause {
                shouldPause = false
                await barrier.pause()
            }
        })
        let first = artworkConfiguration(key: "first", abilities: [.slash])
        let second = artworkConfiguration(key: "second", abilities: [.heal])
        let firstKey = try #require(first.runKey)
        let secondKey = try #require(second.runKey)
        #expect(session.prepareBattleRun(first))
        #expect(session.prepareBattleRun(second))
        let pending = Task { await session.prepareBattlePresentationAssets(displayScale: 1) }
        if whilePreparing {
            await barrier.waitForArrival()
        } else {
            await pending.value
        }
        let before = pins.counts
        #expect(!before.isEmpty)

        #expect(session.activatePreparedBattle(
            runKey: firstKey, configurationID: first.id,
        ))
        #expect(pins.counts == before)
        barrier.resume()
        await pending.value
        await session.prepareBattlePresentationAssets(displayScale: 1)
        session.trimMemoryFootprint(releaseBattleLog: true)
        #expect(pins.counts == before)
        #expect(session.hasPreparedRun(secondKey))
        session.endBattle()
        session.trimMemoryFootprint(releaseBattleLog: true)
        #expect(pins.counts.isEmpty)
    }

    private enum ArtworkLifecycleChange: CaseIterable {
        case end, replace, prune, activate, restart
    }

    @Test(arguments: [false, true], ArtworkLifecycleChange.allCases)
    private func `obsolete artwork preparation cannot publish`(duringWarmup: Bool, change: ArtworkLifecycleChange) async {
        let pins = ArtworkPinRecorder()
        let barrier = ArtworkPreparationBarrier()
        let session = BattleSession(openingHandDrawStagger: 0)
        session.artworkPreparation = pins.makePreparation(
            warmup: {
                if duringWarmup {
                    await barrier.pause()
                }
            },
            decoding: {
                if !duringWarmup {
                    await barrier.pause()
                }
            },
        )
        let original = artworkConfiguration(key: "old", abilities: [.slash])
        if change == .restart {
            #expect(session.activate(original))
        } else {
            #expect(session.prepareBattleRun(original))
        }
        let pending = Task { await session.prepareBattlePresentationAssets(displayScale: 1) }
        await barrier.waitForArrival()
        let replacement = artworkConfiguration(key: "old", abilities: [.heal])
        switch change {
        case .end: session.endBattle()
        case .replace: #expect(session.prepareBattleRun(replacement))
        case .prune: session.keepPreparedRuns([])
        case .activate: #expect(session.activate(replacement))
        case .restart: #expect(session.restart(replacement))
        }
        barrier.resume()
        await pending.value
        #expect(pins.counts.isEmpty)
        if duringWarmup {
            #expect(pins.acquisitions == 0)
        }
        session.endBattle()
    }

    @Test(arguments: [false, true])
    func `superseded artwork request balances temporary pins`(cancel: Bool) async {
        let pins = ArtworkPinRecorder()
        let barrier = ArtworkPreparationBarrier()
        var decodingRequests = 0
        let preparation = pins.makePreparation(decoding: {
            decodingRequests += 1
            if decodingRequests == 2 {
                await barrier.pause()
            }
        })
        await preparation.prepare(names: ["shared"], displayScale: 1) {}
        let pending = Task {
            await preparation.prepare(names: ["shared", "old"], displayScale: 1) {}
        }
        await barrier.waitForArrival()
        if cancel {
            pending.cancel()
        } else {
            await preparation.prepare(names: ["shared", "new"], displayScale: 1) {}
        }
        barrier.resume()
        await pending.value
        let expected = cancel ? ["shared": 1] : ["shared": 1, "new": 1]
        #expect(pins.counts == expected)
        preparation.release()
        #expect(pins.counts.isEmpty)
    }

    private func artworkConfiguration(key: String, abilities: [Ability]) -> BattleRunConfiguration {
        let party = BattlePartyFixtures.quickWinParty(heroAbilities: abilities)
        return BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey(key), hero: party.hero,
            companion: party.companion, enemy: party.enemy,
        ).configuration
    }
}

@MainActor
private final class ArtworkPinRecorder {
    var counts: [String: Int] = [:]
    var acquisitions = 0

    func acquire(_ names: Set<String>) {
        acquisitions += names.count
        for name in names {
            counts[name, default: 0] += 1
        }
    }

    func makePreparation(
        warmup: @escaping () async -> Void = {},
        decoding: @escaping () async -> Void = {},
    ) -> BattleArtworkPreparation {
        BattleArtworkPreparation(
            warmup: { _ in await warmup() },
            acquire: { names in
                self.acquire(names)
                await decoding()
            },
            release: { names in
                for name in names {
                    let count = self.counts[name, default: 0]
                    #expect(count > 0)
                    if count <= 1 {
                        self.counts.removeValue(forKey: name)
                    } else {
                        self.counts[name] = count - 1
                    }
                }
            },
        )
    }
}

@MainActor
private final class ArtworkPreparationBarrier {
    private var paused: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?

    func pause() async {
        await withCheckedContinuation { continuation in
            paused = continuation
            arrival?.resume()
            arrival = nil
        }
    }

    func waitForArrival() async {
        if paused != nil {
            return
        }
        await withCheckedContinuation { arrival = $0 }
    }

    func resume() {
        paused?.resume()
        paused = nil
    }
}

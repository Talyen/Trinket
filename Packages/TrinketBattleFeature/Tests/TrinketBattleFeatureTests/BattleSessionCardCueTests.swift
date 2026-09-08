import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionCardCueTests {
    @Test func `lifting a mixed card cues its actual recipients without playing it`() throws {
        let session = makeSession()
        let card = try install(.spikedShield, in: session)
        let rng = session.engineState?.rng
        let health = session.engineState?.roster.enemy.currentHealth
        session.beginCardCue(card)
        let cue = try #require(session.cardCues.current)
        #expect(cue.recipients[session.heroID ?? ""]?.kind == .protect)
        #expect(cue.recipients[session.enemyID ?? ""]?.kind == .attack)
        #expect(session.engineState?.rng == rng)
        #expect(session.engineState?.roster.enemy.currentHealth == health)
        #expect(session.hand.contains(card))
        session.cancelCardCue(card)
        #expect(session.cardCues.current == nil)
    }

    @Test func `tap commitment preserves the resource quote until feedback completes`() throws {
        let session = makeSession()
        let card = try install(.darkPact, in: session)
        session.beginCardCue(card)
        let before = try #require(session.cardCues.current)
        #expect(before.resources.first?.amount == 3)
        #expect(before.recipients[before.actorID]?.keyword == .health)
        #expect(session.playCard(cardID: card.id, requiresLift: true).didCommit)
        #expect(session.cardCues.current?.phase == .committed)
        #expect(session.cardCues.current?.resources == before.resources)
        session.cancelCardCue(card)
        #expect(session.cardCues.current?.phase == .committed)
        session.clearCardCues()
    }

    @Test func `a late cancellation cannot clear a newer card cue`() throws {
        let session = makeSession()
        let first = try install(.heal, in: session)
        session.beginCardCue(first)
        let second = try install(.briarShield, in: session)
        session.beginCardCue(second)
        session.cancelCardCue(first)
        #expect(session.cardCues.current?.cardID == second.id)
        #expect(session.cardCues.current?.phase == .lifted)
        session.clearCardCues()
    }

    @Test func `inspection suspension and reset clear lifted cues`() throws {
        let session = makeSession()
        let card = try install(.heal, in: session)
        session.beginCardCue(card)
        session.presentAbilityDetail(card.ability)
        #expect(session.cardCues.current == nil)
        session.overlayAbilityDetail = nil
        session.beginCardCue(card)
        session.setSuspendedForScenePhase(true)
        #expect(session.cardCues.current == nil)
        session.setSuspendedForScenePhase(false)
        #expect(!session.playCard(cardID: card.id, requiresLift: true).didCommit)
        #expect(session.hand.contains(card))
        session.beginCardCue(card)
        session.clearRunState()
        #expect(session.cardCues.current == nil)
    }

    @Test func `two quick taps may both commit while only the latest preview remains visible`() throws {
        let session = makeSession()
        let first = try install(.briarShield, in: session)
        var state = try #require(session.engineState)
        let second = BattleCardCombatEngine.deal(.manaBerries, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        session.beginCardCue(first)
        session.beginCardCue(second)
        session.cancelCardCue(second)
        #expect(session.cardCues.hasLift(for: first.id))
        session.beginCardCue(second)
        #expect(session.playCard(cardID: first.id, requiresLift: true).didCommit)
        #expect(session.cardCues.current?.cardID == second.id)
        #expect(session.playCard(cardID: second.id, requiresLift: true).didCommit)
        #expect(session.cardCues.current?.phase == .committed)
        session.clearCardCues()
    }

    @Test func `denied health costs highlight the owner while stale cards do not claim a resource problem`() throws {
        let session = makeSession()
        let card = try install(.darkPact, in: session)
        var state = try #require(session.engineState)
        state.roster.mutateRuntime(for: state.hero) { $0.currentHealth = 3 }
        session.engineState = state
        session.installSimulationPresentation()
        session.denyCardCue(card)
        let cue = try #require(session.cardCues.current)
        #expect(cue.phase == .denied)
        #expect(cue.recipients[state.hero.id]?.kind == .deniedHealth)
        #expect(session.engineState?.roster.hero.currentHealth == 3)
        session.clearCardCues()
        _ = state.hand.remove(id: card.id)
        session.engineState = state
        session.denyCardCue(card)
        #expect(session.cardCues.current == nil)
    }

    @Test func `cleanse takes precedence over healing on the same recipient`() throws {
        let session = makeSession()
        let card = try install(.cleanse, in: session)
        session.beginCardCue(card)
        #expect(session.cardCues.current?.recipients[session.heroID ?? ""]?.kind == .cleanse)
        session.clearCardCues()
    }

    private func makeSession() -> BattleSession {
        BattleSessionTestSupport.makeConfiguredSession(
            hero: CombatantFixtures.passiveHero(maxHealth: 100, maxMana: 12),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100, maxMana: 12),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            autoEndTurnDelay: 60,
        )
    }

    private func install(_ ability: Ability, in session: BattleSession) throws -> BattleCard {
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        return card
    }
}

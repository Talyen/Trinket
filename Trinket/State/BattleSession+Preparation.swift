import BattleEngine
import Foundation

extension BattleSession {
    struct PreparedBattleRun {
        let configuration: ActiveBattleConfiguration
        let state: BattleState
        let presentation: BattlePresentationSnapshot
    }

    func prepareBattleRun(_ configuration: ActiveBattleConfiguration) {
        guard activeBattle == nil,
              let token = configuration.resumeToken else { return }
        if preparedBattleRunsByToken[token]?.configuration.id == configuration.id {
            return
        }
        let state = Self.makeBattleState(from: configuration)
        preparedBattleRunsByToken[token] = PreparedBattleRun(
            configuration: configuration,
            state: state,
            presentation: BattlePresentationSnapshot(
                configurationID: configuration.id,
                state: state
            )
        )
    }

    /// Opening-hand ability art names for a prepared run (cast faces on first play).
    func preparedAbilityArtworkNames(for resumeToken: ActiveBattleResumeToken) -> [String] {
        guard let run = preparedBattleRunsByToken[resumeToken] else { return [] }
        return run.state.hand.cards.compactMap { $0.ability.artReference?.imageName }
    }

    func activatePreparedJourneyBattle(
        stageID: String,
        heroID: String,
        companionID: String,
        enemyID: String
    ) -> Bool {
        activatePreparedBattle(
            resumeToken: .journey(stageID: stageID),
            heroID: heroID,
            companionID: companionID,
            enemyID: enemyID
        )
    }

    func activatePreparedBattle(
        resumeToken: ActiveBattleResumeToken,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool {
        guard let preparedBattleRun = preparedBattleRunsByToken[resumeToken],
              preparedBattleRun.configuration.resumeToken == resumeToken,
              preparedBattleRun.configuration.hero.combatant.id == heroID,
              preparedBattleRun.configuration.companion.combatant.id == companionID,
              preparedBattleRun.configuration.enemy?.id == enemyID
        else { return false }
        preparedBattleRunsByToken.removeValue(forKey: resumeToken)
        pendingPreparedRun = preparedBattleRun
        activeBattle = preparedBattleRun.configuration
        return true
    }

    func installBattleState(_ newState: BattleState, configurationID: UUID? = nil) {
        state = newState
        guard let configurationID = configurationID ?? activeBattle?.id else { return }
        presentation.install(
            BattlePresentationSnapshot(configurationID: configurationID, state: newState)
        )
    }
}

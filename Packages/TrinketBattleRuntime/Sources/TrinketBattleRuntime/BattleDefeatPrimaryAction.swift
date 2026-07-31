/// Defeat chrome primary action, baked at launch so Battle UI never branches on mode.
public enum BattleDefeatPrimaryAction: Equatable, Sendable {
    case retreat
    case restart
}

/// Stable SFX catalog IDs curated in `SoundManifest/sfx.tsv`.
///
/// The catalog belongs with content metadata so simulation and feature modules
/// can refer to sound identities without importing presentation support.
public enum SFXID {
    public static let uiDeny = "ui_deny"
    public static let uiConfirm = "ui_confirm"
    public static let uiCancel = "ui_cancel"
    public static let uiToggleOn = "ui_toggle_on"
    public static let uiToggleOff = "ui_toggle_off"
    public static let uiEquip = "ui_equip"
    public static let uiBuySell = "ui_buy_sell"
    public static let abilityDraw = "ability_draw"
    public static let hit = "hit"
    public static let hitBurn = "hit_burn"
    public static let hitFreeze = "hit_freeze"
    public static let heal = "heal"
    public static let buff = "buff"
    public static let block = "block"
    public static let controlFreeze = "control_freeze"
    public static let controlStun = "control_stun"
    public static let purge = "purge"
    public static let deathsDoor = "deaths_door"
    public static let victory = "victory"
    public static let defeat = "defeat"
    public static let mysteryEvent = "mystery_event"

    public static let battlePrewarmIDs = [
        abilityDraw,
        hit,
        hitBurn,
        hitFreeze,
        heal,
        buff,
        block,
        controlFreeze,
        controlStun,
        purge,
        deathsDoor,
        victory,
        defeat,
    ]
}

# Audio context

Use for music routing, SFX mapping, playback behavior, and audio content.

Authored track and SFX metadata belongs in `MusicManifest/` and `SoundManifest/`; run
the asset-generation workflow in `content-and-manifests.md` for input changes.
Playback and routing live in `Packages/TrinketAppState/Sources/TrinketAppState/Audio`: music
intentionally uses ambient `AVAudioPlayer`, and SFX use a prestarted `AVAudioEngine`.
Shared bundle lookup lives in `TrinketContent.MediaResourceLocator`. Battle feedback mappings live in
`TrinketBattleFeature`, not content catalogs.

Keep audio ownership layered: catalog metadata in `TrinketContent`, player
state/preferences and routing/playback in `TrinketAppState`, and battle event
interpretation in `TrinketBattleFeature`. Do not unit-test AVFoundation playback or
real device audio output. Test routing/mapping logic and audio-actor lifecycle policy
with controlled backends; keep native engine behavior in the system backend. Current
playback behavior is documented in `Packages/TrinketAppState/README.md`.

Stopping or releasing SFX invalidates earlier queued requests and pending decodes.
Later requests retain ordinary ordering and wait for that invalidation to finish.

## Action sound selection

BattleFeature selects one cue from committed results before chip filtering/culling.
Death's Door overrides ordinary results, then actual Freeze/Stun activation; equal
priority uses source order. Otherwise compare summed actual damage by keyword,
restored Health, Block gained, and Block absorbed within the resolved action.
Ties favor damage, healing, then Block. Shared clips do not merge different effects.
Structured damage/absorption replaces its corresponding log amounts; Block logs
can describe an ally's borrowed pool rather than the attacked combatant.
Health costs, unused overhealing, percentages, future damage, Block spending/stripping,
and stack application do not add numeric strength. Fallbacks prefer dodge,
cleanse/purge, healing/buffs, resources, then draw. Pure healing at full Health
retains its cue. Draw arbitration uses the same selector; standalone hand deals
remain separate beats. Repeated delivery cannot replay a resolved action's sound.

Poison and Bleed share Sword Impact for hits and actual ticks. Stun damage uses
Gut Punch separately from becoming Stunned; Holy uses Spell Impact. Block absorption
and dodge have dedicated cues. No general card-play or critical-hit layer is added.
Separate actions and screen transitions may overlap; the player applies no global
suppression or tail-cutting policy.

Progression cues belong to confirmed outcomes: Forge reveal, Salvage dissolve
(or confirmation fallback), Homestead improvement celebration, first collection
deposit, talent unlock, and Corruption reveal. Battle/Mystery collection uses the
same Coins Handling cue as Homestead; shops retain buy/sell. Corruption replaces
victory on Continue. Retry/remount guards belong to the existing action/session
owner, and all playback respects Effects volume independently of haptics.

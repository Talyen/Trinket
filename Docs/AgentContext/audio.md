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
Player teardown sends a terminal shutdown after pending invalidation, independently
of the command worker. It cancels catalog warming and decodes, releases the engine,
and rejects later commands. A cancelled worker cannot start catalog warming.

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

Direct Poison and Bleed hits use Sword Impact; actual periodic Poison and Bleed
use separate squelch and soft wet-impact cues. Stun damage uses Gut Punch separately
from becoming Stunned; Holy uses Spell Impact. Block absorption and dodge have
dedicated cues. A winning damage keyword with actual critical Health loss selects
its critical variant, including mixed ordinary/critical contributions. Fully
blocked and dodged hits do not qualify.

`CombatAbilitySFX` changes the recording of a winning result without changing its
numeric strength or priority. Selected abilities use sword, bow, bite, food,
Potion, ritual, ward, movement, choir or rock identities. Astral Arrow selects a
single bow-plus-element recording from its actual damage keyword; Slash, Stab and
Astral Arrow retain corresponding critical revisions. Periodic ticks and unrelated
reactions cannot inherit a card's cast sound. Death's Door and actual control
activation still override authored identity; absorbed hits retain the parry cue.
No separate critical layer or general card-play cue is added. End Turn sounds
only after its turn transition resolves.
Separate actions and screen transitions may overlap; the player applies no global
suppression or tail-cutting policy.

Progression cues belong to confirmed outcomes: Forge reveal, Salvage dissolve
(or confirmation fallback), Homestead improvement celebration, first collection
deposit, talent unlock, and Corruption reveal. First visible Astral/Unique loot also uses
its short exceptional reveal cue, deduplicated by the reward presentation owner. Battle/Mystery collection uses the
same short Coins Gathering cue as Homestead and shop transactions. Corruption replaces
victory on Continue. Retry/remount guards belong to the existing action/session
owner, and all playback respects Effects volume independently of haptics.

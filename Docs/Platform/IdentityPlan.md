# Identity Plan

Canonical product + engineering guidance for Trinket identity, cross-device progress, and account/data deletion.

**Status:** Decisions locked. Live CloudKit remains stubbed until Apple Developer Program enrollment — execute [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md) to enable sync. Persistence overview: [Architecture.md](Architecture.md).

---

## Decisions (locked)

| # | Question | Decision |
|---|----------|----------|
| 1 | What must identity unlock? | **Cross-device progress only** |
| 2 | Google Sign-In? | **Skip** (not required) |
| 3 | No iCloud on device? | **Fully playable local-only** |
| 4 | Account / data deletion? | Follow Apple guidance — see [Deletion](#deletion--apple-guidance) |
| 5 | Multi-device conflicts? | **Rely on CloudKit / SwiftData defaults** for ordinary progression; passive Homestead production is gated until its idempotent claim authority is verified |
| 6 | Developer Program timing? | **Not imminent** — keep seams stubbed; do not enable live sync early |
| 7 | Non-Apple platforms? | **None planned** — CloudKit-private is sufficient |

**Out of scope (explicit):**

- Login / splash / title gate
- Sign in with Apple (not needed for iCloud private sync)
- Sign in with Google / email-password / other social logins
- Game Center
- Soft “Save progress to iCloud?” prompts
- Hosted backend, Firebase, custom user directory

---

## Product model

Trinket’s “identity” for progress is the **system iCloud Apple ID**, not an in-app account.

```text
Cold launch
  → Play immediately (local SwiftData) — always
  → If CloudKit enabled AND device signed into iCloud AND cloud sync not disabled
       → SwiftData private CloudKit syncs PlayerSave silently
  → Else
       → Local-only; no blocking UI
```

| Concern | Mechanism |
|---------|-----------|
| Who owns the save | iCloud account on the device (CloudKit private DB) |
| How progress moves devices | Automatic SwiftData ↔ CloudKit sync after enablement |
| How players start | Guest / local — no sign-in |
| How players wipe data | In-app **Reset Game Progress** (clears local; after enablement also clears synced CloudKit data) |
| How players manage iCloud storage | System Settings → Apple Account → iCloud (Apple-provided) |

There is **no** Trinket-owned user row, password, or OAuth session. Cross-device restore happens because Device B uses the same iCloud account as Device A.

---

## Why not Sign in with Apple or Google

| Approach | Fits “cross-device progress, no hosting”? |
|----------|------------------------------------------|
| **CloudKit private DB** (chosen) | Yes — Apple hosts; keyed by iCloud Apple ID; no login UI |
| Sign in with Apple alone | Does **not** key CloudKit private DB; redundant for sync; adds 5.1.1 account-deletion + token-revoke duties |
| Google Sign-In | Cannot key CloudKit; needs a hosted identity store to mean anything for saves |
| Email / password | Not required by Apple; needs a database — skip |

**App Store 4.8:** Only applies if a third-party social login authenticates a **primary account**. With no Google/Facebook/etc., SIWA is **not** required.

**App Store 5.1.1(v):** If the app does **not** create accounts, the account-creation / SIWA-revoke rules do not apply. Players must still be able to use the app without login (satisfied). Data wipe is handled via Reset + iCloud storage management (below).

---

## Deletion — Apple guidance

Sources: [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app), Guideline **5.1.1(v)**, [Allowing Users to Manage Data Stored in iCloud](https://developer.apple.com/icloud/allowing-users-to-manage-data/).

### What Apple requires when you *do* create accounts

- Easy-to-find in-app deletion of the account **and** associated personal data
- Not email/phone-only support flows (except highly regulated industries)
- SIWA apps must revoke tokens via the Sign in with Apple REST API on delete
- Auto-created “guest” accounts also need a deletion path if you create them as accounts

### What Trinket should do (no in-app account)

Because progress is **local + optional iCloud container data**, not a developer-hosted account:

1. **Keep / strengthen in-app Reset Game Progress** (Options)  
   - Clears local SwiftData save (already).  
   - **When sync ships:** ensure reset also removes / replaces CloudKit-backed progress so wipe propagates across devices (checklist already expects this).  
   - Copy: device-local wording until sync; after enablement, accurate “this Apple Account / iCloud” wording without promising manual sync controls.

2. **Do not invent a separate “Delete Account”** unless we later add SIWA or a hosted account. That would create 5.1.1 obligations we do not need for sync.

3. **Respect system iCloud management**  
   Players can delete the app’s iCloud data from Settings → Apple Account → iCloud → Manage storage. App Review notes should state: playable offline; progress syncs via iCloud when signed in; reset clears progress.

4. **If we later add SIWA** (not planned): treat it as optional profile only; implement full in-app account deletion + token revoke; still do not gate play or sync on SIWA.

---

## UX rules

| Rule | Detail |
|------|--------|
| No login splash | System launch screen → Play tab |
| No save prompts | No “Sign in to save” / “Enable iCloud?” sheets |
| Offline / no iCloud | Full game; progress stays on device |
| Options (after sync) | Optional quiet status only if useful later (e.g. “iCloud sync: On/Off”) — **not** a prompt |
| Reset | Confirmation alert; destructive; after sync must clear synced progress |
| Conflicts | Accept CloudKit/SwiftData last-writer / merge defaults for ordinary progression; passive Homestead production must use the dedicated pre-ship claim gate and authority |

---

## Engineering notes

Keep seams lightweight until Developer Program enrollment:

| Seam | Purpose |
|------|---------|
| Cloud sync status (optional value type) | Derive local-only vs iCloud-available from launch args / entitlements readiness — no Auth UI |
| `PlayerSaveStore` / config | Keep `cloudKitDatabase: .none` vs `.private(...)` gate; identity = system iCloud |
| Launch args | `-disable-cloud-sync`, `-enable-cloud-sync` (Simulator), `-reset-state`; tests never require an Apple ID |
| Options copy helpers | Single place for “this device” vs “iCloud” reset strings gated on “cloud sync configured” |

**Do not** ship Account / Sign-In rows in Options. **Do not** add SIWA / Google capabilities.

When enabling live CloudKit, run [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md) end-to-end. Explicitly deferred forever unless product goals change: SIWA, Google, Game Center, player-facing conflict UI, hosted backend, non-Apple platforms. Passive Homestead production remains disabled in cloud mode until its claim authority is verified.

---

## Simulator vs tests vs live

| Audience | Behavior |
|----------|----------|
| **Live (sync on)** | Local play always; silent iCloud sync when signed into iCloud; reset wipes progress including cloud |
| **Live (sync off / stub)** | Local-only; reset is this-device only; no sync claims in UI |
| **Dev Simulator** | CloudKit off unless `-enable-cloud-sync`; no identity UI |
| **UI tests** | Default `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`; unique `-store-name`; never hit real iCloud login |
| **Unit tests** | Persistence tests stay cloud-off; assert local reset/seed only until a sync harness exists |

---

## Privacy & App Review notes (draft for sync enablement)

- **Data collected for sync:** game progress in the app’s iCloud container (declare in privacy questionnaire when sync lands).  
- **Tracking:** none.  
- **Login:** none required.  
- **Review notes sketch:** “Trinket is playable without an account. Progress syncs across the player’s devices via iCloud when they are signed into iCloud. Players can reset progress in Options. There is no Sign in with Apple / Google login.”

---

## Success criteria

1. New player reaches Play and can battle with **zero** identity UI.  
2. After sync enablement: same iCloud account on two devices shares `PlayerSave` without prompts.  
3. No iCloud → full local play; no blocking errors.  
4. Reset removes progress on this device and, when sync is on, on other devices after sync.  
5. No Google, no SIWA, no hosting, no Game Center in this plan.  
6. Tests and CI remain deterministic without Apple ID / CloudKit network.

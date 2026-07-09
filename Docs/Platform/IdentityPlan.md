# Identity Plan

Canonical product + engineering plan for Trinket identity, cross-device progress, and account/data deletion.

**Status:** Finalized (July 2026). **Implementation stubbed** until Apple Developer Program enrollment unlocks live CloudKit (F2).  
**Related:** [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md), [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md) Phase F2, [Architecture.md](../Architecture.md) Persistence.

---

## Decisions (locked)

| # | Question | Decision |
|---|----------|----------|
| 1 | What must identity unlock? | **Cross-device progress only** |
| 2 | Google Sign-In? | **Skip** (not required) |
| 3 | No iCloud on device? | **Fully playable local-only** |
| 4 | Account / data deletion? | Follow Apple guidance — see [Deletion](#deletion--apple-guidance) |
| 5 | Multi-device conflicts? | **Rely on CloudKit / SwiftData defaults** — no custom merge UI |
| 6 | Developer Program / F2 timing? | **Not imminent** — stub docs + code seams; do not enable live sync |
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
  → If F2 enabled AND device signed into iCloud AND cloud sync not disabled
       → SwiftData private CloudKit syncs PlayerSave silently
  → Else
       → Local-only; no blocking UI
```

| Concern | Mechanism |
|---------|-----------|
| Who owns the save | iCloud account on the device (CloudKit private DB) |
| How progress moves devices | Automatic SwiftData ↔ CloudKit sync after F2 |
| How players start | Guest / local — no sign-in |
| How players wipe data | In-app **Reset Game Progress** (clears local; after F2 also clears synced CloudKit data) |
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
   - **At F2:** ensure reset also removes / replaces CloudKit-backed progress so wipe propagates across devices (checklist already expects this).  
   - Copy: device-local wording until F2; after F2, accurate “this Apple Account / iCloud” wording without promising manual sync controls.

2. **Do not invent a separate “Delete Account”** unless we later add SIWA or a hosted account. That would create 5.1.1 obligations we do not need for sync.

3. **Respect system iCloud management**  
   Players can delete the app’s iCloud data from Settings → Apple Account → iCloud → Manage storage. App Review notes (F2) should state: playable offline; progress syncs via iCloud when signed in; reset clears progress.

4. **If we later add SIWA** (not planned): treat it as optional profile only; implement full in-app account deletion + token revoke; still do not gate play or sync on SIWA.

---

## UX rules

| Rule | Detail |
|------|--------|
| No login splash | System launch screen → Play tab |
| No save prompts | No “Sign in to save” / “Enable iCloud?” sheets |
| Offline / no iCloud | Full game; progress stays on device |
| Options (F2+) | Optional quiet status only if useful later (e.g. “iCloud sync: On/Off”) — **not** a prompt; defer until F2 ships |
| Reset | Confirmation alert; destructive; after F2 must clear synced progress |
| Conflicts | Accept CloudKit/SwiftData last-writer / merge defaults; no player-facing conflict UI in v1 |

---

## Engineering plan (phased)

### Phase I0 — Docs + seams (now — this plan)

- [x] Lock product decisions in this document  
- [x] Cross-link from Platform README, Architecture sync bullet, CloudKit checklist, best-practices plan  
- [x] No runtime identity module yet  
- [x] Do **not** add SIWA / Google capabilities or entitlements  

### Phase I1 — Stub seams (optional, pre–Developer Program)

Lightweight, test-friendly stubs only — no live CloudKit, no Auth UI:

| Seam | Purpose |
|------|---------|
| `CloudSyncStatus` (or similar) value type | `disabled` / `localOnly` / `icloudAvailable` / `syncing` / `error` — derived from `AppEnvironment.disableCloudSync`, entitlements readiness flag, and later account status |
| `PlayerSaveStore` / config | Keep existing `cloudKitDatabase: .none` vs `.private(...)` gate; document identity = iCloud in comments |
| Launch args | Unchanged: `-disable-cloud-sync`, `-enable-cloud-sync` (Simulator), `-reset-state`; tests never require an Apple ID |
| Options copy helpers | Single place for “this device” vs “iCloud” reset strings gated on “cloud sync configured” |

**Do not** ship user-visible Account / Sign-In rows in Options during I1.

### Phase I2 — Live CloudKit (F2 — human + code after Developer Program)

Execute [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md) in full. Identity-relevant extras:

- [ ] Entitlements + container `iCloud.com.ryanmcintire.Trinket`  
- [ ] Production path uses `.private(container)` when `disableCloudSync == false`  
- [ ] Playable with iCloud signed out / restricted → local fallback (no crash, no modal gate)  
- [ ] Reset Game Progress clears local graph **and** synced cloud data; verify on second device  
- [ ] Privacy questionnaire + App Review notes: offline playable; iCloud optional for cross-device  
- [ ] No CI job depends on iCloud credentials  

### Phase I3 — Explicitly deferred

- Sign in with Apple  
- Google / other social login  
- Game Center  
- Custom conflict resolution UI  
- Hosted backend identity  
- Non-Apple platforms  

Revisit only if product goals change (e.g. friends, shared leaderboards beyond Game Center, or Android).

---

## Simulator vs tests vs live

| Audience | Behavior |
|----------|----------|
| **Live (post-F2)** | Local play always; silent iCloud sync when signed into iCloud; reset wipes progress including cloud |
| **Live (pre-F2 / stub)** | Local-only; reset is this-device only; no sync claims in UI |
| **Dev Simulator** | CloudKit off unless `-enable-cloud-sync`; no identity UI |
| **UI tests** | Default `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync`; unique `-store-name`; never hit real iCloud login |
| **Unit tests** | `AppTestContext` / persistence tests stay cloud-off; assert local reset/seed only until F2 harness exists |

---

## Privacy & App Review notes (draft for F2)

- **Data collected for sync:** game progress in the app’s iCloud container (declare in privacy questionnaire when F2 lands).  
- **Tracking:** none.  
- **Login:** none required.  
- **Review notes sketch:** “Trinket is playable without an account. Progress syncs across the player’s devices via iCloud when they are signed into iCloud. Players can reset progress in Options. There is no Sign in with Apple / Google login.”

---

## Success criteria

1. New player reaches Play and can battle with **zero** identity UI.  
2. After F2: same iCloud account on two devices shares `PlayerSave` without prompts.  
3. No iCloud → full local play; no blocking errors.  
4. Reset removes progress on this device and, when sync is on, on other devices after sync.  
5. No Google, no SIWA, no hosting, no Game Center in this plan.  
6. Tests and CI remain deterministic without Apple ID / CloudKit network.

---

## Implementation checklist (when unblocking F2)

1. Finish Developer Program + portal container (human).  
2. Fill `Trinket.entitlements`; flip production `ModelConfiguration` cloud path.  
3. Run CloudKit pre-ship checklist (two devices, offline, reset propagation).  
4. Update Options reset copy + `PrivacyInfo` / questionnaire.  
5. Optionally surface quiet iCloud status in Options (still no prompts).  
6. Keep identity docs in sync if SIWA/Game Center is ever reconsidered.

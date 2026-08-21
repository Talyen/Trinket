# Identity

Canonical product + engineering guidance for Trinket identity, cross-device progress, and account/data deletion.

Locked decisions are PD-008–PD-011 in [Decisions.md](Decisions.md). Live CloudKit remains stubbed until Apple Developer Program enrollment; use [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md) as the enablement and release gate. Persistence ownership is summarized in [Architecture.md](../Platform/Architecture.md).

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
| Conflicts | Define and verify acceptable outcomes per save domain; passive Homestead production must use the dedicated pre-ship claim gate and authority |

---

## Engineering and verification seams

Keep the implementation lightweight until Developer Program enrollment: local play is unconditional, CloudKit is an explicit configuration gate, and tests never require an Apple ID. Launch arguments, persistence mechanics, and UI-test defaults belong to their owning [testing](../Platform/Testing.md), [persistence](../AgentContext/persistence.md), and [UI-test](../../TrinketUITests/README.md) guides rather than being copied here.

Do not ship Account / Sign-In rows, SIWA, Google, Game Center, or a hosted identity store. When sync is ready, run [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md) end-to-end; it owns the entitlement, schema, reset, conflict, privacy, and review checks.

---

## Success criteria

1. New player reaches Play and can battle with **zero** identity UI.  
2. After sync enablement: same iCloud account on two devices shares `PlayerSave` without prompts.  
3. No iCloud → full local play; no blocking errors.  
4. Reset removes progress on this device and, when sync is on, on other devices after sync.  
5. No Google, no SIWA, no hosting, no Game Center.  
6. Tests and CI remain deterministic without Apple ID / CloudKit network.

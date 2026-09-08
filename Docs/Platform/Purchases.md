# Purchases

Product rules and offer copy: [Monetization.md](../Product/Monetization.md).

## Apple infrastructure

Use StoreKit with product identifier `com.ryanmcintire.Trinket.fullgame`, a
non-consumable named **Full Game**, US base price **$4.99**, Family Sharing enabled.
Never rename or reuse that identifier for another product. No Apple Pay merchant
setup, payment server, hosted player account, or third-party purchase SDK is needed.

StoreKit owns payment confirmation, localized pricing, verification, and purchase
history. Only verified current ownership grants access; gameplay save data does
not establish entitlement. Observe transactions for the app lifetime, recover
unfinished deliveries, and finish verified transactions after delivering access.
Explicit Restore Purchases invokes `AppStore.sync()`. Product lookup failure must
not erase a verified entitlement. Restore/family ownership is independent of
Trinket's private CloudKit save synchronization.

## Local development

Run the **Trinket Development** Xcode scheme. Its [local StoreKit configuration](../../StoreKit/Trinket.storekit)
starts without a purchase and exercises Apple's simulated purchase confirmation;
no Apple Developer membership, App Store Connect product, or real money is needed.
Simulated purchases persist across launches. Use **Debug → StoreKit → Manage
Transactions** in Xcode to delete transactions to test a fresh free customer, or
refund/revoke them to exercise access loss. Reset Game Progress intentionally
does not clear ownership. The developer gameplay Unlock All action only seeds
gameplay data and is not purchase authorization.

The normal **Trinket** scheme has no local StoreKit configuration. Without App
Store Connect setup, its purchase product is unavailable; free play still works.
Release builds have no purchase overrides. TestFlight purchases are sandbox-only
and do not become production purchases.

StoreKit integration tests run in `FullGamePurchaseSmokeTests` against the app.
The standalone SPM test process cannot act as the app's StoreKit purchase host;
package tests cover purchase result states and game access policies.

## Before release

- Enroll in the Apple Developer Program; complete the Paid Apps Agreement,
  banking and tax information.
- Register the explicit bundle ID `com.ryanmcintire.Trinket`; confirm its In-App
  Purchase capability in the developer portal (enabled by default for explicit
  App IDs). StoreKit is linked in the authored XcodeGen project; no fabricated
  payment entitlement is added to the app.
- Create and localize the non-consumable, set territories and pricing, enable
  Family Sharing (Apple does not permit turning it off later).
- Verify real product loading, restoration, family ownership, pending approval,
  and refunds on sandbox/TestFlight devices.
- Publish the privacy/support pages from `Website/` using GitHub Pages. Supply a
  public support contact and verify the pages without login. Expected base URL:
  `https://talyen.github.io/Trinket/`.
- Confirm privacy text and App Store privacy answers match the shipped storage,
  sync, diagnostics, and purchase behavior; use Apple's standard EULA.
- Submit the first non-consumable with an app version. Include a paywall screenshot
  and review instructions: open Options → Full Game to inspect the offer without
  finishing free content. Explain that recruitment and game progression remain earned.

No live product, account enrollment, hosting activation, or App Store release is
implied by compiling or testing this implementation.

## References

- [StoreKit product views](https://developer.apple.com/documentation/storekit/productview)
- [Current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [Explicit restoration](https://developer.apple.com/documentation/storekit/appstore/sync())
- [StoreKit testing](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox)
- [Family Sharing](https://developer.apple.com/documentation/storekit/supporting-family-sharing-in-your-app)
- [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)

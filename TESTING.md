# Testing nexi_payment

This plugin talks to two payment gateways through native SDKs, so the test
suite is split into three layers: unit tests that need nothing, automated
integration tests that drive the real native SDKs on a device, and a short
manual checklist for the parts a machine cannot do (typing a card number into
a hosted checkout page).

| Layer | What it covers | Needs a device? | Needs credentials? |
|---|---|---|---|
| Unit tests | Dart API, channel encoding, result decoding | no | no |
| Patrol integration tests | native SDK round-trip, error mapping, no hung futures | yes | sandbox only |
| Manual checklist | real card payment, rooted/jailbroken devices | yes | yes |

> Driving a full NPG payment by hand — every outcome and every way a user can
> leave the checkout — is written up step by step in `docs/DEVICE_TESTING.md`,
> with the exact commands, coordinates and workarounds for our own test phone
> and the iOS simulator. That runbook is kept local (it is neither committed
> nor published) because it is specific to our devices.

---

## 1. Unit tests

Pure Dart. These mock the method channel, so they verify the arguments the
plugin sends and how it decodes replies, without touching the native SDKs.
`analyze` and `flutter test` also run automatically in CI
(`.github/workflows/ci.yml`) on every push and pull request, alongside debug
builds of the example app for both platforms; the Patrol and manual layers
below are not run in CI (see the comments in that file for why).

```bash
flutter analyze
flutter test                 # plugin
cd example && flutter test   # example app widget test
```

Covered: classic `initXPay` + `xPayFrontOfficePaga` argument maps (including
that the removed dead fields — `timeStamp`, `mac`, `clientType`, `extraKeys`
— never reach the channel) and the `"OK"` passthrough, resolving with
`NexiPayment.canceledByUser` on cancel, rethrowing a native
`PlatformException` (e.g. `AUTH_DENIED`) unchanged, NPG request encoding, NPG
success/canceled/error decoding, `PlatformException` →
`NpgPaymentResult.error` mapping, and NPG's `MissingPluginException` →
error-result mapping for platforms that don't implement the plugin.

---

## 2. Patrol integration tests

These run the app on a real device or emulator, call the plugin API for real,
and let the native Nexi SDKs make real network calls. They are the only
automated tests that exercise the Java/Swift code.

### Setup

`patrol_cli` must be installed once, globally:

```bash
dart pub global activate patrol_cli
```

Everything else is already configured: the `patrol` dev dependency, the
`patrol:` block in `example/pubspec.yaml` (note `test_directory:
integration_test` — patrol otherwise defaults to `patrol_test/`), the Android
instrumentation runner, and `example/android/app/src/androidTest/.../MainActivityTest.java`.

> **iOS:** running Patrol on iOS additionally needs a `RunnerUITests` target in
> `example/ios/Runner.xcodeproj`, which has to be added through Xcode
> (File → New → Target → UI Testing Bundle, named `RunnerUITests`), followed by
> `pod install`. Until that target exists, run the integration tests on Android
> and use the manual checklist for iOS.

### Running

```bash
cd example

# everything
patrol test

# one file
patrol test --target integration_test/npg_gateway_test.dart

# against your own NPG terminal instead of Nexi's public sandbox
patrol test --dart-define=NPG_HOSTNAME=your-host.nexigroup.com \
            --dart-define=NPG_API_KEY=your-uuid-key
```

### What they assert

`integration_test/npg_gateway_test.dart`

- **Hostname with a scheme is rejected.** The native SDK validates the hostname
  against a bare-host regex, so `https://stg-ta.nexigroup.com` fails with
  `INVALID_CREDENTIALS`. This is offline and deterministic, and it pins down a
  rule that is easy to get wrong.
- **Non-UUID API key is rejected.** Same path; the SDK requires the key to be a
  UUID. Also offline.
- **The Hosted Payment Page opens, and a dismissed checkout reports
  `canceled`.** Starts a real payment against the sandbox, dismisses the
  checkout natively, asserts the result is `canceled` within 30s, then starts
  another payment to prove the plugin is not left stuck in progress.
- **A second concurrent payment is refused** with `IN_PROGRESS`, covering the
  re-entrancy guard in the native handlers.

`integration_test/classic_gateway_test.dart`

- **The classic checkout opens without crashing**, against Nexi's test
  terminal. If the SDK cannot start its Activity the app process dies and this
  test fails — which is exactly how the `androidx.webkit` "Unknown feature
  PAYMENT_REQUEST" regression was caught.
- **Dismissing the checkout with the back button reports a cancel**, and the
  plugin is usable afterwards. `BaseWebViewActivity.onBackPressed` in XPaySDK
  only calls `WebView.goBack()` or `Activity.onBackPressed()` and never
  invokes `FrontOfficeCallbackQP`, which used to leave the Dart future pending
  forever; the plugin now watches the checkout's lifecycle and fills that
  silence. This test was skipped until that fix landed.

`integration_test/example_app_test.dart`

- Both gateway buttons render.

### Writing new integration tests

Both gateways hand off to a **native Activity** for the checkout, and Flutter
stops producing frames while it is in front. Anything that waits for a frame
blocks forever there — including a single `pump()`, which is why the payment
tests call the plugin API directly instead of tapping the example app's
buttons (`tap()` pumps after the tap, and even
`settlePolicy: SettlePolicy.noSettle` still needs one frame).

So, for a test that opens a checkout:

- Call the plugin API and hold the future instead of awaiting it.
- Wait with `Future.delayed`, never `$.pump`/`pumpAndSettle`.
- Dismiss natively, then await the future with a timeout.
- Keep widget-level assertions in `example_app_test.dart`, where no native
  screen is involved.
- **Keep the native screen in the foreground briefly.** If it stays there too
  long the instrumentation tears the app down (`ActivityManager: Killing …
  due to finished inst`, with `UiAutomationConnection.shutdown` just before).
  That shows up as a test that never reports — patrol prints
  `Successful: 0, Failed: 0` — rather than one that fails. A few seconds is
  enough to prove the checkout launched.

### Deliberately not asserted

Both dismissal tests now pin the outcome, because in both cases the *plugin*
decides rather than the SDK: NPG reports `canceled` when its checkout goes away
silently (the 2.1.0 iOS fix), and the classic gateway does the same when the
back button closes its Activity without a callback (the 2.2.0 Android fix).
Each test then starts another payment and asserts it is not refused with
`IN_PROGRESS`, which is the half that catches a plugin left stuck.

---

## 3. Manual checklist

Things that need a human. Run these before publishing a release.

### Credentials

Classic XPay (from ecommerce.nexi.it → your test terminal): alias, MAC
calculation key (this is the `secretKey`), terminal group. The example app has
a working test alias and key hardcoded in `example/lib/main.dart`.

NPG: hostname and X-Api-Key. Nexi publishes a shared sandbox terminal on the
[test environment page](https://developer.nexigroup.com/xpayglobal/en-EU/docs/test-environment/);
the integration tests default to it. A dedicated NPG terminal has to be
provisioned by Nexi and its key generated in the merchant back office
(Settings → ApiKeys → Create).

**The hostname must be a bare host** (`stg-ta.nexigroup.com`), never a URL, and
**the API key must be a UUID** — both are validated by the native SDK.

### Test cards

| Scheme | Number | Expiry | CVV | Expected |
|---|---|---|---|---|
| Visa | 4509 0345 4361 5006 | 10/2028 | 298 | success |
| Mastercard | 5100 9908 1789 6004 | 04/2027 | 301 | success |
| Visa | 4539 9700 0000 0014 | 12/2030 | any 3 digits | failure |

The failure card above is from Nexi's own test-card reference (ecommerce.nexi.it
test area → **Carte Test**), verified live against the classic checkout. An
older card that circulated here, `4349 9401 9999 7007`, does **not** actually
decline on the classic gateway — it authorizes like a success card — so don't
reuse it. For NPG, the outcome is decided by the 3DS challenge button
(**AUTENTICAZIONE RIUSCITA** / **FALLITA**), not the card number, so any card
from Nexi's test list works for both success and failure there.

### Checklist

Run on **both** Android and iOS, in debug and release:

```bash
cd example
flutter run --dart-define=NPG_HOSTNAME=stg-ta.nexigroup.com \
            --dart-define=NPG_API_KEY=5d952446-9004-4023-9eae-a527a152846b
```

Classic gateway (**PAY**):

- [ ] Completing a payment with a success card shows `OK` in green.
- [ ] Cancelling shows `Operation canceled by the user`
      (`NexiPayment.canceledByUser`).
- [ ] Using the failure card shows an `AUTH_DENIED: ...` dialog — the example
      app catches the `PlatformException` — instead of a success string or an
      uncaught exception.
- [ ] Backgrounding the app mid-payment and returning still resolves.
- [ ] Starting a second payment while one is already open is refused with
      `IN_PROGRESS` instead of the two payments interfering with each other.

NPG gateway (**PAY WITH NPG (HPP)**):

- [ ] A success card returns `status: success` with `operationResult`
      `EXECUTED` or `AUTHORIZED` — on **both** platforms. On Android the SDK
      itself still fails to parse the outcome (the NPGSDK 1.1.0 defect, see
      README); the plugin recovers it from the orders API, so the *user-visible*
      result must be a success. Getting `errorCode: RESULT_PARSING_FAILED`
      here means recovery did not run or could not reach the API: check the
      device network, then verify via the orders API that the order really is
      EXECUTED/CAPTURED.
- [ ] With `recoverOutcomeOnParsingFailure: false`, the same Android payment
      goes back to reporting `RESULT_PARSING_FAILED` — the opt-out works.
- [ ] A payment that finishes without succeeding — the failure card, or
      pressing "AUTENTICAZIONE FALLITA" on the 3DS page — returns
      `status: error` with the NPG outcome as `errorCode` (`DECLINED`,
      `THREEDS_FAILED`, …), never `status: success`.
- [ ] Dismissing the checkout resolves instead of hanging. On iOS also try
      swiping the sheet down: `canceled` arrives within a few seconds, and a
      new payment can be started right after.
- [ ] A wrong-but-well-formed UUID key returns a typed error.
- [ ] With `notificationUrl` set, your backend receives the server-to-server
      notification.

Device/platform:

- [ ] iOS: works on a physical device *and* an Apple Silicon simulator (the
      fetched xcframeworks carry both slices; the `Nexi_XPay` pod did not).
- [ ] Android: minSdk 23 device.
- [ ] A rooted/jailbroken device reports `DEVICE_ROOTED` / `DEVICE_JAILBROKEN`
      as an exception. Not automatable.

---

## 4. Release checks

```bash
flutter analyze && flutter test
cd example && flutter build apk --debug && flutter build ios --simulator --no-codesign
pod lib lint ios/nexi_payment.podspec --allow-warnings
dart pub publish --dry-run
```

`android/consumer-rules.pro` keeps both native SDKs' model classes, so
consumers don't need any ProGuard/R8 setup of their own for a minified
release build. The example app's own `release` build type doesn't set
`minifyEnabled true`, so `flutter build apk --debug` above doesn't exercise
those rules. If you touch `consumer-rules.pro` or bump either native SDK,
temporarily set `minifyEnabled true` (and `shrinkResources true`) in
`example/android/app/build.gradle`, build a release APK, and confirm a
payment still goes through — Gson-reflected fields silently break at runtime
rather than at compile time if a keep rule is ever wrong.

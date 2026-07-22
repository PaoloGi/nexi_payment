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
- **The Hosted Payment Page opens and always completes.** Starts a real payment
  against the sandbox, dismisses the checkout natively, and asserts a result
  comes back within 30s. This guards the bug class fixed in 2.0.0, where the
  future could never complete.
- **A second concurrent payment is refused** with `IN_PROGRESS`, covering the
  re-entrancy guard in the native handlers.

`integration_test/classic_gateway_test.dart`

- **The classic checkout opens without crashing**, against Nexi's test
  terminal. If the SDK cannot start its Activity the app process dies and this
  test fails — which is exactly how the `androidx.webkit` "Unknown feature
  PAYMENT_REQUEST" regression was caught.
- A second test asserting that dismissing the checkout with the **back button**
  reports an outcome is **skipped on purpose**: it fails today.
  `BaseWebViewActivity.onBackPressed` in XPaySDK only calls `WebView.goBack()`
  or `Activity.onBackPressed()` and never invokes `FrontOfficeCallbackQP`, so
  the Dart future stays pending forever. Cancelling through the payment page's
  own cancel link works (the SDK detects its `urlBack` navigation). Un-skip it
  if Nexi fixes the SDK.

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

The dismissal tests assert only that a result arrives and is *not* success.
Whether the SDK reports a dismissed checkout as `canceled` or as an `error`
is the SDK's choice and differs between the two gateways; pinning it would
make the suite brittle without testing anything we control.

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
| Visa | 43499 4019999 7007 | 12/2028 | 829 | failure |

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
      `EXECUTED` or `AUTHORIZED`. On **Android** it may instead return
      `status: error` with `errorCode: RESULT_PARSING_FAILED`, the known
      NPGSDK 1.1.0 parsing defect (see README) — in that case verify via the
      orders API that the order is EXECUTED/CAPTURED; the payment itself went
      through. iOS parses cleanly and returns `EXECUTED`.
- [ ] Dismissing the checkout resolves instead of hanging.
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

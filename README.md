
# nexi_payment

[![CI](https://github.com/PaoloGi/nexi_payment/actions/workflows/ci.yml/badge.svg)](https://github.com/PaoloGi/nexi_payment/actions/workflows/ci.yml)

Flutter plugin for Nexi payment integration, supporting both Nexi gateways:

- **Classic XPay** (ecommerce.nexi.it) — WebView payment via `NexiPayment`
- **NPG** (developer.nexigroup.com) — Nexi's newer gateway; Hosted Payment Page
  via `NexiNpgPayment`

**New here?** [INTEGRATION.md](INTEGRATION.md) walks through getting
credentials, wiring up either gateway and going live, step by step.

## Requirements

- Dart >= 3.3, Flutter >= 3.16
- Android: minSdk 23, a consumer app built with AGP 8+
- iOS: deployment target 14.4 (`platform :ios, '14.4'` in your Podfile)

No manual SDK setup is needed. On iOS the Nexi SDKs (XPaySDK 1.5.1 with its
ThreeDS_SDK dependency, and NPGSDK 1.1.0) are downloaded from Nexi's own
release repositories during `pod install` and verified against pinned SHA-256
checksums — see `ios/scripts/fetch_frameworks.sh`. Building therefore needs
network access the first time, and the frameworks land in `ios/Frameworks/`,
which is not tracked in git.

On Android the SDKs ship as small `.aar` files in `android/libs/`, since Nexi
publishes no Maven artifacts for them.

## Installation

```sh
flutter pub add nexi_payment
```

Then import the gateway you need:

```dart
import 'package:nexi_payment/nexi_payment.dart';      // classic XPay
import 'package:nexi_payment/nexi_payment_npg.dart';  // NPG Hosted Payment Page
```

The first import also re-exports `EnvironmentUtils` and `CurrencyUtilsQP`, so a
single import is enough for the classic gateway.

## Classic XPay gateway

Initialize `NexiPayment` with your secretKey and environment (test or prod):

```dart
@override
void initState() {
  super.initState();
  _nexiPayment = NexiPayment(secretKey: "_yourSecretKey_", environment: EnvironmentUtils.TEST);
}
```

> **Leave `domain` unset unless you really need a custom host.** The
> environment already picks the right one (TEST →
> `https://int-ecommerce.nexi.it`, PROD → `https://ecommerce.nexi.it`), and a
> non-empty `domain` *overrides* it — passing the production URL together
> with `EnvironmentUtils.TEST` sends the test terminal's requests to
> production, which Nexi rejects with a generic error page in the checkout.

To start the payment process just call `xPayFrontOfficePaga`:

```dart
try {
  // codTrans must be unique per attempt — Nexi rejects a reused one with a
  // generic "operation failed" page in the checkout.
  var res = await _nexiPayment.xPayFrontOfficePaga("YOUR_ALIAS", codTrans, CurrencyUtilsQP.EUR, amount);
  if (res == NexiPayment.canceledByUser) {
    // user cancelled
  } else {
    // res == "OK"
  }
} on PlatformException catch (e) {
  // e.code is one of the codes below
}
```

`res` is `"OK"` on success or `NexiPayment.canceledByUser` (the string
`"Operation canceled by the user"`, exposed as a constant so you don't have to
hardcode it) when the user cancels — this is now the same string on both
platforms. Everything else throws a `PlatformException` with one of these
codes:

| Code | Platform | Meaning |
|---|---|---|
| `AUTH_DENIED` | both | The payment authorization was denied |
| `IN_PROGRESS` | both | A classic payment is already running |
| `INVALID_REQUEST` | both | Missing/invalid payment parameters, or a non-EUR currency on iOS |
| `NOT_INITIALIZED` | both | `initXPay` did not complete before paying |
| `NO_ACTIVITY` | both | Plugin not attached to an Activity / no root view controller |
| `DEVICE_ROOTED` | Android | The SDK refuses to run on a rooted device |
| `DEVICE_JAILBROKEN` | iOS | The SDK refuses to run on a jailbroken device |
| `INIT_FAILED` | iOS | `initXPay` failed for a reason other than jailbreak detection |
| `ACTIVITY_DESTROYED` | Android | The host Activity/engine was torn down for good mid-payment (not raised on a rotation/config change) |

On Android, lower-level SDK failures may additionally surface through the native
SDK's own `onError` callback, carrying the SDK's own error code — so treat the
table above as the common cases, not a closed set.

> **Known limitation (Android, classic gateway only).** If the user leaves the
> checkout with the system **back button**, XPaySDK finishes its WebView
> Activity without invoking its own callback, so `xPayFrontOfficePaga` never
> completes. Cancelling through the cancel link on Nexi's payment page works
> normally and returns `"Operation canceled by the user"`. Until Nexi fixes
> this in the SDK, do not rely on the returned future alone to decide an
> order's fate — treat your server-side notification as the source of truth,
> and consider a timeout in your UI. The NPG gateway is unaffected.

<img src="https://raw.githubusercontent.com/PaoloGi/nexi_payment/master/android_screen_1.jpg" width="400">

<img src="https://raw.githubusercontent.com/PaoloGi/nexi_payment/master/android_screen_2.jpg" width="400">

## NPG gateway (Hosted Payment Page)

For merchants on the new Nexi gateway (developer.nexigroup.com). Import the
opt-in library:

```dart
import 'package:nexi_payment/nexi_payment_npg.dart';
```

Open the Hosted Payment Page and await the typed result:

```dart
final npg = NexiNpgPayment(hostname: hostname, apiKey: apiKey);
final result = await npg.payWithHostedPaymentPage(NpgHostedPaymentRequest(
  orderId: "your-order-id",
  amount: 2500, // minor units: €25.00
  currency: "EUR",
  language: "ita",
));
switch (result.status) {
  case NpgPaymentStatus.success:
    // result.operationResult e.g. "EXECUTED" or "AUTHORIZED"
    break;
  case NpgPaymentStatus.canceled:
    break;
  case NpgPaymentStatus.error:
    // result.errorCode / result.errorMessage
    break;
}
```

> **Security note (from Nexi's guidelines):** the NPG `hostname` and `apiKey`
> identify your merchant and should be retrieved at runtime from your backend,
> not hardcoded in the app.

> **Known limitation (NPG SDK 1.1.0, Android).** The Android NPGSDK models
> `operations[].additionalData` as a string, but the NPG backend returns an
> object there — so after a completed card payment the Android SDK can fail to
> parse the outcome **even though the payment was executed and captured**
> (verified against the sandbox: the orders API reported `EXECUTED`/`CAPTURED`
> while the Android SDK threw a parsing exception; the same sandbox payment
> parses cleanly on iOS and returns `EXECUTED`). The plugin surfaces this case
> as `NpgPaymentStatus.error` with `errorCode: RESULT_PARSING_FAILED`. Treat
> that code as "outcome unknown", not as a decline: verify the order
> server-side (orders API by `orderId`, or your `notificationUrl`) before
> failing the purchase. iOS carries the same defensive guard in case its SDK
> ever regresses. 1.1.0 is the latest SDK Nexi ships; this note goes away when
> they fix the Android model.

## Testing

See [TESTING.md](TESTING.md) for the unit tests, the Patrol integration tests
that drive the real native SDKs, and the manual checklist with Nexi's sandbox
credentials and test cards.

## Credentials

The two gateways use different, non-interchangeable credentials:

- **Classic XPay** — alias and "chiave per il calcolo mac" from the Nexi
  merchant portal (test area: https://ecommerce.nexi.it/area-test).
- **NPG** — a bare hostname and a UUID X-Api-Key from the NPG back office
  (https://developer.nexigroup.com).

[INTEGRATION.md](INTEGRATION.md) explains where each value comes from and
where it goes.

## Migrating from 1.x to 2.0.0

The classic API is source-compatible: the `NexiPayment` constructor and
`xPayFrontOfficePaga` signature are unchanged, and a successful payment still
resolves with `"OK"`. The error and cancel *contract* did change on iOS,
though — see below. What changed:

- **iOS now matches Android's error/cancel contract.** Previously iOS resolved
  the future successfully even for a denied payment or an init failure
  (reporting them as plain strings, or hanging on a jailbroken device), and
  its cancel string was `"Cancelled by the user"` — different from Android's.
  Both platforms now throw `PlatformException` for denials/failures and both
  resolve with the same cancel string, `"Operation canceled by the user"`.
  Compare against the new `NexiPayment.canceledByUser` constant instead of
  hardcoding that string.
- Error conditions that previously returned strings via the success callback
  (or hung forever on iOS) now throw `PlatformException` with the codes above,
  including three new ones: `IN_PROGRESS`, `ACTIVITY_DESTROYED` (Android) and
  `INIT_FAILED` (iOS).
- iOS now rejects any currency other than `EUR` with `INVALID_REQUEST` (the
  Nexi iOS SDK only supports EUR); Android now rejects a missing `amount` with
  `INVALID_REQUEST` instead of silently sending a zero-amount payment.
- BREAKING (unlikely to affect you): the internal XPay request models
  (`ApiFrontOfficeBaseRequest` / `ApiFrontOfficeQPRequest`) moved under
  `lib/src/` and are no longer part of the public API, and their unused
  `timeStamp`, `mac`, `clientType` and `extraKeys` fields were removed (the
  native SDKs never read them; no MAC is computed client-side). This affects
  you only if you imported those model files directly instead of going through
  `NexiPayment`; the public API is otherwise source-compatible.
- Tooling floors: Dart 3.3 / Flutter 3.16, Android minSdk 23 + AGP 8,
  iOS 14.4.
- The iOS SDK no longer comes from the `Nexi_XPay` pod, whose published
  framework has no simulator slice; remove any explicit `Nexi_XPay` entry from
  your Podfile. It is fetched at `pod install` instead, so the first build
  needs network access.
- `flutter build aar` is not supported (the bundled .aar libraries are
  resolved via flatDir).
- On Android, consumer ProGuard/R8 rules for both native SDKs now ship with
  the plugin (`android/consumer-rules.pro`); you don't need to add any
  yourself for a minified release build.

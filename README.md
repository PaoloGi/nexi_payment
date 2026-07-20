
# nexi_payment

#### Flutter plugin for Nexi payment integration.

Supports both Nexi gateways:

- **Classic XPay** (ecommerce.nexi.it) — WebView payment via `NexiPayment`
- **NPG / XPay** (developer.nexigroup.com) — Hosted Payment Page via `NexiNpgPayment`

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

## Classic XPay gateway

Initialize `NexiPayment` with your secretKey and environment (test or prod):

```dart
@override
void initState() {
  super.initState();
  _nexiPayment = NexiPayment(secretKey: "_yourSecretKey_", environment: EnvironmentUtils.TEST);
}
```

To start the payment process just call `xPayFrontOfficePaga`:

```dart
var res = await _nexiPayment.xPayFrontOfficePaga("YOUR_ALIAS", "codTrans", CurrencyUtilsQP.EUR, amount);
// res == "OK" on success, "Operation canceled by the user" when the user cancels
```

Failures throw a `PlatformException` with one of these codes:

| Code | Meaning |
|---|---|
| `DEVICE_ROOTED` / `DEVICE_JAILBROKEN` | The SDK refuses to run on a compromised device |
| `NOT_INITIALIZED` | `initXPay` did not complete before paying |
| `INVALID_REQUEST` | Missing/invalid payment parameters |
| `AUTH_DENIED` | The payment authorization was denied |
| `NO_ACTIVITY` | Plugin not attached to an Activity / no root view controller |

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

## Testing

See [TESTING.md](TESTING.md) for the unit tests, the Patrol integration tests
that drive the real native SDKs, and the manual checklist with Nexi's sandbox
credentials and test cards.

## Dependencies

### Classic XPay
- Create a Nexi account and project (or create a test backend here https://ecommerce.nexi.it/area-test )
- Retrieve a secretKey from backend

### NPG
- Get your hostname and X-Api-Key from the NPG back office (https://developer.nexigroup.com)

## Migrating from 1.x to 2.0.0

The classic API is source-compatible: constructor, method and success/cancel
strings are unchanged. What changed:

- Error conditions that previously returned strings via the success callback
  (or hung forever on iOS) now throw `PlatformException` with the codes above.
- Tooling floors: Dart 3.3 / Flutter 3.16, Android minSdk 23 + AGP 8,
  iOS 14.4.
- The iOS SDK no longer comes from the `Nexi_XPay` pod, whose published
  framework has no simulator slice; remove any explicit `Nexi_XPay` entry from
  your Podfile. It is fetched at `pod install` instead, so the first build
  needs network access.
- `flutter build aar` is not supported (the bundled .aar libraries are
  resolved via flatDir).

## Special thanks

<img src="https://www.crilumatech.it/wp-content/uploads/2019/05/cropped-CRILUMATECH-BANNER-300-1.jpg" width="200">
for support and testing of the first implementation of the plugin

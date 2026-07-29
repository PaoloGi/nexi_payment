# Integration guide

Step by step from nothing to a working payment, for both gateways.

For the API reference see [README.md](README.md); for running the test suite
see [TESTING.md](TESTING.md).

---

## 0. Which gateway are you on?

Nexi runs two separate products, with separate contracts, separate portals and
credentials that are **not interchangeable**. Pick by where your credentials
come from:

| You have | Gateway | Class to use |
|---|---|---|
| Alias + "Chiave per il calcolo mac", from ecommerce.nexi.it | Classic XPay | `NexiPayment` |
| A hostname + an X-Api-Key (a UUID), from developer.nexigroup.com | NPG | `NexiNpgPayment` |

If you have the first set and want NPG, you cannot convert them yourself —
Nexi has to provision an NPG terminal for you. Both can be used from the same
app if you happen to have both.

---

## 1. Add the plugin

```yaml
dependencies:
  nexi_payment: ^2.2.0
```

### Android

`android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 23   // required by the NPG SDK
    }
}
```

Your app must build with AGP 8 or newer.

### iOS

`ios/Podfile`:

```ruby
platform :ios, '14.4'
```

Then `cd ios && pod install`. **The first install downloads the Nexi SDKs**
(~33 MB) from Nexi's release repositories and verifies them against pinned
checksums, so it needs network access. If you previously depended on the
`Nexi_XPay` pod directly, remove that line — the plugin no longer uses it.

---

## 2. Classic XPay

### 2.1 Get your credentials

From the Nexi merchant portal (test area: <https://ecommerce.nexi.it/area-test>),
under **Pagamenti E-commerce → Dati per l'integrazione**:

| Portal field | What it is | Where it goes |
|---|---|---|
| **Alias** | identifies your terminal | first argument of `xPayFrontOfficePaga` |
| **Chiave per il calcolo mac** | the signing key | `secretKey` in the `NexiPayment` constructor |
| **Gruppo** | portal-side grouping | **not used** by the mobile SDK |

You do not compute the MAC yourself — the native SDK derives it from
`secretKey` on the device.

### 2.2 Wire it up

```dart
import 'package:flutter/services.dart' show PlatformException;
import 'package:nexi_payment/nexi_payment.dart';

final nexi = NexiPayment(
  secretKey: yourMacKey,
  environment: EnvironmentUtils.TEST,   // EnvironmentUtils.PROD when live
);

try {
  final result = await nexi.xPayFrontOfficePaga(
    yourAlias,
    orderId,          // codTrans: must be unique per attempt
    CurrencyUtilsQP.EUR,
    2500,             // minor units — 2500 = €25.00
  );

  if (result == NexiPayment.canceledByUser) {
    // user cancelled
  } else {
    // paid (result == 'OK')
  }
} on PlatformException catch (e) {
  // e.code is AUTH_DENIED, IN_PROGRESS, INVALID_REQUEST, NOT_INITIALIZED,
  // NO_ACTIVITY, DEVICE_ROOTED / DEVICE_JAILBROKEN, ACTIVITY_DESTROYED
  // (Android) or INIT_FAILED (iOS) — see README.md for the full table.
}
```

A single `import 'package:nexi_payment/nexi_payment.dart';` is enough:
it re-exports `EnvironmentUtils` and `CurrencyUtilsQP`, so you don't need to
import the `models/` files separately.

`codTrans` must be unique for every attempt. Reusing one gets the transaction
rejected.

### 2.3 Read this before you ship

`xPayFrontOfficePaga` always completes — including on Android when the user
leaves with the **system back button**, which XPaySDK itself does not report
(the plugin watches the checkout's lifecycle and resolves with
`NexiPayment.canceledByUser`). Still:

- Confirm the order server-side rather than trusting the client result. The
  client tells you what the user saw; your server-to-server notification tells
  you whether you were paid.

---

## 3. NPG

### 3.1 Get your credentials

Two values, both from your NPG merchant back office
(**Settings → ApiKeys → Create**) at <https://developer.nexigroup.com>:

| Value | Format | Notes |
|---|---|---|
| `hostname` | **bare host**, e.g. `stg-ta.nexigroup.com` | no `https://`, no path — the SDK validates this and rejects a URL |
| `apiKey` | **a UUID** | the SDK rejects anything else |

Getting either shape wrong fails fast with `errorCode: 'INVALID_CREDENTIALS'`
before any network call.

Environments:

| | hostname |
|---|---|
| Test | `stg-ta.nexigroup.com` |
| Live | `xpay.nexigroup.com` |

Confirm the live host against your own terminal's configuration.

To try it before you have a terminal, Nexi publishes a shared sandbox key on
its [test environment page](https://developer.nexigroup.com/xpayglobal/en-EU/docs/test-environment/):
`5d952446-9004-4023-9eae-a527a152846b`. Fine for a smoke test, useless for real
integration — it is public and shared.

### 3.2 Wire it up

```dart
import 'package:nexi_payment/nexi_payment_npg.dart';

final npg = NexiNpgPayment(
  hostname: hostname,
  apiKey: apiKey,
);

final result = await npg.payWithHostedPaymentPage(NpgHostedPaymentRequest(
  orderId: orderId,             // unique per attempt
  amount: 2500,                 // minor units — 2500 = €25.00
  currency: 'EUR',
  language: 'ita',
  notificationUrl: 'https://your-backend.example/nexi/notify',
));

switch (result.status) {
  case NpgPaymentStatus.success:
    // result.operationResult is 'EXECUTED' or 'AUTHORIZED'
    // result.operationId is the NPG reference for this payment
    break;
  case NpgPaymentStatus.canceled:
    break;
  case NpgPaymentStatus.error:
    // result.errorCode / result.errorMessage
    break;
}
```

`payWithHostedPaymentPage` never throws — every outcome, including a rejected
API key, comes back as an `NpgPaymentResult`.

### 3.3 Where the API key should live

The apiKey is a bearer credential: it authenticates your merchant account for
order creation *and* for back-office operations like refunds and captures.
Anyone who decompiles your app can extract a hardcoded one.

So don't ship it baked into the binary. Have your backend hand it to the app at
runtime behind your own authentication, and keep it out of source control. The
plugin doesn't care where the string comes from.

This is the same exposure the classic gateway has with its `secretKey`, so the
advice applies to both — it is not an argument against the mobile SDK, which is
an integration path Nexi supports and documents.

### 3.4 Confirming payments server-side

Set `notificationUrl` to an endpoint on your backend. NPG calls it
server-to-server with the final outcome when the payment completes.

Treat that notification as the source of truth. The in-app result tells you what
the user saw; it does not survive the user killing the app right after paying.
Mark orders paid from the notification, and use the in-app result only to drive
the UI.

That advice stands even though the plugin already protects you from the known
NPGSDK 1.1.0 parsing defect: when the native SDK cannot read the outcome of a
payment, the plugin fetches the order from the NPG orders API and reports the
real result instead of a bogus failure (see the README). If even that lookup
cannot settle it, you get `errorCode: NpgPaymentResult.resultParsingFailedCode`,
which means "outcome unknown" — resolve it from your backend, never by
assuming a decline.

---

## 4. Test before going live

Nexi's test cards (both gateways):

| Scheme | Number | Expiry | CVV | Result |
|---|---|---|---|---|
| Visa | 4509 0345 4361 5006 | 10/2028 | 298 | success |
| Mastercard | 5100 9908 1789 6004 | 04/2027 | 301 | success |
| Visa | 4539 9700 0000 0014 | 12/2030 | any 3 digits | failure |

For NPG, the outcome is decided by the 3DS challenge button (**AUTENTICAZIONE
RIUSCITA** / **FALLITA**), not the card number — any card from the list above
works for both success and failure there.

Run through, on a real device for each platform:

- [ ] A successful payment reports success.
- [ ] The failure card surfaces a denial, not a success.
- [ ] Cancelling from the payment page resolves.
- [ ] Backgrounding the app mid-payment and returning still resolves.
- [ ] For NPG: your `notificationUrl` endpoint actually receives the callback.
- [ ] iOS: builds and runs on a **simulator** as well as a device.

---

## 5. Going live

- [ ] Classic: switch to `EnvironmentUtils.PROD` and production alias + MAC key.
- [ ] NPG: switch `hostname` to your live host and use a production API key.
- [ ] Neither credential is hardcoded in the shipped binary.
- [ ] Orders are settled from server-side notifications, not the client result.
- [ ] `notificationUrl` points at production and is reachable from Nexi's IPs.
- [ ] Your UI handles a payment that never resolves (see §2.3).

---

## 6. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `INVALID_CREDENTIALS` from NPG, immediately | `hostname` includes `https://` or a path, or `apiKey` is not a UUID. Use a bare host. |
| iOS: `No such module 'XPaySDK'` | The frameworks were not fetched — `pod install` needs network on first run. Re-run it; check `ios/Frameworks/` is populated. |
| Android: crash on opening the checkout, `Unknown feature PAYMENT_REQUEST` | An `androidx.webkit` older than 1.14.0 has been forced into your build. XPaySDK needs >= 1.14.0. |
| Classic payment never returns (Android) | Fixed in 2.2.0: the back button now resolves with `NexiPayment.canceledByUser`. On an older version, upgrade. |
| `NOT_INITIALIZED` | Payment called before init finished. Await the payment call rather than firing it during widget construction. |
| Build fails on minSdk | The NPG SDK requires 23; raise `minSdkVersion`. |
| `flutter build aar` fails | Not supported: the Nexi `.aar`s resolve through `flatDir`. Build the app directly. |
| NPG payment succeeds but your order stays unpaid | You are relying on the in-app result. Wire up `notificationUrl` (§3.4). |

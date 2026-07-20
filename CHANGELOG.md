## 2.0.0

* NEW: NPG gateway support (developer.nexigroup.com) — `NexiNpgPayment.payWithHostedPaymentPage`
  opens the Hosted Payment Page and returns a typed `NpgPaymentResult`
  (import `package:nexi_payment/nexi_payment_npg.dart`).
* Classic XPay SDKs updated: Android XPaySDK 1.4.1 → 1.4.92 (3DS2 with the new
  3DS Server, Google Pay WebView, target API updates); iOS now bundles
  XPaySDK 1.5.1 + ThreeDS_SDK, fetched from Nexi's release repositories at
  `pod install` and pinned by SHA-256, instead of depending on the `Nexi_XPay`
  pod (which ships no simulator slice). The first iOS build needs network
  access; the binaries are not redistributed in this package.
* Bug fixes on the classic flow:
  * iOS: `result` was invoked twice on successful payments; futures hung
    forever on jailbroken devices or when `initXPay` had failed; crash on
    missing card brand; deprecated `keyWindow` usage.
  * Android: NPE when the payment request could not be built; rooted device
    and denied authorization were reported as success strings.
  * Android: the classic checkout Activity crashed on launch with
    `Unknown feature PAYMENT_REQUEST`. XPaySDK 1.4.92 enables that WebView
    feature, which needs `androidx.webkit` 1.14.0 or newer; the plugin now
    depends on 1.16.0.
* BREAKING: error conditions now throw `PlatformException` with stable codes
  (`DEVICE_ROOTED`, `DEVICE_JAILBROKEN`, `NOT_INITIALIZED`, `INVALID_REQUEST`,
  `AUTH_DENIED`, `NO_ACTIVITY`) instead of returning strings. Success ("OK")
  and user-cancel strings are unchanged.
* BREAKING: tooling floors — Dart >= 3.3, Flutter >= 3.16, Android minSdk 23 /
  AGP 8 / compileSdk 35, iOS deployment target 14.4.
* Removed dead Android card-form code and the Flutter v1 embedding.
* Documented a pre-existing XPaySDK limitation: on Android, leaving the classic
  checkout with the system back button never resolves `xPayFrontOfficePaga`,
  because the SDK finishes its WebView Activity without invoking its callback.
  Cancelling from the payment page itself is unaffected, as is NPG.

## 1.3.0

* Update example to Android manifest embedding v2, dependency updates.

## 1.2.0

* Add Null Safety (thanks to Federico )

## 1.1.1

* Add xPay.FrontOffice.setDomain method

## 1.0.0

* Format code, tested on IOS

## 0.0.1-dev.2

* BugFix get activity, added comments

## 0.0.1-dev.1

* Initial release, implementing Xpay.FrontOffice.paga web view

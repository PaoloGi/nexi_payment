## 2.2.0

* **FIX (Android, classic gateway): the checkout always reports an outcome.**
  XPaySDK's `BaseWebViewActivity.onBackPressed` only calls `WebView.goBack()`
  or `Activity.onBackPressed()`, so leaving the checkout with the system back
  button never invoked `FrontOfficeCallbackQP`: `xPayFrontOfficePaga` stayed
  pending forever and every later payment was refused with `IN_PROGRESS` until
  the app restarted. The plugin now watches the SDK's checkout screens and, if
  the last one disappears without the SDK reporting anything, resolves with
  `NexiPayment.canceledByUser` — the same result the payment page's own cancel
  link produces. A real outcome always wins: callbacks clear the pending
  result before delivering, and a grace period leaves room for one already on
  its way, so a completed payment and the 3DS step are unaffected.
  * This removes the documented limitation that told you to add your own
    timeout. Both gateways now guarantee that the returned future completes,
    on both platforms.

## 2.1.0

* **FIX (important): a failed NPG payment is no longer reported as a success.**
  Both native SDKs invoke their "completed" callback for a payment that merely
  *finished* — including one that was declined or failed 3DS — and the plugin
  took that at face value, so failing 3DS came back as
  `NpgPaymentStatus.success` with `THREEDS_FAILED` sitting in
  `operationResult`. The outcome is now decided by `operationResult` whenever
  NPG reports one: only a final `AUTHORIZED`/`EXECUTED` is a success, and
  anything else (`DECLINED`, `DENIED_BY_RISK`, `THREEDS_FAILED`, `FAILED`,
  `CANCELED`, `VOIDED`, `REFUNDED`, and non-final states such as `PENDING` or
  `THREEDS_VALIDATED`) is an error carrying that value as `errorCode`.
  Found on a real device against the sandbox; it affects 2.0.0.
  * Behaviour change if you worked around this by checking `operationResult`
    yourself after a `success`: those payments now arrive as errors, which is
    what they always were. A result with no `operationResult` at all is
    unchanged — there is nothing to contradict the platform with.
* NPG: a payment whose outcome the native SDK cannot parse is no longer
  reported as a failure. The plugin now reads the order back from the NPG
  orders API (`GET /api/phoenix-0.0/psp/api/v1/orders/{orderId}`, with the
  `hostname` and `apiKey` it already uses) and reports the real outcome, so a
  payment that went through comes back as `NpgPaymentStatus.success` with its
  true `operationResult`. This works around the NPGSDK 1.1.0 defect that made
  every successful Android card payment surface as `RESULT_PARSING_FAILED`.
  * Recovery is conservative: only a final `AUTHORIZED`/`EXECUTED` operation is
    reported as a success; final negative outcomes become an error carrying the
    NPG operation result (e.g. `DECLINED`); a non-final state, or an orders API
    that is unreachable, unauthorized or unparseable, leaves the original
    `RESULT_PARSING_FAILED` result untouched. It never turns a known outcome
    into a worse one, and never throws.
  * Opt out with `NexiNpgPayment(..., recoverOutcomeOnParsingFailure: false)`.
  * `NexiNpgPayment` accepts an optional `httpGet` to route that call through
    your own HTTP stack (proxy, pinning, logging); it defaults to the exported
    `npgDefaultHttpGet`, a plain `dart:io` GET that you can wrap instead of
    reimplementing, so the package stays dependency-free.
  * The operation is picked by `operationTime` rather than by the order the
    API happens to list operations in, so a retried payment always resolves to
    its latest attempt.
* NPG: added `NpgPaymentResult.resultParsingFailedCode` so the "outcome
  unknown" code no longer has to be hardcoded by callers.
* NPG: added `NpgPaymentResult.fromOperation`, which maps one `operations[]`
  entry of the NPG orders API to a result using the same success rule as the
  rest of the plugin. The recovery above is built on it, and it is public so
  you can reuse it when you query the orders API yourself; it returns null
  when the operation's outcome is not final.
* NPG: a `hostname` that is not a bare host (one carrying a scheme or a path,
  or an empty one) is now rejected identically on both platforms, offline and
  before any native call, with `errorCode: 'INVALID_CREDENTIALS'` and a message
  naming the host you should have used. Previously only Android rejected it —
  its SDK validates the host when the client is built, while the iOS SDK
  accepts it and fails later on the network with `NPG_ERROR`, which contradicted
  the documented "fails fast before any network call" behaviour.
* NPG (iOS): dismissing the checkout by swiping the sheet down — or closing a
  page with no way forward, such as an expired session — now completes the
  payment with `NpgPaymentStatus.canceled` instead of leaving the future
  pending forever and refusing every later payment with `IN_PROGRESS`. A real
  outcome still wins: cancellation is reported only when the SDK stays silent
  after the checkout is gone.

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
  `AUTH_DENIED`, `NO_ACTIVITY`, plus `IN_PROGRESS`, `ACTIVITY_DESTROYED` and
  `INIT_FAILED` below) instead of returning strings. Success ("OK") is
  unchanged; the user-cancel string is now identical on both platforms (see
  below).
* The classic gateway's error and cancel contract is now unified across
  platforms:
  * iOS now throws `PlatformException(code: "AUTH_DENIED")` for a denied or
    failed payment instead of resolving successfully with an error string
    ("There were errors during payment process"), matching Android.
  * The cancel string is now `"Operation canceled by the user"` on both
    platforms, instead of iOS's previous `"Cancelled by the user"`. The new
    `NexiPayment.canceledByUser` constant should be used instead of
    hardcoding the string.
  * `IN_PROGRESS` (both platforms): thrown if `xPayFrontOfficePaga` is called
    while a payment is already running.
  * `ACTIVITY_DESTROYED` (Android): the pending payment now fails with this
    code if the Activity/engine is torn down for good mid-payment, instead of
    leaving the future hanging forever. A rotation/config change does not
    trigger it. The classic and NPG channels share this fix.
  * `INIT_FAILED` (iOS): `initXPay` failures that are not jailbreak-related
    now surface as `INIT_FAILED`, instead of the previous catch-all that
    reported every `initXPay` failure as `DEVICE_JAILBROKEN`; that code is now
    reserved for the SDK's actual jailbreak error.
  * iOS now validates `currency` and throws `INVALID_REQUEST` for anything
    other than `EUR` (the Nexi iOS SDK supports only EUR). Android now throws
    `INVALID_REQUEST` when `amount` is missing instead of silently sending a
    zero-amount payment.
* BREAKING: `ApiFrontOfficeBaseRequest` dropped its unused `timeStamp`, `mac`,
  `clientType` and `extraKeys` fields and its `.map()` constructors — neither
  native SDK read them, and no MAC is computed client-side.
* NPG: `payWithHostedPaymentPage` now also catches `MissingPluginException`,
  so it never throws even where the plugin isn't implemented (e.g.
  web/desktop); it returns an error-status `NpgPaymentResult` instead.
* NPG: a completed payment whose outcome the Android NPGSDK 1.1.0 cannot parse
  (the SDK declares `operations[].additionalData` as `Map<String, String>`,
  and the backend nests an object inside it) is now reported with the stable
  `errorCode`
  `RESULT_PARSING_FAILED` and an explicit "verify the order server-side"
  message, instead of a raw `JsonSyntaxException` class name. Found by
  completing a real sandbox HPP payment on-device: the order was EXECUTED and
  CAPTURED while the Android SDK threw. The same sandbox payment parses cleanly
  on the iOS simulator (returns `EXECUTED`), so this is Android-specific; iOS
  carries the same defensive mapping (`DecodingError` → `RESULT_PARSING_FAILED`)
  in case its SDK ever regresses.
* Android: `consumer-rules.pro` now keeps `it.nexi.**`, covering both bundled
  SDKs' Gson-reflected model classes. Consumers no longer need to add their
  own ProGuard/R8 rules for a minified release build.
* Added `analysis_options.yaml` (`flutter_lints`), a GitHub Actions CI
  workflow (analyze, unit tests, debug builds for Android and iOS) and
  Renovate for dependency updates.
* BREAKING: tooling floors — Dart >= 3.3, Flutter >= 3.16, Android minSdk 23 /
  AGP 8 / compileSdk 35, iOS deployment target 14.4.
* Removed dead Android card-form code and the Flutter v1 embedding.
* Example app and classic integration tests no longer override `domain` with
  the production URL: a non-empty `domain` overrides the host the
  `environment` selects, so TEST requests were being sent to
  `ecommerce.nexi.it` (production), which rejects the test terminal with a
  generic error page before the card form ever loads. With `domain` unset,
  TEST correctly targets `int-ecommerce.nexi.it` — verified end-to-end on a
  physical device with a real sandbox 3DS payment (state "Autorizzato" via
  the `situazioneOrdine` API). The example also now generates a unique
  `codTrans` per attempt instead of reusing a hardcoded one, which Nexi
  rejects.
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

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nexi_payment/models/environment_utils.dart';
import 'package:nexi_payment/models/xpay_recurring_result.dart';
import 'src/models/api_front_office_qp_request.dart';

export 'models/environment_utils.dart';
export 'models/currency_utils_qp.dart';
export 'models/xpay_recurring_result.dart';

/// Entry point for the classic Nexi XPay gateway (WebView checkout).
///
/// Construct an instance with your merchant [secretKey] and [environment],
/// then call [xPayFrontOfficePaga] to run a payment. For the newer Nexi NPG
/// Hosted Payment Page gateway, use `NexiNpgPayment` from
/// `package:nexi_payment/nexi_payment_npg.dart` instead.
class NexiPayment {
  static const MethodChannel _channel = MethodChannel('nexi_payment');

  /// The exact string [xPayFrontOfficePaga] resolves with when the user
  /// cancels the classic XPay checkout.
  ///
  /// [xPayFrontOfficePaga] settles in one of three ways:
  ///  * resolves with `'OK'` when the payment succeeds;
  ///  * resolves with this constant when the user cancels the checkout;
  ///  * throws a [PlatformException] for anything else, usually with one of
  ///    these stable codes: `AUTH_DENIED`, `IN_PROGRESS` (a payment is
  ///    already in progress), `INVALID_REQUEST`, `NOT_INITIALIZED`,
  ///    `NO_ACTIVITY`, `DEVICE_ROOTED`, `DEVICE_JAILBROKEN`,
  ///    `ACTIVITY_DESTROYED` (Android only: the host Activity was torn down
  ///    mid-payment), `INIT_FAILED`. On Android, lower-level SDK failures
  ///    can additionally surface with the SDK's own error code, so treat
  ///    this list as the common cases rather than a closed set.
  static const String canceledByUser = 'Operation canceled by the user';

  /// Merchant secret key ("chiave per il calcolo mac") from your Nexi terminal.
  final String secretKey;

  /// Target environment: [EnvironmentUtils.TEST] or [EnvironmentUtils.PROD].
  /// Defaults to [EnvironmentUtils.TEST].
  final String environment;

  /// Optional host override for all HTTP requests (e.g. `https://newdomain.com`).
  ///
  /// Leave it empty in almost every case: the SDK derives the host from
  /// [environment] (TEST -> `https://int-ecommerce.nexi.it`, PROD ->
  /// `https://ecommerce.nexi.it`). A non-empty [domain] **overrides** that
  /// mapping — so setting the production URL together with
  /// [EnvironmentUtils.TEST] sends the test terminal's requests to
  /// production, which Nexi rejects with a generic error page in the
  /// checkout.
  final String domain;

  /// Creates a classic XPay client for the given merchant [secretKey].
  ///
  /// [environment] defaults to [EnvironmentUtils.TEST]; leave [domain] empty
  /// unless you need to override the host derived from [environment].
  NexiPayment({
    required this.secretKey,
    this.environment = EnvironmentUtils.TEST,
    this.domain = "",
  });

  /// Initializes the native XPay object with this client's configuration.
  Future<String> _initXPay(
      String secretKey, String environment, String domain) async {
    var res = await _channel.invokeMethod("initXPay",
        {"secretKey": secretKey, "environment": environment, "domain": domain});
    return res;
  }

  /// Opens the XPay checkout in a WebView and awaits the outcome.
  ///
  /// [extraParameters] are passed through to XPay's checkout untouched, which
  /// is how you reach features the plugin does not model directly — most
  /// usefully **storing the card for later charges**:
  ///
  /// ```dart
  /// await nexi.xPayFrontOfficePaga(
  ///   alias, codTrans, CurrencyUtilsQP.EUR, 2500,
  ///   extraParameters: {
  ///     'num_contratto': 'customer-42-card-1',  // your identifier
  ///     'tipo_servizio': 'paga_multi',          // store the card
  ///   },
  /// );
  /// ```
  ///
  /// After that payment the card is held against `num_contratto` and can be
  /// charged again with [xPayRecurringPayment] — the customer never re-enters
  /// it. Other common keys are `urlpost` (your server-to-server notification
  /// URL), `mail` and `descrizione`. Refer to Nexi's XPay parameter reference
  /// for the full list; the plugin does not validate them.
  Future<String> xPayFrontOfficePaga(
    String alias,
    String codTrans,
    String currency,
    int amount, {
    Map<String, String> extraParameters = const <String, String>{},
  }) async {
    await _initXPay(secretKey, environment, domain);
    ApiFrontOfficeQPRequest request = ApiFrontOfficeQPRequest(
      alias,
      codTrans,
      currency,
      amount,
      extraParameters: extraParameters,
    );
    var res =
        await _channel.invokeMethod("xPayFrontOfficePaga", request.toMap());
    return res;
  }

  /// Charges a card previously stored against [contractId], with no checkout
  /// and no interaction from the customer.
  ///
  /// [contractId] is the `num_contratto` you sent as an [extraParameters]
  /// entry on a first payment through [xPayFrontOfficePaga]; [codTrans] must
  /// be unique for every attempt, exactly as in a normal payment.
  ///
  /// The returned [XpayRecurringResult] always completes and never throws for
  /// a refusal: an unauthorized charge comes back with `isSuccess == false`
  /// and XPay's own error code. A [PlatformException] is thrown only for
  /// configuration problems, with the same stable codes as
  /// [xPayFrontOfficePaga] (`NOT_INITIALIZED`, `INVALID_REQUEST`, …).
  ///
  /// > **Consider where this runs.** Unlike the checkout, this call needs no
  /// > user present, so it authorises money to move on its own — which means
  /// > an app doing this must carry your [secretKey], and anyone who unpacks
  /// > the app can then charge every card you have stored. If you have a
  /// > backend, make recurring charges from there and keep the key off the
  /// > device. Use this when the app genuinely is the whole product, and you
  /// > accept that trade-off knowingly.
  Future<XpayRecurringResult> xPayRecurringPayment({
    required String alias,
    required String contractId,
    required String codTrans,
    required int amount,
  }) async {
    await _initXPay(secretKey, environment, domain);
    final res = await _channel
        .invokeMapMethod<String, dynamic>("xPayRecurringPayment", {
      "alias": alias,
      "contractId": contractId,
      "codTrans": codTrans,
      "amount": amount,
    });
    return XpayRecurringResult.fromMap(res ?? const <String, dynamic>{});
  }
}

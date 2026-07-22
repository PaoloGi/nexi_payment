import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nexi_payment/models/environment_utils.dart';
import 'src/models/api_front_office_qp_request.dart';

export 'models/environment_utils.dart';
export 'models/currency_utils_qp.dart';

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

  ///Initialize XPay object with the activity
  Future<String> _initXPay(
      String secretKey, String environment, String domain) async {
    var res = await _channel.invokeMethod("initXPay",
        {"secretKey": secretKey, "environment": environment, "domain": domain});
    return res;
  }

  ///Makes the web view payment and awaits the response
  Future<String> xPayFrontOfficePaga(
      String alias, String codTrans, String currency, int amount) async {
    await _initXPay(secretKey, environment, domain);
    ApiFrontOfficeQPRequest request =
        ApiFrontOfficeQPRequest(alias, codTrans, currency, amount);
    var res =
        await _channel.invokeMethod("xPayFrontOfficePaga", request.toMap());
    return res;
  }
}

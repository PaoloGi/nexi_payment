import 'dart:async';

import 'package:flutter/services.dart';

import '../src/npg/npg_order_recovery.dart';
import '../src/npg/npg_orders_api.dart';
import 'models/npg_hosted_payment_request.dart';
import 'models/npg_payment_result.dart';
import 'npg_http.dart';

/// Client for the Nexi NPG gateway (https://developer.nexigroup.com).
///
/// This is independent from the classic XPay gateway exposed by
/// `NexiPayment`: NPG merchants are identified by a [hostname] and an
/// [apiKey] (X-Api-Key) instead of a secret key and an alias.
///
/// Nexi recommends that [hostname] and [apiKey] are retrieved at runtime
/// from your backend rather than hardcoded in the app.
class NexiNpgPayment {
  static const MethodChannel _channel = MethodChannel('nexi_payment_npg');

  /// Base URL of your NPG environment, e.g. the sandbox or production
  /// hostname found in your NPG back office.
  final String hostname;

  /// Your NPG X-Api-Key.
  final String apiKey;

  /// Whether to read the order back from the NPG orders API when the native
  /// SDK cannot parse the outcome of a payment. Defaults to true.
  ///
  /// NPGSDK 1.1.0 models `operations[].additionalData` as a string while the
  /// backend returns an object, so on Android the SDK fails to parse the
  /// outcome of a payment that actually went through. With this enabled the
  /// plugin fetches the order (same [hostname] and [apiKey] it already uses
  /// to create it) and reports the real outcome, instead of surfacing
  /// [NpgPaymentResult.resultParsingFailedCode].
  ///
  /// Recovery never invents a success: only a final `AUTHORIZED`/`EXECUTED`
  /// operation is reported as one, final negative outcomes are reported as
  /// errors carrying the NPG operation result, and anything else — including
  /// an unreachable or unhappy orders API — leaves the original
  /// "outcome unknown" result untouched.
  ///
  /// Set it to false if your app must not talk to the NPG API directly, e.g.
  /// because you confirm every order from your backend anyway.
  final bool recoverOutcomeOnParsingFailure;

  final NpgOrderRecovery _recovery;

  /// Creates an NPG client for the given [hostname] and [apiKey].
  ///
  /// Pass [httpGet] to route the orders-API call of the outcome recovery
  /// through your own HTTP stack; it defaults to [npgDefaultHttpGet], which
  /// you can also wrap rather than replace.
  NexiNpgPayment({
    required this.hostname,
    required this.apiKey,
    this.recoverOutcomeOnParsingFailure = true,
    NpgHttpGet? httpGet,
  }) : _recovery = NpgOrderRecovery(NpgOrdersApi(httpGet ?? npgDefaultHttpGet));

  /// Opens the NPG Hosted Payment Page in a WebView and completes with the
  /// outcome of the payment.
  ///
  /// The returned [NpgPaymentResult] always completes, never throws: user
  /// cancellation is reported with [NpgPaymentStatus.canceled] and any
  /// failure with [NpgPaymentStatus.error] — a payment that finished without
  /// succeeding (a declined card, a failed 3DS) carrying the NPG operation
  /// result as [NpgPaymentResult.errorCode], and errors the native SDK
  /// surfaces as exceptions (invalid credentials, network errors, or the
  /// platform simply not implementing this plugin, e.g. on web or desktop)
  /// carrying the exception's code.
  ///
  /// When the native SDK cannot parse the outcome of a payment, the order is
  /// read back from the NPG orders API so that a payment that went through is
  /// reported as one; see [recoverOutcomeOnParsingFailure].
  Future<NpgPaymentResult> payWithHostedPaymentPage(
      NpgHostedPaymentRequest request) async {
    final badHostname = _hostnameProblem(hostname);
    if (badHostname != null) {
      return NpgPaymentResult.error(
        code: 'INVALID_CREDENTIALS',
        message: badHostname,
      );
    }
    final result = await _openHostedPaymentPage(request);
    if (!recoverOutcomeOnParsingFailure ||
        result.errorCode != NpgPaymentResult.resultParsingFailedCode) {
      return result;
    }
    final recovered = await _recovery.recover(
      hostname: hostname,
      apiKey: apiKey,
      orderId: request.orderId,
    );
    return recovered ?? result;
  }

  /// Why [hostname] is not the bare host NPG requires, or null if it is fine.
  ///
  /// Only the two mistakes the SDKs actually receive are rejected — a scheme
  /// and a path — plus the empty case. Anything narrower (a DNS-shaped regex)
  /// would risk refusing a host Nexi later considers valid.
  ///
  /// **WHY here:** the Android SDK rejects a malformed host when its client is
  /// built, but the iOS one accepts it and only fails later on the network
  /// call, reporting `NPG_ERROR`. Checking in Dart gives both platforms the
  /// same fast, offline `INVALID_CREDENTIALS` the documentation promises.
  static String? _hostnameProblem(String hostname) {
    final host = hostname.trim();
    if (host.isEmpty) {
      return 'The NPG hostname is empty; it must be a bare host such as '
          '"stg-ta.nexigroup.com".';
    }
    if (host.contains('://')) {
      return 'The NPG hostname must be a bare host, without a scheme: use '
          '"${host.substring(host.indexOf('://') + 3).split('/').first}" '
          'rather than "$hostname".';
    }
    if (host.contains('/')) {
      return 'The NPG hostname must be a bare host, without a path: use '
          '"${host.split('/').first}" rather than "$hostname".';
    }
    return null;
  }

  Future<NpgPaymentResult> _openHostedPaymentPage(
      NpgHostedPaymentRequest request) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'npgHostedPaymentPage',
        <String, dynamic>{
          'hostname': hostname,
          'apiKey': apiKey,
          ...request.toMap(),
        },
      );
      return NpgPaymentResult.fromMap(res ?? const <String, dynamic>{});
    } on PlatformException catch (e) {
      return NpgPaymentResult.error(code: e.code, message: e.message);
    } on MissingPluginException {
      return const NpgPaymentResult.error(
        code: 'NOT_IMPLEMENTED',
        message: 'NPG is not supported on this platform.',
      );
    }
  }
}

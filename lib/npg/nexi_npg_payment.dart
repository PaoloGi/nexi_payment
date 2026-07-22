import 'dart:async';

import 'package:flutter/services.dart';

import 'models/npg_hosted_payment_request.dart';
import 'models/npg_payment_result.dart';

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

  /// Creates an NPG client for the given [hostname] and [apiKey].
  NexiNpgPayment({required this.hostname, required this.apiKey});

  /// Opens the NPG Hosted Payment Page in a WebView and completes with the
  /// outcome of the payment.
  ///
  /// The returned [NpgPaymentResult] always completes, never throws: user
  /// cancellation is reported with [NpgPaymentStatus.canceled] and any
  /// failure (invalid credentials, network errors, declined payments
  /// surfaced as exceptions by the native SDK, or the platform simply not
  /// implementing this plugin, e.g. on web or desktop) with
  /// [NpgPaymentStatus.error].
  Future<NpgPaymentResult> payWithHostedPaymentPage(
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

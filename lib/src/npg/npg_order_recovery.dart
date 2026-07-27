import '../../npg/models/npg_payment_result.dart';
import 'npg_orders_api.dart';

/// Establishes the real outcome of an order from the NPG orders API when the
/// native SDK could not.
///
/// This exists because NPGSDK 1.1.0 declares `operations[].additionalData` as
/// `Map<String, String>` while the backend nests an object inside it
/// (`originalTraceId`): the SDK then fails to parse the outcome of a payment
/// that actually went through. The orders API returns the
/// same operation, and reading it here avoids reporting a successful payment
/// as a failure.
///
/// Its own job is only to pick the operation that represents the payment;
/// fetching belongs to [NpgOrdersApi] and deciding what the operation means to
/// [NpgPaymentResult.fromOperation].
class NpgOrderRecovery {
  final NpgOrdersApi _api;

  /// Creates a recovery that reads orders through [api].
  const NpgOrderRecovery(this._api);

  /// Returns the real outcome of [orderId], or null when it cannot be
  /// established — in which case the caller keeps the result it already had.
  Future<NpgPaymentResult?> recover({
    required String hostname,
    required String apiKey,
    required String orderId,
  }) async {
    final order = await _api.fetchOrder(
      hostname: hostname,
      apiKey: apiKey,
      orderId: orderId,
    );
    if (order == null) {
      return null;
    }
    final operation = _paymentOperation(order['operations']);
    if (operation == null) {
      return null;
    }
    return NpgPaymentResult.fromOperation(operation, orderId: orderId);
  }

  /// The operation that represents the payment: the most recent authorization
  /// if there is one, otherwise the most recent operation carrying a result.
  Map<String, dynamic>? _paymentOperation(Object? operations) {
    if (operations is! List) {
      return null;
    }
    final candidates = <Map<String, dynamic>>[];
    final authorizations = <Map<String, dynamic>>[];
    for (final operation in operations) {
      if (operation is! Map) {
        continue;
      }
      final map = operation.cast<String, dynamic>();
      if (map['operationResult'] is! String) {
        continue;
      }
      candidates.add(map);
      if (map['operationType'] == 'AUTHORIZATION') {
        authorizations.add(map);
      }
    }
    return _mostRecent(authorizations.isNotEmpty ? authorizations : candidates);
  }

  /// Picks the newest operation by `operationTime`, so a retried payment
  /// resolves to its latest attempt whichever order the API lists them in.
  /// Falls back to the API's own order only when a timestamp is missing or
  /// unparseable.
  Map<String, dynamic>? _mostRecent(List<Map<String, dynamic>> operations) {
    if (operations.isEmpty) {
      return null;
    }
    final times = operations
        .map((operation) => operation['operationTime'])
        .map((time) => time is String ? DateTime.tryParse(time) : null)
        .toList();
    if (times.any((time) => time == null)) {
      return operations.last;
    }
    var best = 0;
    for (var i = 1; i < operations.length; i++) {
      // Not-before rather than after, so equal timestamps keep list order.
      if (!times[i]!.isBefore(times[best]!)) {
        best = i;
      }
    }
    return operations[best];
  }
}

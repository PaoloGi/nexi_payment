import '../../src/npg/npg_operation_outcome.dart';

/// Outcome of an NPG payment.
enum NpgPaymentStatus {
  /// The payment completed successfully (see `operationResult` for detail).
  success,

  /// The user dismissed the checkout before completing the payment.
  canceled,

  /// The payment failed or its outcome could not be determined (see
  /// `errorCode`/`errorMessage`).
  error,
}

/// Typed result of an NPG Hosted Payment Page payment.
class NpgPaymentResult {
  /// [errorCode] reported when the native SDK could not parse the outcome of
  /// a payment, and the plugin could not establish it from the NPG orders
  /// API either (see `NexiNpgPayment.recoverOutcomeOnParsingFailure`).
  ///
  /// Treat it as "outcome unknown", never as a decline: the payment may well
  /// have succeeded. Confirm the order server-side — through your
  /// `notificationUrl` or the orders API — before failing the purchase.
  static const String resultParsingFailedCode = 'RESULT_PARSING_FAILED';

  /// How the payment ended.
  final NpgPaymentStatus status;

  /// Identifier of the order the payment belongs to.
  final String? orderId;

  /// Identifier of the payment operation assigned by NPG.
  final String? operationId;

  /// Raw NPG operation result, e.g. "AUTHORIZED" or "EXECUTED".
  final String? operationResult;

  /// Amount of the operation in minor currency units, as reported by NPG.
  final String? operationAmount;

  /// ISO 4217 currency code of the operation.
  final String? operationCurrency;

  /// Payment circuit used (e.g. "VISA"), when available.
  final String? paymentCircuit;

  /// Error code when [status] is [NpgPaymentStatus.error].
  final String? errorCode;

  /// Error message when [status] is [NpgPaymentStatus.error].
  final String? errorMessage;

  const NpgPaymentResult._({
    required this.status,
    this.orderId,
    this.operationId,
    this.operationResult,
    this.operationAmount,
    this.operationCurrency,
    this.paymentCircuit,
    this.errorCode,
    this.errorMessage,
  });

  /// Creates an error result with an optional [code] and [message].
  const NpgPaymentResult.error({String? code, String? message})
      : this._(
          status: NpgPaymentStatus.error,
          errorCode: code,
          errorMessage: message,
        );

  /// Builds a result from the map returned over the platform channel.
  ///
  /// The outcome is decided by `operationResult` whenever NPG reports one:
  /// both native SDKs call their "completed" callback for a payment that
  /// merely *finished*, including one that was declined or failed 3DS, so a
  /// non-successful operation is reported here as an error rather than taken
  /// at the platform's word.
  factory NpgPaymentResult.fromMap(Map<String, dynamic> map) {
    final operationResult = map['operationResult'] as String?;
    final reported = _reportedStatus(map['status']);
    final status = _resolveStatus(reported, operationResult);
    final downgraded = status != reported;

    return NpgPaymentResult._(
      status: status,
      orderId: map['orderId'] as String?,
      operationId: map['operationId'] as String?,
      operationResult: operationResult,
      operationAmount: map['operationAmount'] as String?,
      operationCurrency: map['operationCurrency'] as String?,
      paymentCircuit: map['paymentCircuit'] as String?,
      errorCode:
          map['errorCode'] as String? ?? (downgraded ? operationResult : null),
      errorMessage: map['errorMessage'] as String? ??
          (downgraded ? _failureMessage(operationResult!) : null),
    );
  }

  /// Builds a result from a single NPG operation, applying the same rule as
  /// [fromMap]: only a final `AUTHORIZED`/`EXECUTED` operation is a success.
  ///
  /// [operation] is **one entry of the `operations[]` array** returned by
  /// `GET /api/phoenix-0.0/psp/api/v1/orders/{orderId}` — not the whole order
  /// document. [orderId] is used only when the operation itself omits one.
  ///
  /// This is what the plugin uses to read an order back when the native SDK
  /// cannot parse the outcome, and it is exposed so you can reuse it if you
  /// call the orders API yourself:
  ///
  /// ```dart
  /// final order = jsonDecode(response.body) as Map<String, dynamic>;
  /// final operations = order['operations'] as List<dynamic>;
  /// final result = NpgPaymentResult.fromOperation(
  ///   operations.last as Map<String, dynamic>,
  /// );
  /// ```
  ///
  /// Returns null when the outcome cannot be established — the operation is
  /// unreadable, or its state is not final (`PENDING`, `THREEDS_VALIDATED`,
  /// or a value this version does not know). Treat null as "still unknown"
  /// and keep whatever you already knew, rather than assuming a failure.
  static NpgPaymentResult? fromOperation(
    Map<String, dynamic> operation, {
    String? orderId,
  }) {
    final operationResult = operation['operationResult'];
    if (operationResult is! String) {
      return null;
    }
    final outcome = npgClassifyOperationResult(operationResult);
    if (outcome == NpgOperationOutcome.inconclusive) {
      return null;
    }
    final succeeded = outcome == NpgOperationOutcome.succeeded;
    return NpgPaymentResult._(
      status: succeeded ? NpgPaymentStatus.success : NpgPaymentStatus.error,
      orderId: operation['orderId'] as String? ?? orderId,
      operationId: operation['operationId'] as String?,
      operationResult: operationResult,
      operationAmount: operation['operationAmount'] as String?,
      operationCurrency: operation['operationCurrency'] as String?,
      paymentCircuit: operation['paymentCircuit'] as String?,
      errorCode: succeeded ? null : operationResult,
      errorMessage: succeeded ? null : _failureMessage(operationResult),
    );
  }

  static NpgPaymentStatus _reportedStatus(Object? status) {
    switch (status) {
      case 'success':
        return NpgPaymentStatus.success;
      case 'canceled':
        return NpgPaymentStatus.canceled;
      default:
        return NpgPaymentStatus.error;
    }
  }

  /// A reported success only survives if the operation backs it up. A missing
  /// `operationResult` leaves the platform's verdict alone: there is nothing
  /// to contradict it with.
  static NpgPaymentStatus _resolveStatus(
    NpgPaymentStatus reported,
    String? operationResult,
  ) {
    if (reported != NpgPaymentStatus.success || operationResult == null) {
      return reported;
    }
    return npgClassifyOperationResult(operationResult) ==
            NpgOperationOutcome.succeeded
        ? NpgPaymentStatus.success
        : NpgPaymentStatus.error;
  }

  static String _failureMessage(String operationResult) =>
      npgClassifyOperationResult(operationResult) == NpgOperationOutcome.failed
          ? 'The payment did not succeed: NPG reported $operationResult.'
          : 'The payment did not complete: NPG reported $operationResult, '
              'which is not a final successful outcome. Verify the order '
              'server-side before treating it either way.';

  /// Whether [status] is [NpgPaymentStatus.success].
  bool get isSuccess => status == NpgPaymentStatus.success;

  /// Whether [status] is [NpgPaymentStatus.canceled].
  bool get isCanceled => status == NpgPaymentStatus.canceled;

  @override
  String toString() =>
      'NpgPaymentResult(status: $status, orderId: $orderId, operationId: $operationId, '
      'operationResult: $operationResult, errorCode: $errorCode, errorMessage: $errorMessage)';
}

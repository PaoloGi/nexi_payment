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
  factory NpgPaymentResult.fromMap(Map<String, dynamic> map) {
    final NpgPaymentStatus status;
    switch (map['status']) {
      case 'success':
        status = NpgPaymentStatus.success;
        break;
      case 'canceled':
        status = NpgPaymentStatus.canceled;
        break;
      default:
        status = NpgPaymentStatus.error;
    }
    return NpgPaymentResult._(
      status: status,
      orderId: map['orderId'] as String?,
      operationId: map['operationId'] as String?,
      operationResult: map['operationResult'] as String?,
      operationAmount: map['operationAmount'] as String?,
      operationCurrency: map['operationCurrency'] as String?,
      paymentCircuit: map['paymentCircuit'] as String?,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  /// Whether [status] is [NpgPaymentStatus.success].
  bool get isSuccess => status == NpgPaymentStatus.success;

  /// Whether [status] is [NpgPaymentStatus.canceled].
  bool get isCanceled => status == NpgPaymentStatus.canceled;

  @override
  String toString() =>
      'NpgPaymentResult(status: $status, orderId: $orderId, operationId: $operationId, '
      'operationResult: $operationResult, errorCode: $errorCode, errorMessage: $errorMessage)';
}

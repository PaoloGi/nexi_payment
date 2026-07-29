/// Outcome of a recurring charge against a stored contract.
class XpayRecurringResult {
  /// Whether the charge was authorized.
  final bool isSuccess;

  /// Authorization code returned by the issuer, when the charge succeeded.
  final String? authCode;

  /// XPay's own identifier for the operation.
  final String? operationId;

  /// Card circuit used, e.g. `VISA`.
  final String? brand;

  /// Date and time XPay recorded for the operation.
  final String? date;
  final String? time;

  /// Error code when [isSuccess] is false, as reported by XPay.
  final String? errorCode;

  /// Error message when [isSuccess] is false.
  final String? errorMessage;

  /// Creates a recurring-charge result.
  const XpayRecurringResult({
    required this.isSuccess,
    this.authCode,
    this.operationId,
    this.brand,
    this.date,
    this.time,
    this.errorCode,
    this.errorMessage,
  });

  /// Builds a result from the map returned over the platform channel.
  factory XpayRecurringResult.fromMap(Map<String, dynamic> map) {
    return XpayRecurringResult(
      isSuccess: map['isSuccess'] == true,
      authCode: map['authCode'] as String?,
      operationId: map['operationId'] as String?,
      brand: map['brand'] as String?,
      date: map['date'] as String?,
      time: map['time'] as String?,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  @override
  String toString() => 'XpayRecurringResult(isSuccess: $isSuccess, '
      'authCode: $authCode, operationId: $operationId, brand: $brand, '
      'errorCode: $errorCode, errorMessage: $errorMessage)';
}

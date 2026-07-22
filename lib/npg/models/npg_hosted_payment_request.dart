/// Parameters for an NPG Hosted Payment Page payment.
class NpgHostedPaymentRequest {
  /// Unique identifier of the order in your system.
  final String orderId;

  /// Amount in minor currency units (e.g. cents: 2500 = €25.00).
  final int amount;

  /// ISO 4217 currency code.
  final String currency;

  /// Language of the hosted payment page (e.g. "ita", "eng").
  final String language;

  /// Optional server-to-server notification URL called by NPG with the
  /// final outcome of the payment.
  final String? notificationUrl;

  /// Optional identifier of the customer in your system.
  final String? customerId;

  /// Optional order description shown in the back office.
  final String? description;

  /// Optional free-form field stored with the order.
  final String? customField;

  /// Creates a hosted-payment-page request for [orderId] and [amount].
  ///
  /// [currency] defaults to `EUR` and [language] to `ita`; the remaining
  /// fields are optional.
  const NpgHostedPaymentRequest({
    required this.orderId,
    required this.amount,
    this.currency = 'EUR',
    this.language = 'ita',
    this.notificationUrl,
    this.customerId,
    this.description,
    this.customField,
  });

  /// Serializes this request to the map sent over the platform channel.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'orderId': orderId,
      'amount': amount,
      'currency': currency,
      'language': language,
      'notificationUrl': notificationUrl,
      'customerId': customerId,
      'description': description,
      'customField': customField,
    };
  }
}

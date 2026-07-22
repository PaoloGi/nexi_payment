// ignore_for_file: constant_identifier_names

/// Environment constants for the classic XPay gateway.
///
/// Pass one of these as the `environment` argument when constructing
/// `NexiPayment`. The SDK maps each to its Nexi host (TEST ->
/// `int-ecommerce.nexi.it`, PROD -> `ecommerce.nexi.it`).
class EnvironmentUtils {
  /// Production environment (live payments).
  static const String PROD = "PROD";

  /// Test/sandbox environment (no real money moves).
  static const String TEST = "TEST";
}

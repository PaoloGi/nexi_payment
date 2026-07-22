import Flutter
import UIKit
import NPGSDK

/// Handler for the "nexi_payment_npg" channel: NPG Hosted Payment Page.
class NpgHandler: NSObject {
  private var inProgress = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "npgHostedPaymentPage" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let myArgs = call.arguments as? [String: Any],
          let hostname = myArgs["hostname"] as? String,
          let apiKey = myArgs["apiKey"] as? String,
          let orderId = myArgs["orderId"] as? String,
          let amount = myArgs["amount"] as? Int,
          let currency = myArgs["currency"] as? String else {
      result(FlutterError(code: "INVALID_REQUEST",
                          message: "hostname, apiKey, orderId, amount and currency are required",
                          details: nil))
      return
    }
    guard let rootViewController = SwiftNexiPaymentPlugin.rootViewController() else {
      result(FlutterError(code: "NO_ACTIVITY", message: "No root view controller available.", details: nil))
      return
    }
    guard !inProgress else {
      result(FlutterError(code: "IN_PROGRESS", message: "Another NPG payment is already in progress.", details: nil))
      return
    }

    let client: PaymentClient
    do {
      client = try PaymentClient(host: hostname, xApiKey: apiKey)
    } catch {
      result(FlutterError(code: "INVALID_CREDENTIALS", message: "\(error)", details: nil))
      return
    }

    let amountString = String(amount)
    let order = Order(orderId: orderId,
                      amount: amountString,
                      currency: currency,
                      customerId: myArgs["customerId"] as? String,
                      _description: myArgs["description"] as? String,
                      customField: myArgs["customField"] as? String)
    let paymentSession = PaymentSessionWebView(actionType: .pay,
                                               amount: amountString,
                                               language: myArgs["language"] as? String,
                                               notificationUrl: myArgs["notificationUrl"] as? String)
    let request = CreateHostedFieldOrderRequestWebView(order: order, paymentSession: paymentSession)

    inProgress = true
    let finish = self.singleShot(result)
    Task { @MainActor in
      do {
        try await client.CreateOrderHPPWebView(
          param: request,
          cbResultOk: { operation in
            finish(Self.successMap(operation))
          },
          cbResultCancel: { _ in
            finish(["status": "canceled"])
          },
          controller: rootViewController)
      } catch {
        if error is DecodingError {
          // Parity with Android: NPGSDK 1.1.0 models operations[].additionalData
          // as a String while the NPG backend returns an object, so parsing the
          // outcome can fail even though the payment was EXECUTED and CAPTURED.
          finish(FlutterError(
            code: "RESULT_PARSING_FAILED",
            message: "The Nexi NPG SDK could not parse the payment outcome; "
              + "the payment may still have succeeded. Verify the order "
              + "server-side (orders API or server-to-server notification) "
              + "before treating it as failed. Original error: \(error)",
            details: nil))
        } else {
          finish(FlutterError(code: Self.errorCode(for: error), message: "\(error)", details: nil))
        }
      }
    }
  }

  /// Wraps the Flutter result so that only the first outcome is delivered,
  /// on the main thread, and the in-progress flag is always released.
  private func singleShot(_ result: @escaping FlutterResult) -> (Any) -> Void {
    var delivered = false
    return { value in
      DispatchQueue.main.async {
        guard !delivered else { return }
        delivered = true
        self.inProgress = false
        result(value)
      }
    }
  }

  /// Absent fields are omitted rather than sent as nil: a Swift dictionary
  /// holding Optional.none does not bridge cleanly through the platform
  /// channel, and the Dart side reads missing keys as null anyway.
  private static func successMap(_ operation: NPGSDK.Operation) -> [String: Any] {
    var map: [String: Any] = ["status": "success"]
    func put(_ key: String, _ value: String?) {
      if let value = value {
        map[key] = value
      }
    }
    put("orderId", operation.orderId)
    put("operationId", operation.operationId)
    put("operationResult", operation.operationResult.map(normalizedResult))
    put("operationAmount", operation.operationAmount)
    put("operationCurrency", operation.operationCurrency)
    put("paymentCircuit", operation.paymentCircuit.flatMap(circuitString))
    return map
  }

  /// PaymentCircuit is an opaque Codable wrapper around a string; round-trip
  /// it through JSON to read the value.
  private static func circuitString(_ circuit: PaymentCircuit) -> String? {
    guard let data = try? JSONEncoder().encode(circuit) else { return nil }
    return try? JSONDecoder().decode(String.self, from: data)
  }

  /// Normalizes the iOS enum to the NPG API constant names, which is also
  /// what the Android SDK reports (e.g. "DENIED_BY_RISK").
  private static func normalizedResult(_ operationResult: OperationResult) -> String {
    switch operationResult {
    case .authorized: return "AUTHORIZED"
    case .executed: return "EXECUTED"
    case .declined: return "DECLINED"
    case .deniedByRisk: return "DENIED_BY_RISK"
    case .threedsValidated: return "THREEDS_VALIDATED"
    case .threedsFailed: return "THREEDS_FAILED"
    case .pending: return "PENDING"
    case .canceled: return "CANCELED"
    case .voided: return "VOIDED"
    case .refunded: return "REFUNDED"
    case .failed: return "FAILED"
    @unknown default: return operationResult.rawValue
    }
  }

  private static func errorCode(for error: Error) -> String {
    switch error {
    case is UnauthorizedException: return "UNAUTHORIZED"
    case is ClientException: return "CLIENT_ERROR"
    case is ServerErrorException: return "SERVER_ERROR"
    default: return "NPG_ERROR"
    }
  }
}

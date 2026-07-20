import Flutter
import UIKit
import XPaySDK

public class SwiftNexiPaymentPlugin: NSObject, FlutterPlugin {
  private var xPay: XPay?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "nexi_payment", binaryMessenger: registrar.messenger())
    let instance = SwiftNexiPaymentPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let npgChannel = FlutterMethodChannel(name: "nexi_payment_npg", binaryMessenger: registrar.messenger())
    let npgHandler = NpgHandler()
    npgChannel.setMethodCallHandler { call, result in
      npgHandler.handle(call, result: result)
    }
  }

  static func rootViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initXPay":
      initXPay(call, result: result)
    case "xPayFrontOfficePaga":
      xPayFrontOfficePaga(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initXPay(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let myArgs = call.arguments as? [String: Any],
          let secretKey = myArgs["secretKey"] as? String,
          let domain = myArgs["domain"] as? String,
          let environment = myArgs["environment"] as? String else {
      result(FlutterError(code: "INVALID_REQUEST", message: "iOS could not extract " +
          "flutter arguments in method: (initXPay)", details: nil))
      return
    }
    do {
      let xPay = try XPay(secretKey: secretKey)
      xPay._FrontOffice.SelectedEnvironment = environment == "PROD"
          ? EnvironmentUtils.Environment.prod : EnvironmentUtils.Environment.test
      if !domain.isEmpty {
        xPay._FrontOffice.setDomain(newUrl: domain)
      }
      self.xPay = xPay
      result("OK")
    } catch {
      result(FlutterError(code: "DEVICE_JAILBROKEN", message: error.localizedDescription, details: nil))
    }
  }

  private func xPayFrontOfficePaga(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let xPay = xPay else {
      result(FlutterError(code: "NOT_INITIALIZED", message: "XPay is not initialized. Call initXPay first.", details: nil))
      return
    }
    guard let rootViewController = Self.rootViewController() else {
      result(FlutterError(code: "NO_ACTIVITY", message: "No root view controller available.", details: nil))
      return
    }
    guard let myArgs = call.arguments as? [String: Any],
          let alias = myArgs["alias"] as? String,
          let codTrans = myArgs["codTrans"] as? String,
          let _ = myArgs["currency"] as? String,
          let amount = myArgs["amount"] as? Int else {
      result(FlutterError(code: "INVALID_REQUEST", message: "iOS could not extract " +
          "flutter arguments in method: (xPayFrontOfficePaga)", details: nil))
      return
    }

    let apiFrontOfficeQPRequest = ApiFrontOfficeQPRequest(alias: alias, codTrans: codTrans, currency: CurrencyUtilsQP.EUR, amount: amount)

    xPay._FrontOffice.paga(apiFrontOfficeQPRequest, navigation: true, parentController: rootViewController, completionHandler: { response in
      self.handleFrontOffice(response, result: result)
    })
  }

  private func handleFrontOffice(_ response: ApiFrontOfficeQPResponse, result: @escaping FlutterResult) {
    if response.IsValid && !response.IsCanceled {
      result("OK")
    } else if response.IsCanceled {
      result("Cancelled by the user")
    } else {
      result("There were errors during payment process")
    }
  }
}

import Flutter
import UIKit
import XPaySDK

public class SwiftNexiPaymentPlugin: NSObject, FlutterPlugin {
  private var xPay: XPay?
  var mUiViewController: UIViewController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "nexi_payment", binaryMessenger: registrar.messenger())
    let instance = SwiftNexiPaymentPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

    switch call.method {
          case "initXPay":
            print(">>entering initXPay")
            guard let args = call.arguments else {
                return
            }
            if let myArgs = args as? [String: Any],
                let secretKey = myArgs["secretKey"] as? String,
                let domain = myArgs["domain"] as? String,
                let environment = myArgs["environment"] as? String {
                do {
                    xPay = try XPay(secretKey: secretKey)
                    
                    if !(domain ?? "").isEmpty {
                        xPay?._FrontOffice.setDomain(newUrl:domain ?? "")
                    }
                    xPay?._FrontOffice.SelectedEnvironment = environment == "PROD" ? EnvironmentUtils.Environment.prod : EnvironmentUtils.Environment.test
                    



                    result("OK")
                } catch {
                    print("Jailbroken Device")
                }

            } else {
                print("---> error initXPay: iOS could not extract " +
                "flutter arguments in method: (initXPay)")
                result(FlutterError(code: "-1", message: "iOS could not extract " +
                    "flutter arguments in method: (initXPay)", details: nil))
            }
          case "xPayFrontOfficePaga":
            print(">>entering xPayFrontOfficePaga")
            xPayFrontOfficePaga(call, result: result)

          default:
              result(FlutterMethodNotImplemented)
          }
  }

    func xPayFrontOfficePaga(_ call: FlutterMethodCall,  result: @escaping FlutterResult){
        let rootViewController:UIViewController! = UIApplication.shared.keyWindow?.rootViewController
        guard let args = call.arguments else {
            return
        }
        if let myArgs = args as? [String: Any],
            let alias = myArgs["alias"] as? String,
            let codTrans = myArgs["codTrans"] as? String,
            let _ = myArgs["currency"] as? String,
            let amount = myArgs["amount"] as? Int {


          let apiFrontOfficeQPRequest = ApiFrontOfficeQPRequest(alias: alias, codTrans: codTrans, currency: CurrencyUtilsQP.EUR, amount: amount)


            xPay?._FrontOffice.paga(apiFrontOfficeQPRequest, navigation: true, parentController: rootViewController, completionHandler: { response in
                self.handleFrontOffice(response, result: result)
            })

        } else {
            result(FlutterError(code: "-1", message: "iOS could not extract " +
                "flutter arguments in method: (initXPay)", details: nil))
        }
    }


    private func handleFrontOffice(_ response: ApiFrontOfficeQPResponse, result: @escaping FlutterResult) {

        var message = "Payment was canceled by user"
        if response.IsValid {
            if !response.IsCanceled {
                message = "Payment was successful with the circuit \(response.Brand!)"
                result("OK")
            }
            result("Cancelled by the user")

        } else {
            message = "There were errors during payment process"
            result(message)

        }
    }




}

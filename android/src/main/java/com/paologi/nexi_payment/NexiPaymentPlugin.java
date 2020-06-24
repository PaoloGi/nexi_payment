package com.paologi.nexi_payment;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;

import java.io.UnsupportedEncodingException;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.platform.PlatformViewRegistry;
import it.nexi.xpay.CallBacks.FrontOfficeCallbackQP;
import it.nexi.xpay.Models.WebApi.Errors.ApiErrorResponse;
import it.nexi.xpay.Models.WebApi.Requests.FrontOffice.ApiFrontOfficeQPRequest;
import it.nexi.xpay.Models.WebApi.Responses.FrontOffice.ApiFrontOfficeQPResponse;
import it.nexi.xpay.Utils.EnvironmentUtils;
import it.nexi.xpay.Utils.Exceptions.DeviceRootedException;
import it.nexi.xpay.Utils.Exceptions.MacException;
import it.nexi.xpay.XPay;

/** NexiPaymentPlugin */
public class NexiPaymentPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  private Activity activity;
  private XPay xPay;
  private static final String TAG = "NEXI_PAYMENT_PLUGIN";
  private MethodChannel channel;

  public NexiPaymentPlugin() {   }

  public NexiPaymentPlugin(Activity activity){
    this.activity = activity;
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    Log.i(TAG, ">> onAttachedToEngine: entering");
    channel = new MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "nexi_payment");
    channel.setMethodCallHandler(this);
  }

  public static void registerWith(Registrar registrar) {
    Log.i(TAG, ">> registerWith: entering");
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "nexi_payment");
    channel.setMethodCallHandler(new NexiPaymentPlugin(registrar.activity()));
  }


  @Override
  public void onMethodCall(@NonNull final MethodCall call, @NonNull final Result result) {

    switch (call.method) {
      case "initXPay":
        Log.i(TAG, "calling initXPay--------------");
        String secretKey = (String) call.argument("secretKey");
        String environment = (String) call.argument("environment");
        try {
          boolean isNotNull = activity != null;
          Log.i(TAG, "-----------------------activity:" + isNotNull + "--------------");

          xPay = new XPay(activity, secretKey);
          xPay.FrontOffice.setEnvironment(
                  environment != null && environment.equals("PROD")
                  ? EnvironmentUtils.Environment.PROD
                  : EnvironmentUtils.Environment.TEST);
          Log.i(TAG,"XPay initialized");
          result.success("OK");
        } catch (DeviceRootedException e) {
          e.printStackTrace();
          result.success(e.getMessage());
        }

        break;
      case "xPayFrontOfficePaga":
        Log.i(TAG, "calling xPayFrontOfficePaga--------------");
        payWebView(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private void payWebView(MethodCall call, final Result result){
    Log.i(TAG,"-*******************--start xPayFrontOfficePaga--*****************--");
    boolean isTest =  !(call.argument("environment") != null && call.argument("environment").equals("PROD"));
    ApiFrontOfficeQPRequest apiFrontOfficeQPRequest = getFrontOfficeRequest(call);
    Log.i(TAG,"ApiFrontOfficeQPRequest initialized");
    xPay.FrontOffice.setEnvironment(isTest ? EnvironmentUtils.Environment.TEST : EnvironmentUtils.Environment.PROD);
    FrontOfficeCallbackQP callback = new FrontOfficeCallbackQP() {
      @Override
      public void onConfirm(ApiFrontOfficeQPResponse apiFrontOfficeQPResponse) {
        if(apiFrontOfficeQPResponse.isValid()) {
          result.success("OK");
          Log.i(TAG, "QP Payment successful with circuit card: " +apiFrontOfficeQPResponse.getBrand());
        } else {
          String message = "Auth Denied";
          if (apiFrontOfficeQPResponse.getError() != null) {
            message = apiFrontOfficeQPResponse.getError().getMessage();
          }
          Log.i(TAG, "QP Payment error: " + message);
          result.success("QP Payment error: " + message);
        }
      }

      @Override
      public void onError(ApiErrorResponse error) {
        Log.i(TAG, "Error: " +error.getError().getMessage());
        result.error(error.getError().getCode(), error.getError().getMessage(), error.getError().toString());
      }

      @Override
      public void onCancel(ApiFrontOfficeQPResponse apiFrontOfficeQPResponse) {
        Log.i(TAG, "Operation canceled by the user");
        result.success("Operation canceled by the user");
      }
    };

    xPay.FrontOffice.paga(apiFrontOfficeQPRequest, true, callback);


  }


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  public static ApiFrontOfficeQPRequest getFrontOfficeRequest(MethodCall call)  {
    ApiFrontOfficeQPRequest apiFrontOfficeQPRequest = null;
    try {
      apiFrontOfficeQPRequest = new ApiFrontOfficeQPRequest(
              call.argument("alias").toString(),
              call.argument("codTrans").toString(),
              call.argument("currency").toString(),
              call.argument("amount") != null ? ((Integer)call.argument("amount")).longValue() : 0);
    } catch (UnsupportedEncodingException | MacException e) {
      e.printStackTrace();
    }
    return apiFrontOfficeQPRequest;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    android.util.Log.d(TAG, ">>>>>>>>>>>>>>>>onAttachedToActivity: entering");
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {

  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {

  }

  @Override
  public void onDetachedFromActivity() {

  }
}


# nexi_payment

#### Flutter plugin for nexi payment integration.

## Getting Started

### Init Nexi

Initialize NexiPayment object with your secretKey and type of Environment(test or prod)
```
  @override
  void initState() {
    super.initState();
    _nexiPayment = new NexiPayment(secretKey:"_yourSecretKey_", environment: EnvironmentUtils.TEST);
  }
```

To start the payment process just call xPayFrontOfficePaga
```
var res = await _nexiPayment.xPayFrontOfficePagaNonce("YOUR_ALIAS", "codTrans", CurrencyUtilsQP.EUR, amount);
//handle response
```

## Supported features:

### WebView payment
- xPayFrontOfficePaga

<img src="https://github.com/PaoloGi/nexi_payment/blob/master/android_screen_1.jpg" width="400">

<img src="https://github.com/PaoloGi/nexi_payment/blob/master/android_screen_2.jpg" width="400">



## Dependencies

### Android & IOS
- Create a Nexi account and project (or create a test backend here https://ecommerce.nexi.it/area-test )
- Retrieve a secretKey from backend

## Common errors

### IOS
In some cases it's necessary to add these few lines in Podfile (flutter_app/ios/Podfile)
```
platform :ios, '10.0'
use_frameworks!
```

## Special thanks

<img src="https://www.crilumatech.it/wp-content/uploads/2019/05/cropped-CRILUMATECH-BANNER-300-1.jpg" width="200">
for support and testing of the first implementation of the plugin
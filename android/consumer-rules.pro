# The XPay SDK references the Nets 3DS SDK, which Nexi does not distribute
# publicly. It is only reached by the native 3DS2 card-form flow, which this
# plugin never invokes.
-dontwarn com.nets.igfs_3ds_sdk_android.**

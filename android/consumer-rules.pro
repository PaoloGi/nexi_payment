# Neither bundled SDK aar ships proguard rules of its own (XPaySDK has no proguard.txt at all,
# NPGSDK's is present but empty), and both deserialize their API responses with Gson reflecting
# over un-annotated model fields. Without an explicit keep rule, R8 is free to rename/remove
# those fields in a minified consumer app, which silently breaks JSON parsing at runtime instead
# of failing to compile. Keep everything under it.nexi. (covers both it.nexi.xpay and the NPG
# SDK's it.nexi.ngp.sdk package).
-keep class it.nexi.** { *; }

# The XPay SDK references the Nets 3DS SDK, which Nexi does not distribute
# publicly. It is only reached by the native 3DS2 card-form flow, which this
# plugin never invokes.
-dontwarn com.nets.igfs_3ds_sdk_android.**

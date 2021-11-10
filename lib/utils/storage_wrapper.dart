import 'package:shared_preferences/shared_preferences.dart';

class StorageWrapper {

  static Future<void> setData({required String key, required String data}) async {
    Future<SharedPreferences> _storageShared = SharedPreferences.getInstance();
    (await _storageShared).setString(key, data);
  }

  static Future<String?> getData({required String key}) async {
    Future<SharedPreferences> _storageShared = SharedPreferences.getInstance();
    return (await _storageShared).getString(key);
  }

}
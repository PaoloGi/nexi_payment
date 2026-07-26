import 'dart:convert';
import 'dart:math';

import '../../npg/npg_http.dart';

/// Read access to the NPG orders API.
///
/// Owns everything about *talking* to the API — endpoint, headers, timeout,
/// status handling — and nothing about what an order means.
class NpgOrdersApi {
  static const String _ordersPath = '/api/phoenix-0.0/psp/api/v1/orders';

  final NpgHttpGet _httpGet;

  /// Creates a client that performs its requests with [httpGet].
  const NpgOrdersApi(this._httpGet);

  /// Returns the decoded order, or null when it cannot be read: an
  /// unreachable or slow API, a non-200 answer (404 unknown order, 401 bad
  /// key) or a body that is not a JSON object.
  ///
  /// Never throws — callers treat null as "could not establish".
  Future<Map<String, dynamic>?> fetchOrder({
    required String hostname,
    required String apiKey,
    required String orderId,
  }) async {
    try {
      final response = await _httpGet(
        Uri.https(_bareHost(hostname), '$_ordersPath/$orderId'),
        <String, String>{
          'X-Api-Key': apiKey,
          // The API rejects a Correlation-Id that is not a UUID.
          'Correlation-Id': _uuidV4(),
          'Content-Type': 'application/json',
        },
      ).timeout(npgHttpTimeout);

      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// The SDK validates the hostname as a bare host before a payment can even
  /// start, so this only guards against a scheme or a trailing path.
  static String _bareHost(String hostname) {
    var host = hostname.trim();
    final schemeEnd = host.indexOf('://');
    if (schemeEnd != -1) {
      host = host.substring(schemeEnd + 3);
    }
    final pathStart = host.indexOf('/');
    return pathStart == -1 ? host : host.substring(0, pathStart);
  }

  /// A random UUID v4, generated here to keep the package dependency-free.
  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
